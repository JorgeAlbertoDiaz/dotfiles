# Rediseñar install.sh como entrada de instalación

## Objetivo

Convertir `install.sh` en la entrada de configuración de una nueva instalación, con un menú principal que permita: instalación completa, selección de componentes (separando obligatorio de accesorio), conexión WiFi y configuración de red (IP estática/DHCP).

## Problema

El menú actual volvió a una versión descartada. `install.sh` mezcla la selección de componentes con opciones de teclado/red que nunca se implementaron, y `dev.txt` mezcla todos los stacks de desarrollo en un solo archivo sin granularidad.

## Por qué

El usuario quiere una instalación reproducible y granular: obligatorio (base + shell) siempre automático, y lo accesorio (Sway, fuentes, NVIDIA, stacks de desarrollo) elegible por separado. También necesita gestión de red (WiFi y estática/DHCP) desde el mismo script.

## Scope

- Rediseñar el menú principal de `install.sh`.
- Base + shell siempre automáticos al seleccionar componentes.
- Sway instala todo lo necesario (waybar, wofi, fzf, fuentes, etc.).
- Conexión WiFi simple desde el menú principal (nmcli).
- Configuración de red (IP estática/máscara/gateway o DHCP) desde el menú principal (nmcli).
- Nerd Fonts: obligatorias para Sway y para Neovim (Dev Core).
- Dividir `packages/dev.txt` en stacks: PHP, Rust, Python, Dev Core, Angular/Node — mantener Go fuera (no seleccionado).

## Constraints

- openSUSE Tumbleweed, zypper.
- gum como TUI con fallback bash.
- Scripts en `scripts/` modulares e idempotentes.
- Convención de commits en español.

## Tareas

- [x] T1: Dividir packages — crear dev-core.txt, dev-php.txt, dev-rust.txt, dev-python.txt, dev-angular.txt (mantener Go fuera); actualizar/remover dev.txt
- [x] T2: Crear scripts/06-network-wifi.sh — conexión WiFi con nmcli (escaneo, selección SSID, contraseña)
- [x] T3: Crear scripts/07-network-config.sh — configurar IP estática (IP/máscara/gateway/DNS) o DHCP con nmcli
- [x] T4: Reescribir install.sh — menú principal (Instalar todo / Seleccionar componentes / WiFi / Red / Salir), obligatorios automáticos, dependencias de Sway y fuentes, orquestar scripts de red
- [x] T5: Verificación — bash -n OK en install.sh + 06 + 07 + 05; staging separado (WIP base.txt/shell.txt fuera)

## Progreso

- T1-T4 implementados por writer delegado; T5 verificado por el orquestador (bash -n OK, spot-check de parsing --family, stage limpio).
- Comentario de desviación del writer: `--family` se agregó a 05-install-fonts.sh; Git rm de dev.txt rechazado por WIP local → rm + add -A. Pendientes: actualizar README.md y docs/index.md (referencias a dev.txt).
- Fix NVIDIA (03-nvidia-setup.sh): se eliminó `--auto-agree-with-licenses` (EULA interactiva en pantalla, no auto-aceptada) y se filtra con `rpm -q` los paquetes ya instalados → instala solo pendientes u omite.
- Fix permisos NetworkManager (06-network-wifi.sh): `radio wifi on`, `rescan` y `connect` ahora van con `as_root` (settings.modify.system = auten; listar redes sigue sin sudo).
- Fix permisos de ejecución: 06 y 07 estaban en 644 → chmod +x (755).
- Fix detección de conexión activa (06-network-wifi.sh): si hay una red WiFi en uso (`IN-USE == '*'`), avisa y pregunta si se quiere cambiar; si no, sale sin escanear ni pedir contraseña.

## Ronda 2 — reportes del usuario (2026-09-18)

Problemas reportados probando el instalador en la máquina real:

