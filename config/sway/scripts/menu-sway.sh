#!/usr/bin/env bash
# menu-sway.sh — submenú de Sway dentro del dashboard OpenDesk.
#
# Opciones:
#   Personalización            → submenú (Fuente con sway-font.sh, Gaps con sway-gaps.sh)
#   Keybindings                → lista de keybindings activos (wm-keybinds.sh --gui)
#   Recargar configuración     → swaymsg reload (verifica que haya sesión activa)
#   Volver                     → regresa al dashboard
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

# Aviso simple en wofi (para feedback que se ve aunque no haya terminal).
aviso() {
  local mensaje="$1"
  seleccionar "${mensaje}" 'Volver' >/dev/null || true
}

# Verifica si hay una sesión de sway activa.
sesion_activa() {
  command -v swaymsg &>/dev/null &&
    { [[ -S "${SWAYSOCK:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; } &&
    pgrep -x sway &>/dev/null
}

recargar_configuracion() {
  if ! sesion_activa; then
    aviso 'No hay sesión de sway activa; nada que recargar'
    return 0
  fi
  if swaymsg reload; then
    aviso 'Configuración de sway recargada'
  else
    aviso 'Falló la recarga de sway'
  fi
}

personalizacion() {
  local opcion
  while true; do
    opcion="$(seleccionar 'Personalización > ' 'Fuente' 'Gaps' 'Volver')"
    case "${opcion}" in
      'Fuente') "${SCRIPT_DIR}/sway-font.sh" || true ;;
      'Gaps')   "${SCRIPT_DIR}/sway-gaps.sh" || true ;;
      'Volver') return 0 ;;
      *)        return 0 ;;  # ESC
    esac
  done
}

while true; do
  opcion="$(seleccionar 'Sway > ' 'Personalización' 'Keybindings' 'Recargar configuración' 'Volver')"
  case "${opcion}" in
    'Personalización')      personalizacion ;;
    'Keybindings')          "${SCRIPT_DIR}/wm-keybinds.sh" --gui || true ;;
    'Recargar configuración') recargar_configuracion ;;
    'Volver'|*)             exit 0 ;;
  esac
done