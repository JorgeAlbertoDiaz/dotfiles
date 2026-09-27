#!/usr/bin/env bash
# dashboard.sh — menú principal de sway (puerta de entrada "OpenDesk").
#
# Opciones:
#   Sway        → submenú de sway (menu-sway.sh)
#   Keybindings → lista de keybindings activos (wm-keybinds.sh --gui)
#   Waybar      → placeholder "En desarrollo"
#   Sistema     → placeholder "En desarrollo"
#   Salir       → cierra el menú
#
# Se abre desde sway con: bindsym $mod+Slash exec ~/.config/sway/scripts/dashboard.sh
# El menú se reabre tras cada subopción (bucle hasta "Salir" o ESC).
#
# Keybindings va directo acá y no solo adentro de "Sway": es una consulta
# frecuente y de solo lectura, y encontrarla a un clic de la puerta de entrada
# vale más que tener que entrar al submenú. El atajo anidado en menu-sway.sh se
# mantiene como alias —mismo script, mismo resultado— para no romper la ruta
# conocida ni obligar a nadie a aprender un camino nuevo.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Opciones base de wofi (estilo consistente con el launcher del sistema).
WOFI_OPTS=(--dmenu --insensitive)
[[ -f /etc/wofi/config ]] && WOFI_OPTS+=(--conf /etc/wofi/config)
[[ -f /etc/wofi/style.css ]] && WOFI_OPTS+=(--style /etc/wofi/style.css)

# Muestra las opciones dadas y devuelve la elegida (vacío si se cancela).
seleccionar() {
  local prompt="$1"
  shift
  printf '%s\n' "$@" | wofi "${WOFI_OPTS[@]}" --prompt "${prompt}" || true
}

# Esqueleto de categoría en desarrollo: avisa y ofrece volver al menú.
placeholder() {
  local titulo="$1"
  local opcion
  while true; do
    opcion="$(seleccionar "${titulo} — En desarrollo" 'Volver')"
    [[ -z "${opcion}" || "${opcion}" == 'Volver' ]] && return 0
  done
}

while true; do
  opcion="$(seleccionar 'OpenDesk > ' 'Sway' 'Keybindings' 'Waybar' 'Sistema' 'Salir')"
  case "${opcion}" in
    'Sway')       "${SCRIPT_DIR}/menu-sway.sh" || true ;;
    'Keybindings') "${SCRIPT_DIR}/wm-keybinds.sh" --gui || true ;;
    'Waybar')     placeholder 'Waybar' ;;
    'Sistema')    placeholder 'Sistema' ;;
    'Salir')      exit 0 ;;
    *)            exit 0 ;;  # ESC o cancelación
  esac
done