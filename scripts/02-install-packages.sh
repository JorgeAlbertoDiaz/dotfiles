#!/usr/bin/env bash
# 02-install-packages: lee uno o varios archivos de packages/*.txt e
# instala los paquetes listados con zypper.
#
# Uso: 02-install-packages.sh <archivo1.txt> [archivo2.txt ...]
# Los archivos se buscan dentro de la carpeta packages/.
#
# Opcional: exportar ZYPPER_OPTS para añadir flags a zypper
# (ej. "--auto-agree-with-licenses").
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

PACKAGES_DIR="$(dirname "${SCRIPT_DIR}")/packages"
ZYPPER_OPTS="${ZYPPER_OPTS:--n}"

if [[ $# -eq 0 ]]; then
  error "Uso: 02-install-packages.sh <archivo.txt> ..."
  exit 1
fi

for file in "$@"; do
  file="${PACKAGES_DIR}/${file}"
  if [[ ! -f "${file}" ]]; then
    error "El archivo de paquetes no existe: ${file}"
    exit 1
  fi

  info "Leyendo paquetes de: $(basename "${file}")"

  local_pkgs=()
  while IFS= read -r line || [[ -n "${line}" ]]; do
    # Quitar comentarios (#) y espacios sobrantes.
    pkg="${line%%#*}"
    pkg="${pkg//[[:space:]]/}"
    [[ -z "${pkg}" ]] && continue
    local_pkgs+=("${pkg}")
  done < "${file}"

  if [[ ${#local_pkgs[@]} -eq 0 ]]; then
    warn "Sin paquetes en ${file}. Omitiendo."
    continue
  fi

  info "Instalando: ${local_pkgs[*]}"
  # shellcheck disable=SC2086
  as_root zypper ${ZYPPER_OPTS} in "${local_pkgs[@]}"
  ok "Instalados ${#local_pkgs[@]} paquete(s) de $(basename "${file}")"
done

ok "Instalación de paquetes completada"