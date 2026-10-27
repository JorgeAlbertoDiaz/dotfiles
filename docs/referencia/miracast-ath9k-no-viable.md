# Miracast (Wi-Fi Display) desde Sway: no es viable con el adaptador `ath9k` AR9287

Nota de referencia de por qué **no** se integra `gnome-network-displays` al repo, y
qué se comprobó en el intento.

- **Producto / componente:** openSUSE Tumbleweed → Sway (Wayland) → Miracast / Wi-Fi Display
- **Paquete evaluado:** `gnome-network-displays-0.99.0-2.4` (`openSUSE-Tumbleweed-Oss`)
- **Hardware:** Qualcomm Atheros **AR9287** (`168c:002e`), driver **`ath9k`**, single-radio 2.4 GHz
- **Receptor:** Amazon Fire TV Stick en modo *Display Mirroring*
- **Efecto:** imposible establecer el streaming. Bloqueo de **hardware**, no de configuración.

## Resumen

`gnome-network-displays` implementa Miracast sobre **Wi-Fi Direct (P2P)**, no sobre
la LAN. El chip AR9287 con `ath9k` declara los modos P2P pero **no implementa las
primitivas que el discovery P2P requiere**, así que la conexión nunca se establece.
La aplicación, además, **segfaultea** al manejar ese error. Cualquiera de las dos
cosas alcanzaría para abortar; las dos juntas lo vuelven no depurable.

Aplica a **cualquier** máquina con este adaptador, no solo a este repo.

## Los tres bloqueos

| # | Bloqueo | Origen | ¿Evitable? |
|---|---|---|---|
| 1 | `ath9k` sin `remain-on-channel` ni `mgmt_tx` | Hardware/firmware | No |
| 2 | El Firestick **abandona la LAN** en modo espejo | Comportamiento del receptor | No |
| 3 | `gnome-network-displays` **SIGSEGV** en su path de error | Bug de la aplicación | No |

## Evidencia

### 1) El chip declara P2P pero no puede hacer discovery off-channel

```console
$ /usr/sbin/iw list | grep -A25 "Supported interface modes"
    Supported interface modes:
         * IBSS
         * managed
         * AP
         * AP/VLAN
         * monitor
         * mesh point
         * P2P-client     # <- declara P2P
         * P2P-GO         # <- declara P2P
         * outside context of a BSS
```

El soporte declarado es **nominal**. Lo que el discovery P2P realmente necesita es
poder salir del canal actual por ratos, y eso **no está**:

```console
$ /usr/sbin/iw list | grep -E "remain-on-channel|mgmt_tx"
# (sin resultados)
```

`ath9k` en el AR9287 no ofrece `remain-on-channel`: con la radio ya en modo
`managed` sobre el canal del router, **no puede escuchar invites P2P en otro canal**.
El Firestick hace discovery off-channel clásico, así que nunca se encuentran.

Estado de la radio en el momento de la prueba:

```console
$ /usr/sbin/iw dev
    Interface wlp6s0
        ssid Kadibri_5.0
        type managed
        channel 11 (2462 MHz), width: 20 MHz
```

`iw` vive en `/usr/sbin/iw`; en sesiones cuyo `PATH` no incluye `/usr/sbin`
(`/usr/local/bin:/usr/bin:/bin`) hay que invocarlo con ruta absoluta.

### 2) El Firestick sale de la LAN al entrar en modo espejo

Con el Firestick en su pantalla normal queda en la red y responde:

```console
$ ping -c2 192.168.1.238
2 paquetes transmitidos, 2 recibidos, 0% packet loss
```

Con el Firestick en *Display Mirroring*, deja de existir en la LAN:

```console
$ ping -c2 192.168.1.238
2 paquetes transmitidos, 0 recibidos, 100% packet loss
```

Eso confirma que **no** se trata de Miracast sobre la red del router: el receptor
levanta su propia red P2P y espera que el emisor se conecte a ella. Por eso
ninguna regla de `firewalld` en la zona `public` (la de `wlp6s0`) habilita el
streaming: **ese tráfico no pasa por ahí**.

Consecuencia práctica: `avahi-browse` y el descubrimiento por mDNS sobre la LAN
tampoco sirven una vez que el receptor cambió de modo.

### 3) La aplicación segfaultea al no poder manejar el fallo

Cinco core dumps consecutivos, todos en el mismo sitio:

