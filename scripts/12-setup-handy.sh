#!/usr/bin/env bash
# 12-setup-handy: instala Handy (dictado por voz offline) desde el RPM oficial
# de GitHub Releases, verificando el SHA-256, y deja los ajustes por defecto
# del repo en el directorio de datos de la app.
#
# Por qué un script y no packages/: Handy no está en repo-oss ni en Packman;
# el RPM se publica en GitHub Releases. El pin de versión + SHA-256 evita que
# una reinstalación baje un binario distinto al verificado.
#
# Uso: 12-setup-handy.sh [--quiet] [--force]
#   --quiet  suprime info/ok (warn/error siempre salen)
#   --force  reinstala aunque la versión pinneada ya esté instalada
#
# Requiere: instalador de paquetes ya corrido con packages/handy.txt, o al
# menos zypper con acceso a repo-oss (lo invoca para resolver dependencias).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

REPO_DIR="$(dirname "${SCRIPT_DIR}")"
PLANTILLA_AJUSTES="${REPO_DIR}/config/home/.local/share/com.pais.handy/settings_store.json"

# ---------------------------------------------------------------------------
# Pin de versión: actualizar a mano tras verificar el release en GitHub.
#   https://github.com/cjpais/Handy/releases
# ---------------------------------------------------------------------------
readonly HANDY_VERSION="0.9.8"
readonly HANDY_SHA256="7038045edb560bb5497503541b1c43ce6b467b796169d20accd4e17210c60baf"

FORCE=0
for arg in "$@"; do
  case "${arg}" in
    --quiet) export QUIET=1 ;;
    --force) FORCE=1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Ya instalado: no se reinstala salvo --force.
# ---------------------------------------------------------------------------
if rpm -q handy &>/dev/null && [[ ${FORCE} -eq 0 ]]; then
  ok "Handy ya está instalado: $(rpm -q --qf '%{VERSION}-%{RELEASE}\n' handy)"
  exit 0
fi

case "$(uname -m)" in
  x86_64)  rpm_arch="x86_64" ;;
  aarch64) rpm_arch="aarch64" ;;
  *)
    error "Arquitectura no soportada para Handy: $(uname -m)"
    exit 1
    ;;
esac

if ! command -v curl &>/dev/null; then
  error "curl no está disponible."
  exit 1
fi

# ---------------------------------------------------------------------------
# Descarga + verificación de integridad
# ---------------------------------------------------------------------------
rpm_name="Handy-${HANDY_VERSION}-1.${rpm_arch}.rpm"
rpm_url="https://github.com/cjpais/Handy/releases/download/v${HANDY_VERSION}/${rpm_name}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

info "Descargando ${rpm_name}..."
if ! curl -fsSL -o "${tmp_dir}/${rpm_name}" "${rpm_url}"; then
  error "No se pudo descargar ${rpm_url}"
  exit 1
fi

info "Verificando SHA-256..."
sha_obtenido="$(sha256sum "${tmp_dir}/${rpm_name}" | awk '{print $1}')"
if [[ "${sha_obtenido}" != "${HANDY_SHA256}" ]]; then
  error "SHA-256 no coincide para ${rpm_name}."
  error "  esperado: ${HANDY_SHA256}"
  error "  obtenido: ${sha_obtenido}"
  error "El release cambió o la descarga se corrompió: verificá el hash en GitHub antes de seguir."
  exit 1
fi
ok "SHA-256 verificado"

# ---------------------------------------------------------------------------
# Instalación. El RPM no viene firmado con llaves de openSUSE, así que
# --allow-unsigned-rpm es obligatorio para que zypper no corte con un prompt
# interactivo en modo -n. Las dependencias salen de repo-oss.
# ---------------------------------------------------------------------------
info "Instalando con zypper (resuelve dependencias desde repo-oss)..."
as_root zypper -n in --allow-unsigned-rpm "${tmp_dir}/${rpm_name}"

if ! command -v handy &>/dev/null; then
  error "zypper terminó sin errores pero 'handy' no quedó en PATH."
  exit 1
fi
ok "Handy instalado: $(rpm -q --qf '%{VERSION}-%{RELEASE}\n' handy)"

# ---------------------------------------------------------------------------
# Ajustes por defecto (español, Whisper large-v3, pegado por portapapeles).
# Los ajustes viven en el directorio de DATOS de la app (no en ~/.config):
#   ~/.local/share/com.pais.handy/settings_store.json
# El componente "Dotfiles" también deja este archivo; acá se cubre el caso de
# instalar Handy sin aplicar dotfiles. Nunca pisa ajustes ya existentes.
# ---------------------------------------------------------------------------
ajustes_destino="${XDG_DATA_HOME:-${HOME}/.local/share}/com.pais.handy/settings_store.json"
if [[ -f "${PLANTILLA_AJUSTES}" && ! -f "${ajustes_destino}" ]]; then
  mkdir -p "$(dirname "${ajustes_destino}")"
  cp -a "${PLANTILLA_AJUSTES}" "${ajustes_destino}"
  ok "Ajustes por defecto aplicados: ${ajustes_destino}"
elif [[ -f "${ajustes_destino}" ]]; then
  info "Se conservan los ajustes existentes: ${ajustes_destino}"
else
  warn "No se encontró la plantilla de ajustes: ${PLANTILLA_AJUSTES}"
fi

# ---------------------------------------------------------------------------
# Siguientes pasos (no se automatizan: dependen de la sesión gráfica).
# ---------------------------------------------------------------------------
cat <<'EOF'

  Handy quedó instalado. Pasos que faltan, una sola vez:

  1. Abrí Handy desde el lanzador (o ejecutá: handy).
  2. En el onboarding elegí el modelo "Whisper Large v3" (1,55 GB, entra en
     los 3 GB de VRAM de la GTX 1060). Es el de mejor WER en español y el
     único que permite fijar el idioma a mano.
  3. Verificá en Ajustes: Idioma = Spanish, Método de pegado = Clipboard.
  4. Atajo para dictar:
       sway → Super+Shift+d   (bindsym en config/sway/keybindings/applications.conf)
       i3   → Super+Shift+d   (config/i3/config.d/60-handy.conf)

EOF
