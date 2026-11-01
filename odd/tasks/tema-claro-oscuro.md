# Tema claro/oscuro del escritorio sway

Feature: un tema claro y un tema oscuro para todo el escritorio (sway, waybar, swaync, wofi, foot, swaylock, wob, apps GTK y nvim), con un toggle desde el panel de notificaciones y un atajo de teclado. La paleta sale del CSS de ejemplo (tema rust de mdbook) que pasó el usuario.

## Specs

S1. Un solo toggle cambia claro↔oscuro en todo el escritorio: sway (borde y colores de cliente), waybar, swaync, wofi, foot, swaylock, wob, apps GTK/libadwaita y nvim.

S2. Paleta oscura (`rust-dark` del ejemplo, valores exactos):

```css
--bg: hsl(60, 5%, 16%)            /* #2b2b27 */
--fg: #cecece
--sidebar-bg: #241c19
--sidebar-fg: #a2a3b9
--sidebar-active: #e69f67
--icons: #8a8b99
--links: #4ea8d6
--inline-code-color: #c2bdab
--theme-popup-bg: #33322e
--theme-popup-border: #8c6a4a
--quote-bg: hsl(60, 5%, 22%)      /* #3b3b37 */
--quote-border: hsl(60, 5%, 35%)  /* #5e5e56 */
--searchbar-bg: #1a1a1a
--warning-border: #ff8e00
```

S3. Paleta clara (`rust-light` del ejemplo, valores exactos):

```css
--bg: hsl(60, 9%, 87%)            /* #e1e1db */
--fg: #262625
--sidebar-bg: #3b2e2a
--sidebar-fg: #c8c9db
--icons: #737480
--icons-hover: #262625
--links: #2b79a2
--inline-code-color: #6e6b5e
--theme-popup-bg: #e1e1db
--theme-popup-border: #b38f6b
--quote-bg: hsl(60, 5%, 75%)      /* #c1c1bb */
--quote-border: hsl(60, 5%, 70%)  /* #b4b4ac */
--table-alternate-bg: hsl(60, 9%, 84%) /* #d9d9d3 */
--searchbar-bg: #fafafa
--warning-border: #ff8e00
```

S4. Roles derivados de las dos paletas (el acento es el mismo en ambos modos):

| Rol | Oscuro | Claro |
|---|---|---|
| fondo de app/barra | `#2b2b27` | `#e1e1db` |
| texto | `#cecece` | `#262625` |
| superficie (módulos, inputs) | `#33322e` | `#d9d9d3` |
| superficie alterna (hover) | `#3b3b37` | `#c1c1bb` |
| borde destacado | `#8c6a4a` | `#b38f6b` |
| divisor | `#5e5e56` | `#b4b4ac` |
| acento | `#e69f67` | `#e69f67` |
| texto sobre acento | `#241c19` | `#262625` |
| enlace/azul (progreso, red) | `#4ea8d6` | `#2b79a2` |
| texto atenuado | `#8a8b99` | `#6e6b5e` |
| urgente/crítico | `#e06c3a` | `#b7410e` |

S5. El tema se cambia desde el panel de notificaciones (swaync `menubar` → `buttons#toggles`) y con `$mod+Shift+t`.

S6. El tema persiste entre sesiones: al iniciar sesión sway y al re-aplicar `scripts/04-setup-dotfiles.sh` se vuelve a aplicar el último tema elegido, sin preguntar.

S7. foot cambia en vivo: las terminales abiertas pasan de tema con `SIGUSR1`/`SIGUSR2` y las sesiones nuevas usan el tema elegido (`initial-color-theme` en `foot.ini`).

S8. waybar, swaync y wofi toman la paleta del tema activo sin cerrar sesión (recarga de CSS / reinicio de barra).

S9. nvim arranca con el tema activo (badwolf en oscuro, `dayfox` en claro) y las instancias abiertas cambian en vivo cuando hay socket alcanzable.

S10. swaylock y wob usan el tema activo la próxima vez que se ejecutan.

S11. Sin generadores de configuración: cada tema es un archivo nativo completo del repo; el único estado es un archivo de texto con `dark` o `light`. `style.css` y `config` de las apps que lo admiten son enlaces simbólicos al tema activo.

S12. Las personalizaciones de fuente existentes (`config/waybar/customize.sh`, `config/sway/scripts/sway-font.sh`) siguen funcionando y aplican a los dos temas.

