#!/usr/bin/env bash
# 10-setup-mime-apps: configura aplicaciones por defecto para tipos MIME comunes.
#
# Usa xdg-mime para setear asociaciones sin sobreescribir mimeapps.list completo.
# Esto respeta otras asignaciones que el usuario ya tenga configuradas.
#
# Uso: ./scripts/10-setup-mime-apps.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# ---------------------------------------------------------------------------
# Asociaciones: tipo MIME → archivo .desktop
# ---------------------------------------------------------------------------
declare -A ASSOCIATIONS=(
  # PDFs → Zathura (visor ligero con soporte Vim-like)
  [application/pdf]="org.pwmt.zathura.desktop"
  [application/x-pdf]="org.pwmt.zathura.desktop"

  # Texto plano → mousepad (editor ligero de XFCE)
  [text/plain]="mousepad.desktop"

  # Imágenes → imv (visor minimalista para Wayland/X11)
  [image/png]="imv.desktop"
  [image/jpeg]="imv.desktop"
  [image/jpg]="imv.desktop"
  [image/webp]="imv.desktop"
  [image/gif]="imv.desktop"
  [image/bmp]="imv.desktop"
  [image/tiff]="imv.desktop"
  [image/x-portable-pixmap]="imv.desktop"
  [image/x-portable-graymap]="imv.desktop"
  [image/svg+xml]="imv.desktop"
)

info "Configurando aplicaciones por defecto..."

for mime in "${!ASSOCIATIONS[@]}"; do
  desktop="${ASSOCIATIONS[$mime]}"

  # Verificar que el .desktop exista en alguna ubicación estándar
  if ! ls /usr/share/applications/"${desktop}" \
          ~/.local/share/applications/"${desktop}" \
          /usr/local/share/applications/"${desktop}" 2>/dev/null >/dev/null; then
    warn "No se encontró ${desktop}; la asociación ${mime} quedará pendiente."
    continue
  fi

  xdg-mime default "${desktop}" "${mime}"
  info "  ${mime} → ${desktop}"
done

ok "Aplicaciones por defecto configuradas"
