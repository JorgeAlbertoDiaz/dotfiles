#!/usr/bin/env bash
# 01-install-gum: instala gum usando solo bash + curl si no está presente.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if command -v gum &>/dev/null; then
  ok "gum ya está instalado: $(gum --version)"
  exit 0
fi

info "gum no está instalado. Instalando con bash + curl..."

if ! command -v curl &>/dev/null; then
  error "curl no está disponible. Instalando curl primero..."
  as_root zypper -n in curl
fi

arch="$(uname -m)"
case "${arch}" in
  x86_64)  gum_arch="x86_64" ;;
  aarch64) gum_arch="arm64" ;;
  *)
    error "Arquitectura no soportada para gum: ${arch}"
    exit 1
    ;;
esac

info "Obteniendo última versión de gum desde GitHub..."
tag="$(curl -fsSL https://api.github.com/repos/charmbracelet/gum/releases/latest \
  | grep -oP '"tag_name"\s*:\s*"\K[^"]+' || true)"

if [[ -z "${tag}" ]]; then
  error "No se pudo obtener la última versión de gum desde GitHub."
  exit 1
fi

version="${tag#v}"
archive="gum_${version}_Linux_${gum_arch}.tar.gz"
url="https://github.com/charmbracelet/gum/releases/download/${tag}/${archive}"

info "Descargando ${url}..."
tmpdir="$(mktemp -d)"
trap 'rm -rf "${tmpdir}"' EXIT

curl -fsSL "${url}" | tar -xz -C "${tmpdir}"

if [[ ! -f "${tmpdir}/gum" ]]; then
  error "El binario gum no se encontró dentro del archivo descargado."
  exit 1
fi

if [[ ${EUID} -eq 0 ]]; then
  install -Dm755 "${tmpdir}/gum" /usr/local/bin/gum
else
  sudo install -Dm755 "${tmpdir}/gum" /usr/local/bin/gum
fi

ok "gum instalado: $(gum --version)"