- **wl-clipboard**: esta máquina tiene sway del sistema (openSUSEway), no vino del instalador → al aplicar dotfiles, los binds que usan `wl-copy` fallan porque el paquete no está. `wl-clipboard` ya está en `packages/desktop-sway.txt`, pero nadie verifica dependencias al aplicar la config.
- **Nerd Fonts**: la URL de descarga salió `.../v3.5.1/.zip` (asset vacío) → curl 404 → el flujo muestra "Fallo al descargar" y WARN "No se encontró ''". Causa raíz: `mapfile -t chosen <<< "${selected}"` con selección gum vacía crea un array con UN elemento vacío, y el guard `[[ ${#chosen[@]} -eq 0 ]]` no lo detecta → `asset ""` → URL rota.
- **Elegir fuentes interactivamente**: no hay opción en el menú principal para instalar fuentes elegidas; solo existe como componente de "todo"/selección.
- **Aplicar dotfiles al sistema**: no hay opción directa en el menú; "Dotfiles" solo es componente de la instalación.
- **Red estática/DHCP**: con gum, `elegida` es la cadena formateada `"Nombre  (tipo)"` pero el lookup compara contra `nombres[$i]` crudo → "No se pudo identificar la conexión elegida." siempre que hay conexiones listadas.
- **Verbosidad**: los 00-check-system, 00-xdg-dirs y 01-install-gum imprimen [OK]/[INFO] en cada arranque del menú; el usuario quiere solo feedback cuando hay algo que HACER (instalar gum, crear directorios), no en el happy path.

## Tareas ronda 2

- [x] T6: Fix fuentes — filtrar elementos vacíos de la selección gum en `select_families_install()`; validar assets no vacíos en `install_assets()` antes de armar la URL; `installed_asset ""` → false. (Plus: `<mapfile + here-string>` produce un elemento vacío con selección vacía; filtrado con array auxiliar.)
- [x] T7: Fix red — en 07-network-config.sh, lookup por índice contra `opciones` (formateadas) cuando hay gum y contra `nombres` (crudos) en el flujo bash; `break` al primer match. Desviación del writer respecto al plan (`elegida%%  (*`): equivalente y más simple.
- [x] T8: Dependencias al aplicar dotfiles — 04-setup-dotfiles.sh verifica 11 comandos de la config (wl-copy, wofi, grim, slurp, jq, swaylock, swaync, playerctl, pamixer, brightnessctl, bc) con `command -v` y ofrece `as_root zypper -n in` con confirmación; decline no aborta.
- [x] T9: Menú install.sh — opciones directas con `continue` para "Instalar fuentes Nerd Fonts" (05) y "Aplicar dotfiles al sistema" (04); caso bash select actualizado; `--height 7`.
- [x] T10: Verbosidad — common.sh `QUIET=${QUIET:-0}` gatea info/ok; `ensure_xdg_dirs` crea dirs con `QUIET=0` override (visible incluso silenciado, porque crear es "algo que hacer"); 00s y 01 aceptan `--quiet`; install.sh los invoca con `--quiet`.
- [x] T11: Verificación — bash -n OK en los 8 scripts tocados; smoke tests del orquestador con stubs: selección vacía de fuentes → WARN sin descargar; 07 lookup con gum y sin gum → identifica conexión, flujo DHCP llega a sudo; menú con --quiet silencioso, crear-dirs visible; `00-xdg-dirs --quiet` segunda corrida silenciosa.

## Fix extra del writer (validado en T11)

- **05-install-fonts.sh tenía 9 rutas rotas del layout viejo** (`${CONFIG_DIR}/foot/.config/foot/foot.ini`, etc.) mientras las configs viven en `config/<app>/...` plano → sed exit 2 → el script SIEMPRE terminaba con error al leer `warn_configured_missing`/`current_family`/`current_size`. Corregido a rutas planas; grep confirmó que no quedan rutas anidadas.

## Ronda 3 — aplicar dotfiles con selección y recarga (2026-09-18)

El usuario reporta que "Aplicar dotfiles al sistema" aparentemente no hace nada y no cambia la config de sway. Diagnóstico del orquestador:

- Los archivos SÍ se copiaban (diff idéntico repo ↔ ~/.config/sway/), pero **sway ya estaba corriendo** y el script nunca lo recarga → la config en memoria no cambia. Falta `swaymsg reload` (o reinicio de sesión).
- El loop copia TODO `config/*/` sin opción de elegir componentes.

## Tareas ronda 3