S13. `config/swaync/config.json` y el CSS no dependen de colores hardcodeados fuera de los archivos de tema.

S14. Documentación: `docs/tema-claro-oscuro.md` explica la paleta, el estado, cómo agregar un tema y cómo verificar; `docs/index.md` lo enlaza.

## Tasks

- [ ] T1 (S11) Crear el documento, la rama y el esqueleto de `config/sway/themes/` + enlaces `themes/current.conf`.
- [ ] T2 (S8, S11, S12) Mover la paleta de los CSS de waybar/swaync/wofi a `themes/dark.css` y `themes/light.css`, dejar `style.css` como enlace al tema por defecto y adaptar `customize.sh` de waybar. — commit 1
- [ ] T3 (S1, S2, S3, S4) Separar la paleta de sway a `config/sway/themes/{dark,light}.conf`, agregar `[colors-light]` a foot, temas de swaylock y wob, y `theme.lua` + `dayfox` en nvim. — commit 2
- [ ] T4 (S5, S6, S7, S8, S9, S10, S11) `config/sway/scripts/sway-theme.sh` (toggle/dark/light/status/apply) con tests ejecutables primero (RED) y luego implementación (GREEN). — commit 3
- [ ] T5 (S5, S6, S13) Cablear: atajo `$mod+Shift+t`, botón en el menubar de swaync, `autostart.conf` (quitar el forzado de `Adwaita-dark`, aplicar tema) y hook en `scripts/04-setup-dotfiles.sh`. — commit 3
- [ ] T6 (S14) Documentar y enlazar (`docs/tema-claro-oscuro.md`, `docs/index.md`, `README.md`, `docs/organizacion-sway.md`). — commit 4
- [ ] T7 Verificación: spec en verde, `bash -n`, `shellcheck` (si está), aplicar dotfiles sobre el sistema y probar el toggle en la sesión real.

## Log

L1 (usuario, verbatim):

> Me gustaria cambiar el theme de sway y todo lo relacionado con sway (notificaciones, menu, waybar, etc) tengo el ejemplo de css para crear un tema claro/oscuro y me gustaria poder hacer un toggle desde el panel de notificaciones
>
> ```css
> :root, .rust-light {
>     --bg: hsl(60, 9%, 87%);
>     --fg: #262625;
>
>     --sidebar-bg: #3b2e2a;
>     --sidebar-fg: #c8c9db;
>     ...
> }
>
> .rust-dark {
>     --bg: hsl(60, 5%, 16%);
>     --fg: #cecece;
>     ...
> }
> ```

L2 (decisión del usuario, opción elegida): paleta = "Rust en ambos modos" — oscuro `rust-dark` y claro `rust-light`, reemplaza badwolf en el escritorio.

L3 (decisión del usuario, opción elegida): alcance = "Todo" — base (sway, waybar, swaync, wofi, foot) + GTK (`gtk-theme` y `color-scheme`) + nvim + swaylock + wob.

L4 (decisión del usuario, opción elegida): disparador = "Panel + atajo" — botón en el `menubar` de swaync y `$mod+Shift+t`. Sin modo automático por horario.

L5 (hallazgos de exploración, sesión de hoy):
- swaync 0.12.6 (GTK4 + libadwaita) soporta el widget `menubar` que ya usa `config/swaync/config.json`; recarga CSS con `swaync-client -rs`.
- foot 1.28 trae `[colors-dark]`/`[colors-light]` en un solo archivo, `initial-color-theme`, y cambio en vivo con `SIGUSR1`/`SIGUSR2`.
- waybar 0.15 y wofi 1.5.3 son GTK3: sin variables CSS, así que cada tema es un archivo completo.
- sway solo re-lee `client.*` con `swaymsg reload`; `exec_always` reinicia sus procesos en cada reload, por eso swaync pasa de `exec_always` a `exec` (recarga con `-rs`, sin cerrar el panel).
- `gsettings set org.gnome.desktop.interface gtk-theme Adwaita[-dark]` + `color-scheme prefer-[dark|light]` es lo que hace que GTK3 y libadwaita acompañen.
- `sed -i` sobre un enlace simbólico lo reemplaza por un archivo regular: `customize.sh` de waybar tiene que editar `themes/*.css`, no `style.css`.
- nvim: `badwolf` es solo oscuro; para claro se suma `EdenEast/nightfox` (`dayfox`), y el estado se lee de `$XDG_STATE_HOME/dotfiles/tema`.
