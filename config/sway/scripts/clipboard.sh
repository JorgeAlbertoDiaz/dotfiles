#!/usr/bin/env bash
# clipboard.sh — historial del portapapeles (cliphist) con wofi.
#
# El watcher definido en features/autostart.conf
# (`wl-paste --watch cliphist store`) va guardando lo copiado, texto e imágenes.
# Este script muestra ese historial en wofi y, al elegir una entrada, la
# decodifica y la vuelve a poner en el portapapeles para pegarla donde haga falta.
#
# Se invoca con $mod+Shift+v (keybindings/media.conf).
set -euo pipefail

if ! command -v cliphist >/dev/null 2>&1; then
  notify-send "Portapapeles" "Falta cliphist (sudo zypper in cliphist)" 2>/dev/null || true
  exit 1
fi

# cliphist list muestra "id<TAB>texto" (para binarios, un marcador). wofi
# devuelve la línea elegida y `cliphist decode` la restaura.
if ! sel="$(cliphist list | wofi --dmenu --insensitive --cache-file /dev/null --prompt 'Portapapeles')"; then
  exit 0
fi
[[ -z "${sel}" ]] && exit 0

cliphist decode <<< "${sel}" | wl-copy
notify-send "Portapapeles" "Contenido copiado; pegalo con Ctrl+V" 2>/dev/null || true
