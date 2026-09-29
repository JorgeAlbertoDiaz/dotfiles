#!/usr/bin/env bash
# screenshot.sh — menú de capturas (imagen y video) con wofi.
#
# Reemplaza el antiguo "mode" de Sway (que aparecía en waybar, en inglés) por un
# menú wofi en español. Las capturas de IMAGEN se guardan en ~/Pictures y ADEMÁS
# se copian al portapapeles; los VIDEO se guardan en ~/Videos (sin portapapeles).
#
# Se invoca con $mod+Print (features/screenshots.conf).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carpetas XDG con fallback (xdg-user-dir no está instalado en este sistema).
pictures_dir() {
  local base
  if [[ -n "${XDG_PICTURES_DIR:-}" ]]; then
    base="${XDG_PICTURES_DIR}"
  elif [[ -d "${HOME}/Pictures" ]]; then
    base="${HOME}/Pictures"
  else
    base="${HOME}/Imágenes"
  fi
  printf '%s\n' "${base}/Screenshots"
}

videos_dir() {
  local d="${XDG_VIDEOS_DIR:-}"
  if [[ -n "${d}" ]]; then printf '%s\n' "${d}"; return; fi
  printf '%s\n' "${HOME}/Videos"
}

# Geometría de la ventana enfocada, o la lista de todas las ventanas visibles
# (para pasársela a slurp como "hints" y elegir una con el mouse).
focused_window_geom() {
  swaymsg -t get_tree | jq -j '.. | select(.type?) | select(.focused).rect | "\(.x),\(.y) \(.width)x\(.height)"'
}
all_windows_geom() {
  swaymsg -t get_tree | jq -r '.. | select(.pid? and .visible?) | .rect | "\(.x),\(.y) \(.width)x\(.height)"'
}
focused_output() {
  swaymsg -t get_outputs | jq -r '.[] | select(.focused) | .name'
}

# capturar_imagen <tipo> <modo> [valor]
#   modo: region (valor=geometría) | full | output (valor=nombre de salida)
capturar_imagen() {
  local tipo="$1" modo="$2" valor="${3:-}" dir archivo
  dir="$(pictures_dir)"
  mkdir -p "${dir}"
  archivo="${dir}/captura_${tipo}_$(date +%Y%m%d_%H%M%S).png"

  case "${modo}" in
    full)   grim "${archivo}" ;;
    output) grim -o "${valor}" "${archivo}" ;;
    *)      grim -g "${valor}" "${archivo}" ;;
  esac

  # Guardar Y copiar al portapapeles.
  wl-copy < "${archivo}"
  notify-send -i "${archivo}" "Captura guardada" \
    "$(basename "${archivo}") · copiada al portapapeles" 2>/dev/null || true
}

grabar_video() {
  local modo="$1"
  "${SCRIPT_DIR}/swpy-recorder.sh" "${modo}"
}

main() {
  local opciones seleccion geom out
  opciones=(
    "Capturar área"
    "Capturar ventana activa"
    "Capturar ventana (elegir)"
    "Capturar pantalla completa"
    "Capturar monitor enfocado"
    "Grabar pantalla completa (iniciar/detener)"
    "Grabar área (iniciar/detener)"
  )

  if ! seleccion="$(printf '%s\n' "${opciones[@]}" \
      | wofi --dmenu --insensitive --cache-file /dev/null --prompt 'Capturas')"; then
    exit 0
  fi
  [[ -z "${seleccion}" ]] && exit 0

  case "${seleccion}" in
    "Capturar área")
      geom="$(slurp)" || exit 0
      capturar_imagen area region "${geom}"
      ;;
    "Capturar ventana activa")
      geom="$(focused_window_geom)"
      [[ -n "${geom}" ]] || { notify-send "Captura" "No hay ventana enfocada"; exit 1; }
      capturar_imagen ventana region "${geom}"
      ;;
    "Capturar ventana (elegir)")
      geom="$(all_windows_geom | slurp)" || exit 0
      capturar_imagen ventana region "${geom}"
      ;;
    "Capturar pantalla completa")
      capturar_imagen completa full
      ;;
    "Capturar monitor enfocado")
      out="$(focused_output)"
      [[ -n "${out}" ]] || { notify-send "Captura" "No pude detectar el monitor"; exit 1; }
      capturar_imagen monitor output "${out}"
      ;;
    "Grabar pantalla completa (iniciar/detener)")
      grabar_video full
      ;;
    "Grabar área (iniciar/detener)")
      grabar_video area
      ;;
  esac
}

main "$@"
