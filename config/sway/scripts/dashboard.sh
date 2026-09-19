#!/usr/bin/env bash
# dashboard.sh — menú principal de sway (puerta de entrada "OpenDesk").
#
# Opciones:
#   Sway     → submenú de sway (menu-sway.sh)
#   Waybar   → placeholder "En desarrollo"
#   Sistema  → placeholder "En desarrollo"
#   Salir    → cierra el menú
#
# Se abre desde sway con: bindsym $mod+Slash exec ~/.config/sway/scripts/dashboard.sh
# El menú se reabre tras cada subopción (bucle hasta "Salir" o ESC).
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
  opcion="$(seleccionar 'OpenDesk > ' 'Sway' 'Waybar' 'Sistema' 'Salir')"
  case "${opcion}" in
    'Sway')    "${SCRIPT_DIR}/menu-sway.sh" || true ;;
    'Waybar')  placeholder 'Waybar' ;;
    'Sistema') placeholder 'Sistema' ;;
    'Salir')   exit 0 ;;
    *)         exit 0 ;;  # ESC o cancelación
  esac
done