- [x] T12: Selección de componentes — 04-setup-dotfiles.sh lista las apps disponibles (subdirs de config/ + home) y permite elegir: "Todos" o un subconjunto (sway, waybar, foot, environment.d, home). gum: `choose --no-limit` multi-selección; fallback bash: menú numerado (t = todos, números separados por espacios, vacío = cancelar). Soporta CLI: `04-setup-dotfiles.sh [todos|app...]`. La selección se guarda en la variable global `SELECCION` (no stdout — el fallback imprime el menú por pantalla y mapfile capturaría el menú como opciones).
- [x] T13: Recarga de sway — tras copiar sway (o todos), detectar sesión sway activa (`command -v swaymsg` + `pgrep -x sway` + `$WAYLAND_DISPLAY`) y ofrecer `swaymsg reload` con confirmación; si no hay sesión, warn de que aplica al reiniciar. El reload es informativo, no reinicia sway.
- [x] T14: Verificación — bash -n OK; smoke tests con stubs (PATH sin gum real): gum multi-select → solo sway+waybar; fallback "2 3" → environment.d+foot; "4 5" → sway+waybar con confirm de recarga; "t" → todos + confirm de recarga; CLI `home` → solo home; sesión sway ausente → warn sin fallar. Bug encontrado y corregido: `cp -r "${app_dir}."` requiere el glob con barra final (`${app_dir}/.`).

## Autorización

Solo esta feature. No tocar configuraciones de sway ni otros componentes.
## Ronda 4 — "Ninguna opción seleccionada" al aplicar dotfiles (2026-09-18)

El usuario reporta que al correr `./install.sh` y elegir "Aplicar dotfiles al sistema", sin importar la opción del submenú, sale `[WARN] Ninguna opción seleccionada.`

Causa raíz: el submenú de 04 usaba `gum choose --no-limit` (multi-select). En gum 0.16, con multi-select **Enter no selecciona la opción resaltada** — Enter solo confirma las opciones ya marcadas con espacio/x (footer de la TUI: `x toggle • enter submit`). El usuario (acostumbrado al menú principal single-select donde flechas+Enter seleccionan directo) navega y da Enter → gum devuelve vacío → WARN + exit 1. Por eso pasaba "sin importar la opción".

## Tareas ronda 4

- [x] T15: Selección iterativa single-select — reemplazado `gum choose --no-limit` por un bucle `gum choose` (single-select, mismo comportamiento que el menú principal) con opciones "Todos", cada app, "home" y "(terminar)". Cada Enter agrega la opción resaltada directo; "(terminar)" finaliza; "Todos" corta aplicando todo; dedupe manteniendo orden de elección. El fallback bash ahora muestra "(terminar)" como opción numerada y la ignora como selección.
- [x] T16: Verificación — bash -n OK; smoke tests con stubs gum (secuencia simulando Enter de la TUI single-select): sway→(terminar) aplica solo sway; "Todos" aplica las 5 apps + home; "(terminar)" directo → WARN Ninguna opción; multi-selección foot+waybar aplica ambos; flujo completo install.sh → "Aplicar dotfiles al sistema" → environment.d → vuelve al menú → "Salir". Fallback bash sin gum: "2 4 6" → environment.d+sway+home (índices del menú de 7 opciones).

## Autorización

Solo esta feature. No tocar configuraciones de sway ni otros componentes.

## Ronda 5 — zsh explícito y fuentes instaladas en el menú (2026-09-18)

El usuario confirmó que la ronda 4 resolvió el "Ninguna opción seleccionada". Reporta:
1. El cambio bash→zsh "nunca se aplicó aunque lo seleccione en el menú". Diagnóstico: el bloque zsh vive en 04-setup-dotfiles.sh y solo corre si `elegidos` contiene literalmente "Todos"; además install.sh llama a 04 SIN argumentos en "Instalación completa (todo)" y en el componente "Dotfiles", así que 04 vuelve a preguntar su propio submenú. Fix acordado: (a) la "Instalación completa (todo)" de install.sh pasa `todos` a 04; (b) el submenú de 04 ofrece "Cambiar shell a zsh" como opción explícita (no solo efecto oculto de "Todos"). El chequeo de shell actual usa `${SHELL}` (variable de la sesión, hereda bash aunque la cuenta ya tenga zsh) — debe usar `getent passwd` para el shell real de la cuenta.
2. Fuentes: no se muestra qué ya está instalado. `installed_asset()` ya salta la re-descarga (verificado en vivo: detecta JetBrainsMono/Monofur/Ubuntu/UbuntuMono, FiraCode no), pero el menú gum no lo indica. Fix: etiquetar "(instalada)" en el menú de selección.

