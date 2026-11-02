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

- [x] T1 (S11) Crear el documento, la rama y el esqueleto de `config/sway/themes/` + enlaces `themes/current.conf`. → en `fff085c`
- [x] T2 (S8, S11, S12) Mover la paleta de los CSS de waybar/swaync/wofi a `themes/dark.css` y `themes/light.css`, dejar `style.css` como enlace al tema por defecto y adaptar `customize.sh` de waybar. → `fff085c` (waybar), `e937d53` (swaync + wofi)
- [x] T3 (S1, S2, S3, S4) Separar la paleta de sway a `config/sway/themes/{dark,light}.conf`, agregar `[colors-light]` a foot, temas de swaylock y wob, y `theme.lua` + `dayfox` en nvim. → `5c80d80` (sway + foot), `8d4f221` (swaylock + wob + nvim)
- [x] T4 (S5, S6, S7, S8, S9, S10, S11) `config/sway/scripts/sway-theme.sh` (toggle/dark/light/status/apply) con tests ejecutables primero (RED) y luego implementación (GREEN). → `c14c694`, corregido en `f0023fe` (85 pasos, 0 fallos)
- [x] T5 (S5, S6, S13) Cablear: atajo `$mod+Shift+t`, botón en el menubar de swaync, `autostart.conf` (quitar el forzado de `Adwaita-dark`, aplicar tema) y hook en `scripts/04-setup-dotfiles.sh`. → `daa2382`
- [x] T6 (S14) Documentar y enlazar (`docs/tema-claro-oscuro.md`, `docs/index.md`, `README.md`, `docs/organizacion-sway.md`). → `a571bd1`
- [x] T7 Verificación: spec en verde, `bash -n`, `shellcheck` (si está), aplicar dotfiles sobre el sistema y probar el toggle en la sesión real. → `f0023fe` y `fc7256e`; 85 + 48 pasos en verde; toggle real light→dark verificado (enlaces, foot.ini, gsettings, swaync vivo, un solo wob)

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

L6 (slices entregados, para que cada commit se revise solo):
- `fff085c` — T2a: waybar + documento de feature + cobertura del mecanismo de enlaces en el spec del despliegue (527 líneas autoradas: el doc y el test del mecanismo van con la primera app que los usa).
- `e937d53` — T2b: swaync + wofi.
- `5c80d80` — T3a: paleta de sway en `config/sway/themes/` + foot con las dos paletas.
- `8d4f221` — T3b: swaylock + wob + nvim (`config/theme.lua`, dayfox en claro, `apply()` como único camino).
- Pendiente: T4 (script + spec), T5 (cableado), T6 (docs). El resto del feature se corta por unidad funcional, no por app, porque script y cableado no se pueden separar sin dejar un commit que no funciona.

L7 (hallazgos de implementación):
- `lazy.setup({ colorscheme = ... })` NO aplicaba el colorscheme en headless: el tema se aplica con `require("config.theme").apply()` después de `lazy.setup`, que además es el mismo camino que usa el toggle en vivo (`nvim --server ... --remote-expr`). Verificado: `state=light → colors=dayfox, Normal.bg=#e1e1db`; `state=dark → colors=badwolf, Normal.bg=nil` (transparencia intacta).
- `config/nvim/lazy-lock.json` lo reescribió lazy en su formato y agregó las entradas que faltaban (nightfox, laravel.nvim, markdown-preview.nvim, nvim-nio, which-key.nvim). Ningún commit de plugin existente cambió.
- swaync pasa de `exec_always` a `exec`: con `exec_always`, cada `reload` (y el toggle hace reload) reiniciaba el panel en vez de recargar su CSS con `-rs`.

