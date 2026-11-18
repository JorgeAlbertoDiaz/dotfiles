# Tema claro/oscuro del escritorio

Un solo interruptor cambia el escritorio wayland entre un tema **oscuro** y uno
**claro**: sway, waybar, swaync, wofi, foot, swaylock, wob, herdr, tmux, las apps
GTK/libadwaita y nvim. La paleta sale del tema *rust* de mdbook (los colores que
usa la documentación de Rust), adaptada a roles de escritorio.

## Cómo se cambia

| Vía | Cómo |
|---|---|
| Centro de notificaciones | Botón `󰸌` en el menubar del panel (junto a wifi/bt/dnd/captura) |
| Teclado | `Super+Shift+t` |
| Terminal | `~/.config/sway/scripts/sway-theme.sh toggle` |

El comando también acepta `dark`, `light`, `apply` y `status`:

```bash
sway-theme.sh status         # imprime dark o light
sway-theme.sh light          # fija claro y recarga lo que se puede recargar
sway-theme.sh dark
sway-theme.sh toggle         # alterna
sway-theme.sh apply --no-reload --quiet   # re-aplica lo persistido sin recargar
```

`apply` es lo que corre en cada inicio de sesión (`features/autostart.conf`) y al
final de `scripts/04-setup-dotfiles.sh`: no cambia el tema, sólo lo vuelve a
aplicar sobre lo desplegado.

## Dónde vive el estado

Un archivo de texto, sin magia:

```text
${XDG_STATE_HOME:-~/.local/state}/dotfiles/tema    →  "dark" o "light"
```

Si el archivo no existe, el tema es `dark` (el valor por defecto del repo). Nada
más se genera: el tema activo se materializa apuntando enlaces simbólicos a
archivos nativos completos.

## Cómo funciona (sin generadores)

Cada app tiene **un archivo por tema** en su directorio `themes/`, y el archivo
que la app lee es un **enlace simbólico** al tema activo. Cambiar de tema es
repuntar el enlace; no hay plantillas ni archivos intermedios.

| App | Lo que lee | Enlace | Recarga |
|---|---|---|---|
| sway | `~/.config/sway/config` | incluye `themes/current.conf` → `dark.conf`/`light.conf` | `swaymsg reload` |
| waybar | `~/.config/waybar/style.css` | → `themes/dark.css`/`light.css` | se reinicia con el reload de sway |
| swaync | `~/.config/swaync/style.css` | → `themes/dark.css`/`light.css` | `swaync-client -rs` (en vivo, el panel queda abierto) |
| wofi | `~/.config/wofi/style.css` | → `themes/dark.css`/`light.css` | al abrirse (lee el CSS en cada lanzamiento) |
| foot | `~/.config/foot/foot.ini` | *dos paletas en el mismo archivo* | `SIGUSR1`/`SIGUSR2` (en vivo) |
| swaylock | `~/.config/swaylock/config` | → `themes/dark.conf`/`light.conf` | al bloquear |
| wob | `~/.config/wob/wob.ini` | → `themes/dark.ini`/`light.ini` | con el reload de sway (reinicia el OSD) |
| herdr | `~/.config/herdr/config.toml` | → `themes/light.toml`/`dark.toml` | `herdr server reload-config` |
| tmux | `~/.config/tmux/tmux.conf` | → `themes/light.conf`/`dark.conf` | `tmux source-file` |
| apps GTK | `gsettings` | — | inmediato (GTK escucha el cambio) |
| nvim | `~/.config/nvim/lua/config/theme.lua` | lee el archivo de estado | `--remote-expr` sobre cada socket abierto |

Como swaylock, herdr no tiene configuración aparte del tema: `config.toml` es un
enlace simbólico y su configuración propia vive dentro de `themes/light.toml` o
`themes/dark.toml`.

Dos excepciones a propósito:

- **foot** soporta `[colors-dark]` y `[colors-light]` en el mismo `foot.ini`
  (desde foot 1.17), así que duplicar el archivo sería peor. El único estado es
  `initial-color-theme`, que el script reescribe; las terminales abiertas
  cambian en vivo con la señal.
