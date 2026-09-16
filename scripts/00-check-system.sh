#!/usr/bin/env bash
# 00-check-system: verifica que el sistema es openSUSE Tumbleweed.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [[ ! -r /etc/os-release ]]; then
  error "No se pudo leer /etc/os-release. Sistema no compatible."
  exit 1
fi

source /etc/os-release

if [[ "${ID}" != "opensuse-tumbleweed" && "${NAME}" != *"Tumbleweed"* ]]; then
  error "Este proyecto solo soporta openSUSE Tumbleweed."
  error "Sistema detectado: ${PRETTY_NAME:-${NAME:-desconocido}}"
  exit 1
fi

ok "Sistema compatible: ${PRETTY_NAME}"