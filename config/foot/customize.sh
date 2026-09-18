#!/usr/bin/env bash
# Customiza la fuente de foot en este directorio.
# Uso: customize.sh <familia> [tamaño]
#
# Reescribe la línea "font=" de foot.ini conservando el resto de opciones.
# Se ejecuta sobre el archivo del repo; luego copia el archivo al sistema con scripts/04-setup-dotfiles.sh.
set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${APP_DIR}/foot.ini"

family="${1:-}"
size="${2:-}"

if [[ -z "${family}" ]]; then
  echo "Uso: $(basename "$0") <familia> [tamaño]" >&2
  exit 1
fi

existing_size="$(sed -nE 's/^font=.*:size=([0-9]+)$/\1/p' "${CONFIG_FILE}" | head -n1)"
size="${size:-${existing_size}}"

if [[ -n "${size}" ]]; then
  sed -i -E "s/^font=.*/font=${family}:size=${size}/" "${CONFIG_FILE}"
else
  sed -i -E "s/^font=.*/font=${family}/" "${CONFIG_FILE}"
fi

echo "foot.ini actualizado: font=${family}:size=${size}"