# Greeter de login (LightDM) con la paleta del escritorio

El login de esta máquina lo da **LightDM** con `lightdm-gtk-greeter`, no SDDM ni
GDM: `rpm -q sddm` no devuelve nada y `/usr/lib/systemd/system/display-manager-legacy.service`
pertenece al paquete `xdm` (es el wrapper genérico, no el display manager). Si
`systemctl status display-manager` muestra ese wrapper, el DM real es el que
corre como proceso: `lightdm`.

De fábrica el greeter traía el branding de openSUSE
(`theme-name=Greybird-geeko` + el wallpaper corporativo), que no tiene nada que
ver con la paleta *rust* de la sesión. Este componente lo integra: mismo fondo,
misma tipografía y mismos colores que el escritorio.

## Cómo funciona

```text
/etc/lightdm/lightdm.conf
  greeter-setup-script=/usr/local/sbin/lightdm-greeter-setup
        │
        ▼  (lightdm lo corre como root antes de mostrar el login)
/usr/share/themes/rust-login/gtk-3.0/
  dark.css  light.css
  gtk.css -> dark.css | light.css     ← enlace que deja el helper según la hora
        │
        ▼
/etc/lightdm/lightdm-gtk-greeter.conf
  theme-name=rust-login
  background=/etc/lightdm/background.png
```

La variante se elige por **hora local**, porque el greeter corre antes de la
sesión y no puede leer el estado de tema de sway
(`~/.local/state/dotfiles/tema`, que sí usa `sway-theme.sh`):

| Hora local | Variante |
| --- | --- |
| 20:00 – 07:59 | oscura |
| 08:00 – 19:59 | clara |

El helper nunca sale con error: si falta el CSS de la hora, avisa al log de
lightdm y deja el tema como estaba, para que el login aparezca igual. Además
mantiene el `numlockx` que antes estaba en ese mismo hook.

## Rutas

| En el repo | En el sistema | Qué es |
| --- | --- | --- |
| `scripts/lightdm/greeter/dark.css` | `/usr/share/themes/rust-login/gtk-3.0/dark.css` | Tema oscuro (paleta de `config/sway/themes/dark.conf`) |
| `scripts/lightdm/greeter/light.css` | `/usr/share/themes/rust-login/gtk-3.0/light.css` | Tema claro (paleta de `config/sway/themes/light.conf`) |
| `scripts/lightdm/lightdm-gtk-greeter.conf` | `/etc/lightdm/lightdm-gtk-greeter.conf` | Tema, fondo, fuente e indicadores |
| `scripts/lightdm/bin/lightdm-greeter-setup` | `/usr/local/sbin/lightdm-greeter-setup` | Helper del hook: variante por hora + numlock |
| `scripts/lightdm/background.png` | `/etc/lightdm/background.png` | **Fondo del login** |

## Cambiar el fondo del login

1. Reemplazá `scripts/lightdm/background.png` por tu imagen (PNG o JPEG, la que
   quieras; se escala sola).
2. Corré `./scripts/15-setup-lightdm.sh` otra vez.
3. En el próximo login, o ya mismo con `sudo dm-tool switch-to-greeter`, se ve.

El instalador **valida que el archivo exista y sea una imagen**: si falta o no
es una imagen, falla sin escribir nada (así no te deja un login sin fondo).

## Instalar

```bash
./scripts/15-setup-lightdm.sh            # instala o actualiza
./scripts/15-setup-lightdm.sh --check    # informa el estado, no escribe
```

Es idempotente: se puede correr las veces que haga falta. Es **por máquina**
(usa `sudo` para escribir en `/etc` y `/usr/share`), y respalda antes de tocar:

- `/etc/lightdm/lightdm-gtk-greeter.conf.bak.<fecha>`
- `/etc/lightdm/lightdm.conf.pre-rust-login.bak`

## Verificar

```bash
./scripts/tests/15-setup-lightdm-spec.sh   # spec del instalador y del helper
./scripts/tests/tema-paleta-spec.sh        # el login claro está en la paleta rust
sudo ./scripts/15-setup-lightdm.sh --check
sudo dm-tool switch-to-greeter             # ver el login sin reiniciar
```

`--check` sale 1 si algo falta o se desvió. `dm-tool switch-to-greeter` corta la
sesión gráfica: guardá lo que tengas abierto.

## Volver atrás

```bash
sudo cp /etc/lightdm/lightdm-gtk-greeter.conf.bak.<fecha> /etc/lightdm/lightdm-gtk-greeter.conf
sudo cp /etc/lightdm/lightdm.conf.pre-rust-login.bak /etc/lightdm/lightdm.conf
```

El respaldo del hook devuelve `greeter-setup-script=/usr/bin/numlockx default`.
Borrar `/usr/share/themes/rust-login` y `/usr/local/sbin/lightdm-greeter-setup`
termina de limpiar.

## Trampas que ya están resueltas

- **La fuente no es la tuya.** El greeter corre como el usuario `lightdm`, que no
  lee `~/.local/share/fonts`. Por eso el instalador copia
  `JetBrainsMonoNerdFont-*.ttf` a `/usr/share/fonts/truetype/JetBrainsMonoNerdFont`
  y refresca el cache. Si la fuente no estaba instalada, avisa y el login usa la
  fuente por defecto: corré `05-install-fonts.sh` y repetí.
- **`sudo` borra variables de entorno.** El instalador le pasa el directorio del
  tema al helper con `env` explícito; lightdm lo llama sin variables y ahí usa su
  valor por defecto.
- **El tema no redefine todo GTK.** Los dos CSS importan Adwaita como base
  (`resource:///org/gtk/libgtk/theme/Adwaita/gtk-contained*.css`) y sólo encima
  pintan los widgets del greeter. Un GTK sin ese resource dejaría el login a
  medias: el spec lo verifica.
- **`theme-name` es un nombre, no una ruta.** GTK lo busca en
  `/usr/share/themes/<nombre>/gtk-3.0/gtk.css`, y por eso `gtk.css` es un enlace
  que cambia de destino en cada login.
- **El nombre de la máquina no se muestra.** Se quitó el indicador `~host`: el
  login no tiene por qué anunciar cómo se llama la máquina a quien pase al lado.
- **Fondo y tema son dos archivos distintos.** El CSS no toca el fondo: lo pone
  `background=` del conf del greeter. Cambiar el CSS no cambia la imagen.
