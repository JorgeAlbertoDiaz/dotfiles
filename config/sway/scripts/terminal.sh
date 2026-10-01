#!/usr/bin/env bash
# terminal.sh — abre la terminal por defecto, o corre un comando adentro.
#
# Uso:
#   terminal.sh                    → abre la terminal (shell interactiva)
#   terminal.sh <cmd> [args...]    → corre <cmd> dentro de la terminal
#
#   terminal.sh calcurse           → la fecha de waybar (agenda)
#   terminal.sh nmtui              → el ícono de red de waybar; botones de swaync
#   terminal.sh bluetuith          → el botón de Bluetooth de swaync
#
# Por qué existe: waybar y swaync NO pueden leer las variables de sway
# (`set $terminal`), así que sin esto cada componente hardcodeaba su terminal
# (waybar usaba wezterm, swaync y sway usaban foot) y cambiar la terminal
# obligaba a tocar nueve lugares. Acá vive la única decisión.
#
# Cambiar la terminal = cambiar TERMINAL_PREFERIDA. La variable de entorno
# $TERMINAL tiene prioridad, útil para probar otra sin editar este archivo:
#   TERMINAL=wezterm terminal.sh nmtui
set -euo pipefail

TERMINAL_PREFERIDA="foot"

# Si la elegida no está instalada se usa la primera de esta lista que sí lo esté,
# así una máquina sin foot igual abre algo en vez de fallar.
TERMINALES_RESPALDO=(wezterm alacritty foot)

elegida=""
for t in "${TERMINAL:-${TERMINAL_PREFERIDA}}" "${TERMINALES_RESPALDO[@]}"; do
  if command -v "${t}" &>/dev/null; then
    elegida="${t}"
    break
  fi
done

if [[ -z "${elegida}" ]]; then
  msg="No hay ninguna terminal instalada (probé: ${TERMINAL:-${TERMINAL_PREFERIDA}}, ${TERMINALES_RESPALDO[*]})"
  notify-send "Terminal" "${msg}" 2>/dev/null || true
  echo "terminal.sh: ${msg}" >&2
  exit 1
fi

# Con comando: se marca la ventana con un app_id propio para que sway la trate
# como flotante (ver features/windows.conf). Así la terminal común de
# $mod+Return sigue tildeando y sólo estas TUI flotan.
# Sólo se marca donde el flag está verificado: si un respaldo no lo tiene, la
# ventana tildea, que es preferible a una terminal que no abre.
APP_ID_TUI="floating-tui"
args_app_id=()
case "${elegida}" in
  foot)      args_app_id=(--app-id="${APP_ID_TUI}") ;;
  alacritty) args_app_id=(--class="${APP_ID_TUI}") ;;
esac

# Con comando: "terminal -e cmd args" (foot, wezterm y alacritty comparten -e).
# Sin comando: la terminal sola abre su shell interactiva.
if [[ $# -gt 0 ]]; then
  exec "${elegida}" "${args_app_id[@]}" -e "$@"
fi
exec "${elegida}"
