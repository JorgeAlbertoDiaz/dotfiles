# Hibernación (suspend-to-disk) en openSUSE Tumbleweed con swap sobre LVM

Estado medido en esta máquina, qué falta para poder hibernar y cómo se verifica.
No está implementado: es la referencia para evaluarlo después.

- **Producto / componente:** openSUSE Tumbleweed → kernel `7.2.9-1-default` → systemd
- **Hardware:** 16 GiB de RAM (`MemTotal: 16297756 KiB`)
- **Swap:** LV de LVM `/dev/system/swap` (`/dev/mapper/system-swap`, `/dev/dm-1`), **2 GiB**
- **Raíz:** btrfs sobre LVM (`/dev/mapper/system-root`); la VG `system` abarca `sda1` y `nvme0n1p2`
- **Estado:** el kernel soporta la hibernación, pero **no está configurada** y el swap no alcanza

## Resumen

Hibernar existe en openSUSE como en cualquier Linux: es *suspend-to-disk* (ACPI S4).
El kernel escribe toda la RAM en el swap y apaga; al encender, un initramfs con
`resume=` lee la imagen de vuelta. Los dos extremos de esa cadena son los que
importan: **dónde se escribe** (tiene que entrar) y **de dónde se lee** (el kernel
tiene que saberlo antes de montar la raíz).

Acá fallan las dos: el swap es de 2 GiB contra 16 GiB de RAM, y el cmdline no tiene
`resume=`. Lo bueno es que el swap es un **LV de LVM**, que es justo el caso que sí
está soportado; un swapfile sobre btrfs —el caso que openSUSE no soporta— no es el
de esta máquina.

## Estado medido

| Requisito | Cómo se consulta | Resultado acá |
|---|---|---|
| Kernel con soporte | `cat /sys/power/state` | `freeze mem disk` → **sí** |
| Método de apagado | `cat /sys/power/disk` | `[platform] shutdown reboot suspend test_resume` → firmware/EFI |
| Swap ≥ RAM | `swapon --show`, `/proc/meminfo` | 2 GiB vs 16 GiB → **no** |
| Swap no es swapfile | `/proc/swaps`, `/etc/fstab` | LV de LVM → **sí** |
| `resume=` en el cmdline | `cat /proc/cmdline` | ausente → **no** |
| Dispositivo de resume | `cat /sys/power/resume` | `0:0` → **sin definir** |
| Tamaño de imagen | `cat /sys/power/image_size` | `6609952768` (~6.2 GiB) |

`swapon` vive en `/usr/sbin`, que no siempre está en el `PATH` de una sesión
interactiva (`/usr/local/bin:/usr/bin:/bin`). En ese caso: `/usr/sbin/swapon --show`.

## Comandos

```bash
sudo systemctl hibernate               # hibernar ahora (suspend-to-disk)
sudo systemctl suspend-then-hibernate  # suspende a RAM y a los N min pasa a disco
sudo systemctl hybrid-sleep            # suspend-to-both: RAM y disco a la vez
loginctl hibernate                     # igual, vía polkit (sin contraseña en sesión local activa)
```

Diagnóstico, todo de lectura:

```bash
cat /sys/power/state                   # ¿el kernel ofrece "disk"?
cat /sys/power/disk                    # método de apagado y de resume
cat /sys/power/resume                  # dispositivo de resume que ve el kernel
cat /proc/cmdline                      # ¿tiene resume=?
/usr/sbin/swapon --show                # tamaño y uso del swap
journalctl -b | grep -i hibernat       # qué dijo systemd/el kernel al intentar
```

En la práctica `systemctl hibernate` hoy falla en el chequeo de systemd con
*«Not enough swap space for hibernation»*, sin llegar a escribir nada. Es un fallo
seguro: no deja la máquina a medio hibernar.

## Lo que falta, en orden

1. **Agrandar el swap a RAM + margen.** Con 16 GiB de RAM, 17 GiB. El swap es un LV,
   así que es `swapoff` → `lvresize` → `mkswap` (conservando el UUID) → `swapon -a`.
   Hay que confirmar los extents libres de la VG con `sudo vgs` (no se puede leer sin
   privilegios; el btrfs de `/` tiene 351 GiB sin asignar, pero el límite real es la VG).
2. **Declarar `resume=`** en `GRUB_CMDLINE_LINUX_DEFAULT` de `/etc/default/grub`:

   ```text
   resume=/dev/mapper/system-swap rd.lvm.lv=system/swap
   ```

   El nombre estable del mapper, no `/dev/dm-1`: la numeración de device-mapper no
   es un contrato, y el initramfs resuelve el mapper por nombre.
3. **Regenerar** grub y el initramfs, que es lo que hace efectivo el `resume=`:

   ```bash
   sudo grub2-mkconfig -o /boot/grub2/grub.cfg
   sudo dracut -f          # en openSUSE, mkinitrd es un alias
   ```
4. **Opcional:** `HibernateDelaySec=30min` en `/etc/systemd/sleep.conf` para
   `suspend-then-hibernate`.
5. **Reiniciar** para que el cmdline nuevo entre en vigencia.

## Verificación

Después de reiniciar, los tres chequeos que importan:

```bash
cat /proc/cmdline        # debe contener resume=/dev/mapper/system-swap
cat /sys/power/resume    # distinto de 0:0 (número mayor:menor del swap)
free -h                  # swap total >= RAM
```

Y la prueba real: `sudo systemctl hibernate`, esperar el apagado, encender, y
comprobar que la sesión volvió. Si vuelve, `journalctl -b | grep -i hibernat`
muestra el resume.

## En Sway

No hay menú de energía, así que el patrón es bloquear y dormir:

```bash
swaylock -f && systemctl hibernate
```

Un binding va en `config/sway/config`. Hoy no hay ninguno para esto: `swayidle` solo
bloquea a los 900 s y apaga la pantalla a los 960.

## Riesgos

- **Editar GRUB sin regenerar** deja el parámetro a medias: es peor que no tocarlo,
  porque la imagen se escribe y no se restaura. Los dos comandos van juntos.
- **`swapoff` con el swap lleno** puede quedarse sin memoria; hay que mirar
  `MemAvailable` antes.
- **NVIDIA propietario:** el resume a veces deja la sesión en un VT negro y hay que
  hacer un cambio de VT. No es específico de openSUSE ni de Sway, pero es esta máquina.
- **Discos cifrados o `resume=` apuntando a un nombre inestable** son la otra fuente
  clásica de "hibernó y arrancó de cero". Acá no hay cifrado.

## Automatización

`scripts/hibernacion-lvm.sh` hace los pasos 1 a 4 con confirmación por paso y
verificación después de cada uno. No reinicia nunca.

```bash
./scripts/hibernacion-lvm.sh            # --check: diagnostica, no cambia nada
./scripts/hibernacion-lvm.sh --apply    # propone cada paso y pregunta uno por uno
./scripts/hibernacion-lvm.sh --verify   # relee el estado en vivo (post-reinicio)
```

Decisión: **no aplicarlo todavía.** Se evalúa más adelante; hasta entonces el script
queda como el procedimiento ejecutable de esta nota.
