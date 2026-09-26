# Drivers por hardware: entry-point por dispositivo + submenú

## Objetivo
1. SUSTITUIR el componente "NVIDIA" del menú por un componente **"Drivers"** con submenú.
2. CREAR un script autocontenido por dispositivo: `driver-nvidia-gtx1060.sh`.
3. ELIMINAR los drivers de `packages/` (`nvidia.txt` + `03-nvidia-setup.sh`).

## Problema
- Los drivers estaban modelados como un *paquete de sistema* (`packages/nvidia.txt`)
  consumido por un script genérico (`03-nvidia-setup.sh`). Eso no escala: el driver
  depende de LA PLACA, no del sistema, y una impresora o una AMD no se
  expresa con un `case` de un solo vendor.
- El nombre `nvidia.txt` y la variable `NVIDIA_PKGS_FILE` hardcodeaban el vendor
  en cada capa. Agregar un segundo dispositivo exigía duplicar el script entero.
- `03-nvidia-setup.sh` promised "Regenerar GRUB (solo si se modificó)" pero el
  chequeo era `grep -q "${GRUB_PARAM}" /etc/default/grub`, que también da true si
  el parámetro ya estaba de antes. Resultado: `grub2-mkconfig` con root en CADA
  corrida, contradiciendo su propio comentario.

## Por qué
El usuario: "lo podemos agrupar por drivers.txt... en el futuro quiero agregar
nuevos plugins", y luego corrigió el enfoque a algo mejor: "no quiero generalizar,
para este caso yo nombraría ese archivo como driver-nvidia-[modelo placa].sh
refactorizado... Mi idea es quitarlos de packages y crear un script único para
cada caso y crear una entrada nueva en el menú principal como 'Drivers' y dentro
todos esos scripts."

Es mejor que un `drivers.txt` genérico: el submenú descubre `driver-*.sh` por
glob, así que un dispositivo futuro aparece solo sin tocar `install.sh`.

## Alcance autorizado (y ejecutado)
- NUEVO `scripts/drivers/driver-nvidia-gtx1060.sh` (755, autocontenido)
- NUEVO `scripts/drivers/drivers-menu.sh` (755, submenú con descubrimiento por glob)
- EDITADO `install.sh` — "NVIDIA" → "Drivers" en `COMPONENTES` y en `run_component()`
- EDITADO `README.md` — árbol, componentes, chmod, nota de drivers
- EDITADO `docs/index.md` — fila `nvidia.txt` removida + sección del patrón de drivers
- EDITADO `docs/assets/flow.mmd` — nodo del diagrama apunta al submenú
- ELIMINADO `packages/nvidia.txt`
- ELIMINADO `scripts/03-nvidia-setup.sh`

## Hardware objetivo
NVIDIA GeForce GTX 1060 3 GB (GP106), rama G06, driver 580.178.04. Verificado
con `lspci` en la máquina: `0a:00.0 VGA compatible controller: NVIDIA Corporation
GP106 [GeForce GTX 1060 3GB]`.

## Checks ejecutados
- `bash -n` en los 3 scripts bash (driver, submenú, install.sh): OK
- Glob del submenú: `driver-nvidia-gtx1060.sh` → label "NVIDIA GeForce GTX 1060"
- `grep -rn 'nvidia.txt|03-nvidia'`: sin refs en `README.md`, `install.sh`, `scripts/`, `docs/index.md`, `docs/assets/flow.mmd`
- `git diff` de `install.sh` revisado línea por línea

## Bugs corregidos de paso
1. **GRUB re-generado en cada corrida** (el del "solo si se modificó"). Ahora un
   flag `GRUB_MODIFICADO` gatea el `grub2-mkconfig`.
2. **`chmod +x` no llegaba al submenú**: al mover scripts a `scripts/drivers/`,
   `chmod +x install.sh scripts/*.sh` ya no los alcanzaba → un clone nuevo daba
   permission denied. Agregado `scripts/drivers/*.sh` al README.

## Riesgos y deuda conocida
- **`docs/organizacion-sway.md` quedó con refs a `nvidia.txt` y `03-nvidia-setup.sh`
  (líneas 103, 111) — NO se tocó a propósito.** Ese doc ya estaba desactualizado
  ANTES de este cambio: lista `00-check-system.sh`, `profile-devops.sh`,
  `profile-llm.sh`, `profile-gaming.sh`, `dev.txt` y `fonts.txt`, ninguno de los
  cuales existe. Necesita una pasada completa, no un parche de 2 líneas. Deuda
  separada, reportada al usuario.
- El label del submenú es la clave para volver del texto elegido al archivo. Si
  dos drivers colapsan al mismo nombre, se desambigua con `[archivo]`. Es un
  guard defensivo, no una necesidad actual.
- `driver-nvidia-gtx1060.sh` sigue configuring el kernel de la GTX 1060 sin
  verificar que la placa presente sea esa. Si el usuario cambia de GPU, debe
  agregar el driver nuevo (el submenú lo recibe solo) — no es un problema, es el
  diseño entry-point-por-hardware.
- El discovery por glob no baja a subdirectorios: un driver anidado en
  `scripts/drivers/foo/` no aparecería. Aceptable para el caso de uso.
- `2>/dev/null` en el `zypper in` de los drivers oculta el motivo real del fallo;
  los `warn` dan una explicación genérica. Preservado del trabajo original.
