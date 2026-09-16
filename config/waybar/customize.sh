#!/usr/bin/env bash
# Customiza la fuente de waybar en este paquete stow.
# Uso: customize.sh <familia> [tamaño]
#
# Reescribe font-family y font-size de style.css conservando el resto.
# Se ejecuta sobre el archivo del repo; el symlink de stow se actualiza solo.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${APP_DIR}/.config/waybar/style.css"

family="${1:-}"
size="${2:-}"

if [[ -z "${family}" ]]; then
  echo "Uso: $(basename "$0") <familia> [tamaño]" >&2
  exit 1
fi

existing_size="$(sed -nE 's/font-size: ([0-9]+)px;/\1/p' "${CONFIG_FILE}" | head -n1)"
size="${size:-${existing_size}}"

sed -i -E "s/font-family:.*/font-family: \"${family}\";/" "${CONFIG_FILE}"
if [[ -n "${size}" ]]; then
  sed -i -E "s/font-size:.*/font-size: ${size}px;/" "${CONFIG_FILE}"
fi

echo "style.css actualizado: font-family ${family} tamaño ${size}px"