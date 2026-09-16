#!/usr/bin/env bash
# 01-install-gum: instala gum preferentemente desde repo-oss (zypper),
# con fallback al binario de GitHub Releases si zypper no lo tiene.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if command -v gum &>/dev/null; then
  ok "gum ya está instalado: $(gum --version)"
  exit 0
fi

info "gum no está instalado. Intentando instalarlo con zypper..."
if as_root zypper -n in gum; then
  if command -v gum &>/dev/null; then
    ok "gum instalado desde repo-oss: $(gum --version)"
    exit 0
  fi
  warn "zypper terminó sin errores pero gum no quedó disponible."
fi
warn "zypper no logró instalar gum; usando el binario de GitHub Releases."

# ---------------------------------------------------------------------------
# Fallback: binario desde GitHub Releases (bash + curl, sin otras dependencias)
# ---------------------------------------------------------------------------

ensure_xdg_dirs >/dev/null

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

download_dir="$(downloads_dir)"
archive_path="${download_dir}/${archive}"

# El archivo se descarga en la carpeta de descargas y se elimina al terminar.
cleanup_archive() {
  if [[ -n "${archive_path:-}" && -f "${archive_path}" ]]; then
    info "Eliminando archivo descargado: ${archive_path}"
    rm -f "${archive_path}"
  fi
}
trap cleanup_archive EXIT

info "Descargando ${archive_path}..."
curl -fsSL --output "${archive_path}" "${url}"

tmpdir="$(mktemp -d)"
trap 'cleanup_archive; rm -rf "${tmpdir}"' EXIT

info "Extrayendo en ${tmpdir}..."
tar -xzf "${archive_path}" -C "${tmpdir}"

# El binario puede estar en la raíz (versiones antiguas) o dentro de un
# subdirectorio con el nombre del paquete (v2.0.1+).
gum_bin="$(find "${tmpdir}" -type f -name gum -print -quit 2>/dev/null || true)"
if [[ -z "${gum_bin}" ]]; then
  error "El binario gum no se encontró dentro del archivo descargado."
  exit 1
fi

info "Instalando ${gum_bin} en /usr/local/bin/gum"
if [[ ${EUID} -eq 0 ]]; then
  install -Dm755 "${gum_bin}" /usr/local/bin/gum
else
  sudo install -Dm755 "${gum_bin}" /usr/local/bin/gum
fi

if command -v gum &>/dev/null; then
  ok "gum instalado desde GitHub: $(gum --version)"
else
  warn "gum instalado en /usr/local/bin/gum, pero no está en el PATH de esta sesión."
  warn "Reabre la terminal y ejecuta: gum --version"
fi