- **nvim** no tiene `include`: `lua/config/theme.lua` lee el archivo de estado y
  aplica `badwolf` (oscuro) o `dayfox` (claro). El mismo `apply()` que usa el
  arranque es el que el script invoca por `nvim --server … --remote-expr`, así
  que una instancia abierta cambia sin perder buffers ni registros.

Cuando el tema cambia, el script también fija el tema GTK para que acompañen las
apps que no tienen CSS propio (thunar, diálogos, file pickers):

| | `gtk-theme` | `color-scheme` |
|---|---|---|
| oscuro | `Adwaita-dark` | `prefer-dark` |
| claro | `Adwaita` | `prefer-light` |

## Paleta

Los valores salen del CSS de ejemplo (tema rust de mdbook). El acento es el
mismo naranja en los dos modos; lo que cambia es sobre qué fondo se usa.

| Rol | Oscuro | Claro |
|---|---|---|
| fondo documento | `#2b2b27` | `#E1E1DB` |
| texto documento | `#cecece` | `#262625` |
| chrome (barra, notificaciones, launcher, OSD, lock, herdr, tmux) | — | `#3B2E2A` |
| texto sobre chrome | — | `#C8C9DB` |
| chrome elevado (chips, tarjetas, input) | `#33322e` | `#45373A` |
| chrome hover | `#3b3b37` | `#505254` |
| panel atenuado del documento | — | `#C2C2BC` |
| borde de documento | `#5e5e56` | `#B6B6AF` |
| borde de popup | `#8c6a4a` | `#B38F6B` |
| cabecera atenuada | — | `#B3A497` |
| superficie alterna | — | `#DADAD3` |
| borde de tabla | — | `#D5D5CD` |
| acento (relleno) | `#e69f67` | `#E69F67` |
| texto sobre acento | `#241c19` | `#262625` |
| azul (enlace/info) | `#4ea8d6` | `#2B79A2` |
| texto atenuado | `#8a8b99` | `#6E6B5E` |
| marca de búsqueda | — | `#DEC2A2` |
| realce | — | `#D3A17A` |
| urgente/crítico | `#e06c3a` | `#AA1721` con texto `#E1E1DB` |
| aviso | — | `#FF8E00` |
| borde de cabecera de sidebar | — | `#8C391F` |

Los `hsl()` del CSS de mdbook se materializan en hex, porque sway/CSS/toml/wob y
swaylock sólo aceptan hex: `--bg` `hsl(60,9%,87%)` = `#E1E1DB`,
`--quote-bg` `hsl(60,5%,75%)` = `#C2C2BC`, `--quote-border` `hsl(60,5%,70%)` =
`#B6B6AF`, `--table-border-color` `hsl(60,9%,82%)` = `#D5D5CD` y
`--table-alternate-bg` `hsl(60,9%,84%)` = `#DADAD3`.

Tres reglas que explican las decisiones raras:

1. **En claro el naranja es relleno, no texto.** Sobre `#e1e1db` el naranja no
   tiene contraste; por eso el acento va siempre como relleno con texto oscuro
   `#262625`, el texto sobre el chrome `#3b2e2a` (el `--sidebar-bg` del tema
   original) va en `#c8c9db` y los enlaces en el azul `#2b79a2`.
2. **Los ANSI de foot se derivan, no se copian.** El CSS de mdbook define 5
   colores, no 16. En oscuro se eligen tonos cálidos que se lean sobre
   `#2b2b27`; en claro, `bright white` es el texto más oscuro (`#262625`),
   porque el fondo es claro.
3. **Sobre el chrome oscuro el azul y el rojo son relleno, no texto.** Contra
   `#3b2e2a` el azul `#2b79a2` da 2.71:1 y el rojo `#aa1721` 1.77:1, por debajo
   de WCAG AA; se usan sólo como relleno con texto claro. Los avisos van en
   `#ff8e00` (5.66:1) y el texto atenuado sobre chrome en `#b3a497` (5.39:1).

### herdr