## Tareas ronda 5

- [x] T17: zsh explícito — 04: opción "Cambiar shell a zsh" en submenú (valor interno `zsh`), CLI acepta `zsh`, loop de aplicación salta `zsh` (no es app de config), bloque zsh corre si `elegidos` contiene "Todos" O "zsh", chequeo contra `getent passwd`. install.sh: "Instalación completa (todo)" pasa `todos` a 04 (`DOTFILES_TODOS=1`).
- [x] T18: fuentes — 05: en `select_families_install`, las candidatas ya instaladas se etiquetan "(instalada)" en el menú gum (y fallback bash); al mapear selección→asset se limpia el sufijo; `installed_asset`/`install_assets` siguen saltando instaladas.

## Ronda 5b — feedback al elegir y cierre con confirm (2026-09-18)

El usuario reportó que seleccionar UNA sola opción (waybar, zsh, etc.) "no hace nada
sin errores". Causa raíz: el submenú de 04 es iterativo y exige elegir "(terminar)"
después de cada opción; sin ese paso el bucle sigue abriendo el menú y si el usuario
cancela (ESC/Ctrl+C) se pierde todo en silencio. "Todos" sí funcionaba porque finaliza
el bucle solo. Fix: tras cada opción elegida se muestra `[OK] Agregado: X` y un
`gum confirm --default=false "¿Aplicar algo más?"` cierra el bucle con Enter sin
necesitar "(terminar)" (que sigue aceptado por compatibilidad). Verificado con stubs:
waybar solo → aplica; waybar→sí→foot→no → aplica ambos; "Cambiar shell a zsh" → bloque
zsh ("La shell por defecto ya es zsh"); flujo completo install.sh → "Seleccionar
componentes" → Dotfiles → waybar → aplica; "Instalación completa" → 04 todos. bash -n OK.

## Ronda 6 — reset de fábrica y ESC que termina la selección (2026-09-18)

El usuario borró el contenido de `~/.config/sway/*`, ejecutó install.sh y seleccionó
solo "sway": el menú no mostró error pero no se copiaron los archivos. Pide que aplicar
no sea solo sobreescribir: borrar todo el contenido del destino y copiarlo de nuevo
("reset de fábrica") con ventana de confirmación.

Causa raíz del no-copiado (además del 5b, ya resuelto): si el usuario responde "sí" a
"¿Aplicar algo más?" y luego pulsa ESC/CTRL+C en el `gum choose` siguiente, el `||` de
la asignación hacía `exit 1` descartando TODO lo elegido hasta ese momento, con solo un
WARN "Operación cancelada." que no parece error. "Todos" no pasaba por ese camino.

## Tareas ronda 6

- [x] T19: ESC con selecciones = terminar — en `seleccionar_apps` (gum), si `gum choose`
  falla (ESC/Ctrl+C) y ya hay opciones acumuladas, se muestra "Selección finalizada con
  ESC." y se termina aplicando lo elegido; `exit 1` solo si no se eligió nada.
- [x] T20: Reset de fábrica — al aplicar, una sola confirmación `¿Reset de fábrica?`
  (s=borrar y recrear desde el repo, n=solo copiar) borra con `rm -rf` cada
  `~/.config/<app>` antes de copiar. `home/` queda siempre aditivo (nunca se borra
  `$HOME`). El flag se calcula una vez para todas las apps elegidas.
- [x] T21: Verificación — bash -n OK; stubs con secuencia gum + stdin para `confirm()`:
  sway→sí→ESC aplica y copia (bug real); reset sí borra basura y recrea; reset no
  conserva archivos propios; "Todos" + reset sí recrea environment.d/foot/sway/waybar
  y home queda aditivo; flujo install.sh completo (Seleccionar componentes→Dotfiles→
  sway→reset) y (Aplicar dotfiles al sistema→sway→ESC→Salir) — ambos exit 0 con archivos
  copiados. Ojo: `RESET` colisiona con readonly de common.sh → se usa `RESET_FABRICA`.
