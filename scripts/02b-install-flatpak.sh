#!/usr/bin/env bash
# 02b-install-flatpak: instala las aplicaciones Flatpak listadas en
# packages/flatpak-apps.txt desde el remote flathub.
#
# Uso: 02b-install-flatpak.sh
#
# Requisito: flatpak debe estar instalado (paquete "flatpak" en
# packages/base.txt). Si no está presente, el paso se omite SIN tocar
# flathub. Registra el remote flathub con --if-not-exists y luego
# instala cada appid (1 por línea; las líneas que empiecen por # se
# ignoran).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

REPO_DIR="$(dirname "${SCRIPT_DIR}")"
FLATPAK_APPS="${REPO_DIR}/packages/flatpak-apps.txt"

# ---------------------------------------------------------------------------
# 1) Requisito: flatpak presente ANTES de tocar flathub
# ---------------------------------------------------------------------------
if ! command -v flatpak &>/dev/null; then
  warn "flatpak no instalado — instalalo vía packages/base.txt primero"
  exit 0
fi

# ---------------------------------------------------------------------------
# 2) Remote flathub (idempotente)
# ---------------------------------------------------------------------------
info "Registrando el remote flathub (si no existe) a nivel de usuario..."
if ! flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo; then
  error "No se pudo registrar el remote flathub a nivel de usuario"
  exit 1
fi
ok "Remote flathub disponible a nivel de usuario"

# ---------------------------------------------------------------------------
# 3) Aplicaciones Flatpak
# ---------------------------------------------------------------------------
if [[ ! -f "${FLATPAK_APPS}" ]]; then
  error "El archivo de aplicaciones no existe: ${FLATPAK_APPS}"
  exit 1
fi

apps=()
while IFS= read -r line || [[ -n "${line}" ]]; do
  # Quitar comentarios (#) y espacios sobrantes.
  app="${line%%#*}"
  app="${app//[[:space:]]/}"
  [[ -z "${app}" ]] && continue
  apps+=("${app}")
done < "${FLATPAK_APPS}"

if [[ ${#apps[@]} -eq 0 ]]; then
  warn "Sin aplicaciones en ${FLATPAK_APPS}. Omitiendo."
  exit 0
fi

info "Instalando ${#apps[@]} aplicación(es) Flatpak desde flathub..."
for app in "${apps[@]}"; do
  info "Instalando: ${app}"
  flatpak install -y --noninteractive --user flathub "${app}"
  ok "Instalada: ${app}"
done

ok "Instalación de aplicaciones Flatpak completada"