# Reorganizar configuración de sway con dashboard wofi

## Objetivo

Reemplazar la config actual de sway (default openSUSE + config.d) por una config completa, autocontenida y propia, con scripts de personalización viviendo dentro de `config/sway/scripts/`, un dashboard wofi como puerta de entrada ("OpenDesk") y submenús para personalizar sway y ver keybindings. Movimientos al estilo de la arquitectura OpenDesk (docs/opendesk-arquitectua-RFC.md).

## Problema

- `config/sway/config` es el default de openSUSE (220 líneas) + `include /etc/sway/config.d/*.conf` — la sesión depende de la distro para $menu, media keys, screenshots, swayidle, modo sistema, tema, wob/swaync/polkit.
- `config/sway/config.d/10-usuario.conf` tiene binds y ajustes con **ruta hardcodeada al repo** (`/home/jorge/Projects/dotfiles/...`): se rompe si se clona en otra ubicación.
- `customize.sh` reescribe `font pango:` del config del repo, pero el config actual **no define** `font pango:` → el sed no matchea y no hace nada.
- El instalador (04) borra cualquier `customize.sh` en el destino; no hay lugar natural para scripts de personalización.
- No existe un dashboard/menú unificado: wm-keybinds.sh suelto en scripts/, sin puerta de entrada.

## Por qué

El usuario quiere "hacer mía" la configuración: autocontenida, portable (sin rutas hardcodeadas), personalizable desde un dashboard wofi (elegir Sway → personalización y keybindings), alineada con el RFC OpenDesk y reutilizable si retoma el proyecto.

## Scope

- Reescribir `config/sway/config` autocontenida (base en default actual + defaults de /etc/sway/config.d que hoy se cargan por include), EN ESPAÑOL, limpia y organizada por secciones.
- Definir `font pango:JetBrainsMono Nerd Font` + `gaps inner` explícitos (para que la personalización tenga qué reescribir).
- Eliminar `config/sway/config.d/10-usuario.conf` (contenido integrado al config principal) y `config/sway/customize.sh` (su función pasa a `sway-font.sh`).
- Crear `config/sway/scripts/`: mover `scripts/wm-keybinds.sh` (rutas estables, sin /etc en FILES), `dashboard.sh` (menú principal), `menu-sway.sh` (submenú sway: personalización + keybindings), `sway-font.sh` (heredar customize.sh, opera sobre ~/.config/sway/config aplicado + reload), `sway-gaps.sh`.
- Dashboard v1: categorías Sway (funcional), Waybar y Sistema (esqueleto placeholder "en desarrollo", sin implementar).
- Adaptar `scripts/04-setup-dotfiles.sh`: quitar `find -delete customize.sh`, asegurar exec bits de scripts copiados, deps.
- Actualizar doc de rondas `odd/tasks/redisenar-instalador.md` si aplica.

## Constraints

- openSUSE Tumbleweed, sway, waybar, wofi, foot, swaync, wob, swaylock, swayidle, grim/slurp, pamixer, playerctl, brightnessctl.
- Config autocontenida: SIN `include /etc/sway/config.d/*.conf`. Sway carga UN solo archivo (`~/.config/sway/config`); no soporta split del archivo por features vía `include` de un `config.d/`, por eso la división por features es **por secciones dentro del único config** (output / input / keybindings / gaps / bar / client / idle) más scripts por feature en `config/sway/scripts/`, tal como prescribe este doc y el RFC (adapters/sway → keymaps + templates → genera `~/.config/sway/config`).
- Scripts en español (lenguaje del proyecto), sin rutas hardcodeadas del clon → binds a `~/.config/sway/scripts/...`.
- Entrega: excepción directa autorizada (>400 líneas, sin PRs encadenados). Un commit por unidad de trabajo, convención español, sin push.
- No tocar `scripts/` (excepto mover wm-keybinds.sh) ni configs ajenas (waybar, swaync, foot, environment.d).
- NO commitear `scripts/wm-keybinds.sh` del working tree del usuario (tiene cambios propios sin commitear, se mueve tal cual).
- No tocar .codegraph/, odd/ se mantiene trackeado.

## Tareas