El tema claro de herdr usa `name = "terminal"`: el área de paneles (el
documento) toma el fondo ANSI de foot —la paleta rust, `#e1e1db` con texto
`#262625`— y el chrome queda en la paleta oscura del escritorio.

El sidebar de spaces/agents, que no se leía, es chrome: `sidebar_bg` y
`panel_bg` en `#3b2e2a` (el `--sidebar-bg`), fila activa en `#45373a`
(`--sidebar-spacer`), cursor de Navegar en `#505254` y tabs inactivas en
`#45373a`. Los tokens de texto de herdr son **globales** (no hay un "sidebar fg"
aparte): por eso, con el chrome oscuro, `text` va en `#c8c9db` (7.97:1) y
`subtext0`/`overlay0` en `#b3a497` (5.39:1). Los paneles no usan `text`, así que
el documento sigue claro sin conflicto. El tema oscuro queda en nord, sin
cambios.

## Agregar otro tema

1. Crear los archivos completos: `config/<app>/themes/<nombre>.{css,conf,ini,toml}`
   para waybar, swaync, wofi, sway, swaylock, wob, herdr y tmux (copiar el
   `dark.*` y cambiar la paleta; los CSS no tienen variables, así que el archivo
   es completo). En tmux el archivo que la app lee (`tmux.conf`) es un enlace a
   `themes/<tema>.conf`, igual que herdr y swaylock.
2. Agregar la paleta a `config/foot/foot.ini` como `[colors-<nombre>]` si se
   quiere que foot lo soporte.
3. Extender `sway-theme.sh`: el nombre del tema en la validación de acciones y
   el mapeo a valores de `gsettings`.
4. Agregar el caso al spec `scripts/tests/sway-theme-spec.sh`.
5. Actualizar la tabla de esta página.

## Verificación

```bash
# Unitario: corre el script real sobre un HOME y un XDG de prueba
./scripts/tests/sway-theme-spec.sh

# Paleta: verifica que cada color del tema claro es una variable del tema rust
# y que cada par texto/fondo alcanza WCAG AA
./scripts/tests/tema-paleta-spec.sh

# En la sesión: el tema activo y a dónde apuntan los enlaces
~/.config/sway/scripts/sway-theme.sh status
readlink ~/.config/waybar/style.css ~/.config/swaync/style.css ~/.config/wofi/style.css
readlink ~/.config/sway/themes/current.conf ~/.config/swaylock/config ~/.config/wob/wob.ini
readlink ~/.config/herdr/config.toml ~/.config/tmux/tmux.conf
grep '^initial-color-theme=' ~/.config/foot/foot.ini
gsettings get org.gnome.desktop.interface color-scheme

# Que sway siga parseando la config con el tema activo
sway --validate -c ~/.config/sway/config
foot -C -c ~/.config/foot/foot.ini
```

El spec del despliegue (`scripts/tests/04-setup-dotfiles-spec.sh`) cubre la otra
mitad del mecanismo: que un enlace del repo se copie **como enlace** y resuelva
dentro de `~/.config/<app>`.

## Límites conocidos

- wofi, swaylock y wob no tienen recarga en vivo: toman el tema la próxima vez
  que se abren (wofi) o se bloquea la pantalla (swaylock). wob se reinicia con el
  reload de sway que hace el propio toggle.
- nvim cambia en vivo sólo si la instancia expone un socket en
  `${XDG_RUNTIME_DIR}/nvim.<pid>.0` (el valor por defecto). Si no hay socket, la
  instancia conserva el tema con el que arrancó.
- Los formatos de los módulos de waybar (`format`, `tooltip-format`) no evalúan
  variables de CSS, así que no pueden cambiar de color con el tema: el
  calendario del reloj hereda el color del módulo y el punto de notificaciones
  usa un rojo medio (`#c9513a`) legible sobre los dos fondos.
- El fondo de pantalla no forma parte del tema: lo maneja azote/swaybg y
  `swaylock-current.sh` reutiliza la imagen elegida ahí.
- Aplicar los dotfiles resetea los enlaces al tema por defecto; por eso
  `04-setup-dotfiles.sh` re-aplica el tema persistido al final.