L8 (T4 entregado por `gentle-ai-worker`, revisado por el padre):
- RED: spec antes del script, falla por ausencia del script (exit 2). GREEN: 75 pasos, 0 fallos. `shellcheck` sin avisos en los dos archivos.
- Decisión del worker que el contrato no fijaba: `sesion_sway` acepta SWAYSOCK no vacío (en vez de exigir `-S`) para que el caso de test con SWAYSOCK como archivo regular sea observable; se acepta, es más tolerante en la sesión real.
- Decisión del worker: logs separados `gsettings.log` y `reload.log` en el fixture (con un solo log, "gsettings tiene exactamente 2 entradas" y "reload vacío" son incompatibles). Se acepta.
- Caso 10 extra: inserción de `initial-color-theme` cuando foot.ini no tiene la línea. Se acepta (rama del contrato que no estaba en la lista de casos).
- Revisado por el padre: verificación previa de los seis payloads antes de escribir estado, enlaces relativos con `ln -sfn`, `sed` de una sola línea en foot.ini, gsettings tolerante, `recargar()` enteramente best-effort, stdout reservado a `status`.

L9 (defectos que encontró el despliegue real, corregidos con test-first):
- `~/.config/wob/` no existía (el CLI de `04-setup-dotfiles.sh` sólo aceptaba `home|sway|waybar|foot|environment.d|zsh|git`), y `ln` abortaba el `apply` a la mitad: los enlaces quedaban a medio cambiar y gsettings/foot sin aplicar. El spec nuevo cubre el caso "app no desplegada se saltea" y "foot sin foot.ini se saltea con aviso" (RED 4 fallos → GREEN).
- El CLI del despliegue no reconocía swaync/wofi/swaylock/wob/nvim: la lista estaba escrita a mano. Ahora cualquier subdirectorio de `config/` se acepta por nombre, con caso propio en el spec del despliegue (RED 3 fallos → GREEN).
- `swaymsg reload` no mata los procesos de `exec_always` (sway 1.12): se midieron **5 pares `tail|wob`** apilados compitiendo por el mismo FIFO, cada uno con el `wob.ini` de un tema distinto. Se agregó guard `pgrep -x wob` en autostart y limpieza del par en el toggle. Verificado en la sesión: 3 reloads seguidos dejan exactamente 1 wob.
- Ojo con `pkill -f "tail -f ..."`: se mata a sí mismo cuando el patrón viaja en la línea de comando del shell que lo invoca (pasó durante la verificación). La limpieza busca `pgrep -x tail` y confirma el FIFO en `/proc/<pid>/cmdline`.

L10 (verificación independiente y review nativo):
- `gentle-ai-verify` (read-only, base `main`): **S1-S14 cumplen**. Corrió los dos specs (85 y 48 pasos), `bash -n` y `shellcheck -S warning` (limpios), `sway --validate` (oscuro y claro en copia temporal), `foot -C`, `jq` del config de swaync, y un probe end-to-end de deploy + toggle en un HOME aislado. Confirmó que `05-install-fonts.sh` lee `style.css` a través del enlace con el mismo resultado que en `main` (empate: el regex ya no matcheaba la línea multi-fuente antes tampoco).
- Hallazgos advisory del verificador, atendidos en `4db6a35`: (1) `config/waybar/config` conservaba hex de badwolf en calendario y punto de notificaciones (los formatos de waybar no evalúan CSS) → colores quitados, punto con rojo medio `#c9513a`, límite documentado; (2) el rol "borde destacado" oscuro `#8c6a4a` no se usaba → tooltip de waybar y borde de wob alineados con el modo claro; (3) `apply` no validaba payloads y un `sed -i` fallido abortaba a mitad → corregido con casos 13 y 14 del spec (92 pasos, 0 fallos).
- Review nativo: `assess` (base `main`) devuelve `risk: high`, `nativeRisk: high`, `reviewDue: true` en las dos corridas. Los dos `start` (4 lenses y 2 lenses, candidatos distintos) volvieron `consent-declined-this-candidate` sin envelope para el humano: el host declinó el consentimiento. No se reintenta (el decline es por candidato). El plan de riesgo quedó satisfecho por la vía que no depende del review: verificación propia + verificador independiente. `commit`/`push`/PR siguen siendo decisión del usuario.