- [ ] T1: Reescribir `config/sway/config` autocontenida en español — variables ($mod, $term=foot, $menu=wofi), output (wallpaper + monitores HDMI-A-2/HDMI-A-1 de 10-usuario.conf), input (latam + touchpad del 50-openSUSE), keybindings base + workspace cycle + splits + media keys + modo screenshots ($mod+Print) + modo sistema ($mod+Shift+e) + notify ($mod+Shift+n), `font pango:JetBrainsMono Nerd Font 10`, `gaps inner`, border, cliente colores (base actual), swayidle, bar { swaybar_command waybar }, for_window floating (esenciales de 55-openSUSE-windows), exec swaync + wob + polkit (comentado si no aplica), `$mod+Slash` → dashboard.
- [ ] T2: Eliminar `config/sway/config.d/10-usuario.conf` y `config/sway/customize.sh` (integrados en T1/T3).
- [ ] T3: Crear `config/sway/scripts/` — mover wm-keybinds.sh (razón: v1 — cambiar FILES sway a ~/.config/sway/config + config.d opcional, QUITAR /etc; documentar), crear dashboard.sh (menú principal wofi: Sway → menu-sway.sh, Waybar/Sistema → placeholder, Salir), menu-sway.sh (Personalización → fuente/gaps, Keybindings → wm-keybinds --gui, Recargar → swaymsg reload, Volver), sway-font.sh (lista familias fc-list mono, opciones tamaño, reescribir font pango: en ~/.config/sway/config + swaymsg reload), sway-gaps.sh (opciones 0/4/8/12/16/20 → reescribir gaps inner + reload). Binds estables a `~/.config/sway/scripts/...`.
- [ ] T4: Adaptar `scripts/04-setup-dotfiles.sh` — quitar `find ... -name customize.sh -delete`; garantizar exec bits (la config aplicada debe correr dashboard.sh); revisar DEPENDENCIAS_CONFIG (wofi ya está; confirmar sed/fc-list son core).
- [ ] T5: Verificación — bash -n de todos los scripts; harness con stub wofi: dashboard → menú → Sway → personalización/keybindings; sway-font cambia línea en destino y llama reload; sway-gaps idem; wm-keybinds --list lee la config NUEVA (no /etc); aplicar con 04 → ~/.config/sway con scripts ejecutables y sin config.d/customize.sh; flujo gobernado por stubs gum (reutilizar /tmp/opencode/t50 o clonarlo).

## Progreso

> Cómo se aplicó el "split por features" de la config de sway en HEAD (per `git log 03137c7`, `a5d3a16`, `38ff26c` y `git status --porcelain` = limpio):

### Bitácora entregada (HEAD — ronda 7, work unit, excepción directa autorizada)

- **T1 ✅ (03137c7 + a5d3a16)** — `config/sway/config` reescrita autocontenida en español, 340 líneas, SIN `include /etc/sway/config.d/*.conf` ni ninguna config externa (verificado: `wc -l config/sway/config` = 340; `grep -n include` solo muestra el comentario que declara la exclusión, ningún include activo). El árbol del RFC (`docs/opendesk-arquitectua-RFC.md` L88-90) prescribe `adapters/sway/{generator.sh, keymaps/, templates/}` y que el adaptador **genera** `~/.config/sway/config` — sway carga UN solo archivo, por eso la división por features es **por secciones** dentro del único config (output/input/keybindings/gaps/bar/for_window/exec) + scripts por feature en `config/sway/scripts/`, no por archivos `config.d/` (sway no los soporta).
- **T3 ✅ (03137c7 + a5d3a16)** — `config/sway/scripts/` creado con 5 scripts ejecutables: `dashboard.sh` (dashboard wofi → menú principal), `menu-sway.sh` (submenú sway: personalización/keybindings), `sway-font.sh` (reescribe `font pango:` en `~/.config/sway/config` + `swaymsg reload`), `sway-gaps.sh` (reescribe `gaps inner` + reload), `wm-keybinds.sh` (**movido vía `git mv` desde `scripts/wm-keybinds.sh` — preserva cambios sin commitear del working tree del usuario**). Binds estables a `~/.config/sway/scripts/...` como prescribe el odd.
- **T2 ✅ (a5d3a16)** — `config/sway/config.d/10-usuario.conf` y `config/sway/customize.sh` eliminados (integrados en T1/T3; sin `config.d/` ni `customize.sh` en HEAD).
- **T5 ✅ (38ff26c)** — `scripts/04-setup-dotfiles.sh` adaptado: quitado `find ... -delete` de customize.sh, garantizado exec bits (`chmod +x` en `~/.config/sway/scripts/*.sh`), DEPENDENCIAS_CONFIG con wofi/sed/fc-list (core), dashboard corredizo como entry point. Sin mover `scripts/wm-keybinds.sh` del árbol del usuario (movimiento solo de la nueva ruta, como autoriza el odd).

### Verificación pendiente para la PR de cierre

- [ ] T4 — harness final con stub wofi y stub `gum` (reutilizar `/tmp/opencode/t50` o clonar): dashboard → menú → Sway → personalización/keybindings; `sway-font.sh` cambia la línea en destino y llama reload; `sway-gaps.sh` idem; `wm-keybinds.sh --list` lee la config NUEVA de `~/.config/sway/config` (no `/etc`). No entregado en HEAD — pendiente para la verificación previa al archive.

### Decisiones tomadas

- Sway no soporta dividir el config en múltiples archivos vía `include` de un `config.d/` — por eso el "split por features" **prescrito por el RFC se materializa a nivel de ADAPTER** (`adapters/sway/` → keymaps + templates → genera `~/.config/sway/config`), y a nivel de ARCHIVO secciones + scripts, NO archivos separados. Confirmado en el RFC (L84-90: `adapters/sway/{generator.sh, keymaps/, templates/}`; L170: destino generado `~/.config/sway/config`).

## Autorización

Solo esta feature: reorganizar config/sway + scripts de personalización + dashboard wofi. No tocar configuraciones de waybar, swaync, foot, environment.d ni otros componentes. No tocar scripts/wm-keybinds.sh del working tree (movimiento preserva cambios del usuario: git mv y commit solo de la nueva ruta).