```console
$ coredumpctl list gnome-network-displays
SIGSEGV  /usr/bin/gnome-network-displays
SIGSEGV  /usr/bin/gnome-network-displays
SIGABRT  /usr/bin/gnome-network-displays
SIGSEGV  /usr/bin/gnome-network-displays
SIGSEGV  /usr/bin/gnome-network-displays

$ coredumpctl info <pid>
Stack trace of thread 74224:
#5  g_logv            (libglib-2.0.so.0)
#6  g_log             (libglib-2.0.so.0)
#7  n/a               (gnome-network-displays + 0x1d355)
#0  __strlen_avx2     (libc.so.6)          <- SEGV leyendo puntero inválido
```

El crash ocurre **dentro de una llamada de logging**: la app recibe un `char *`
NULL o inválido en un formato `%s` y `strlen` explota. Es el mismo sitio que emite:

```console
(gnome-network-displays): Gnd-WARNING **: codec list not initialized
(gnome-network-displays): Gnd-WARNING **: Error with firewall: Se alcanzó el tiempo de expiración
```

Es decir: la app detecta que algo falla, intenta loguearlo, y **crashea en vez de
reportar el error**. No hay configuración del lado del usuario que lo evite.

## Falsos bloqueos descartados

Cosas que parecen faltar y **no** son el problema:

- **`x264enc` no existe en Tumbleweed** (no se empaqueta `libgstx264.so`, motivo de
  licencia). **No hace falta**: `gnome-network-displays` prueba encoders en este
  orden y usa el primero disponible:

  ```text
  openh264enc -> x264enc -> vah264enc -> vaapih264enc -> vp8enc -> vp9enc
  ```

  `openh264enc` (BSD, en `gstreamer-plugins-bad`) ya está presente y es la
  **primera** opción. Un chequeo que exija `x264enc` da un falso negativo.

- **Nombres de paquete**: en openSUSE son `gstreamer-plugins-*`, no `gst-plugins-*`
  (estilo Debian/Arch). `gstreamer-plugins-base/good/bad`, `pipewire` y
  `xdg-desktop-portal-wlr` ya vienen con el escritorio Sway.

- **Zona `firewalld` `P2P-WiFi-Display`**: la plantilla existe en
  `/usr/lib/firewalld/zones/P2P-WiFi-Display.xml` (la trae el propio paquete), pero
  **no está activada** en la configuración. Al intentar crearla, la app recibe
  `NAME_CONFLICT` porque el nombre ya está tomado por la plantilla, y aborta antes
  de pedir polkit. Activarla resuelve ese error concreto:

  ```console
  $ sudo cp -n /usr/lib/firewalld/zones/P2P-WiFi-Display.xml /etc/firewalld/zones/
  $ sudo firewall-cmd --reload
  ```

  Resuelve el `NAME_CONFLICT`, pero **no** habilita el streaming: sin P2P real, la
  zona nunca llega a usarse. La plantilla define `7236/tcp`, `dhcp`, `dns`,
  `icmp` y un `reject` final con prioridad 32767.

- **SSH en la LAN**: ya estaba permitido (`public` incluye `dhcpv6-client ssh`),
  no hubo nada que agregar.

## Veredicto

**No integrar.** Miracast hacia este receptor exige hardware con Wi-Fi Direct
funcional, y el AR9287 no lo tiene. Ningún paquete ni archivo de configuración
cambia capacidades del firmware.

## Alternativas que sí funcionan

| Ruta | Requiere | Por qué funciona |
|---|---|---|
| App receptora en el Firestick (AirScreen, Mirror for Fire TV) + cast por LAN | Nada | La app **no saca al Firestick de la LAN**; se usa IP normal, sin P2P. El chip no participa. |
| Dongle WiFi USB con P2P real (`mt76` MT7612U, `rtw88`) | Compra | Aporta `remain-on-channel`/`mgmt_tx`. Riesgo residual: el SEGV de la app puede persistir. |
| HDMI inalámbrico (emisor/receptor) | Compra | Sin software en juego. |

## Referencias

- `man 5 firewalld.zone` — formato de las plantillas de zona.
- `man 1 iw` — `iw list` como fuente de verdad de los modos soportados por el chip.
- `man 1 coredumpctl` — inspección de los core dumps de la aplicación.
- `/usr/share/doc/packages/gnome-network-displays/` — nota del paquete sobre captura
  por portal (preferida) y fallback X11.
