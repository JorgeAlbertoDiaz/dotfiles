#!/usr/bin/env bash
# Customiza la fuente de sway en este paquete stow.
# Uso: customize.sh <familia> [tamaño]
#
# Reescribe la línea "font pango:" del config de sway conservando el resto.
# Se ejecuta sobre el archivo del repo; el symlink de stow se actualiza solo.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${APP_DIR}/.config/sway/config"

family="${1:-}"
size="${2:-}"

if [[ -z "${family}" ]]; then
  echo "Uso: $(basename "$0") <familia> [tamaño]" >&2
  exit 1
fi

existing_size="$(sed -nE 's/^font pango:[^ ]+ ([0-9]+)$/\1/p' "${CONFIG_FILE}" | head -n1)"
size="${size:-${existing_size}}"

if [[ -n "${size}" ]]; then
  sed -i -E "s/^font pango:.*/font pango:${family} ${size}/" "${CONFIG_FILE}"
else
  sed -i -E "s/^font pango:.*/font pango:${family}/" "${CONFIG_FILE}"
fi

echo "sway config actualizado: font pango:${family} ${size}"