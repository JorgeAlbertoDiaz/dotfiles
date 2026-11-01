#!/usr/bin/env bash
# Customiza la fuente de waybar en este directorio.
# Uso: customize.sh <familia> [tamaño]
#
# Reescribe font-family y font-size en TODOS los temas de themes/*.css
# (dark.css, light.css) conservando el resto.
#
# No toca style.css: desde el tema claro/oscuro ese archivo es un enlace
# simbólico al tema activo, y `sed -i` sobre un enlace lo reemplazaría por un
# archivo regular, rompiendo el cambio de tema (ver docs/tema-claro-oscuro.md).
# Se ejecuta sobre los archivos del repo; luego los copia al sistema
# scripts/04-setup-dotfiles.sh.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEMES_DIR="${APP_DIR}/themes"

family="${1:-}"
size="${2:-}"

if [[ -z "${family}" ]]; then
  echo "Uso: $(basename "$0") <familia> [tamaño]" >&2
  exit 1
fi

shopt -s nullglob
themes=("${THEMES_DIR}"/*.css)
shopt -u nullglob

if [[ ${#themes[@]} -eq 0 ]]; then
  echo "No hay temas en ${THEMES_DIR}; nada que actualizar." >&2
  exit 1
fi

existing_size="$(sed -nE 's/font-size: ([0-9]+)px;/\1/p' "${themes[0]}" | head -n1)"
size="${size:-${existing_size}}"

for theme in "${themes[@]}"; do
  sed -i -E "s/font-family:.*/font-family: \"${family}\";/" "${theme}"
  if [[ -n "${size}" ]]; then
    sed -i -E "s/font-size:.*/font-size: ${size}px;/" "${theme}"
  fi
done

echo "temas actualizados (${#themes[@]} archivos): font-family ${family} tamaño ${size}px"
