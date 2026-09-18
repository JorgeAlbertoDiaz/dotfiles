#!/usr/bin/env bash
# 00-xdg-dirs: muestra y verifica los directorios XDG del usuario,
# creándolos si no existen. También garantiza la carpeta de descargas.
#
# Uso independiente: ./scripts/00-xdg-dirs.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# --quiet suprime los mensajes de happy path (info/ok); warn/error siempre salen.
for arg in "$@"; do
  [[ "${arg}" == "--quiet" ]] && QUIET=1
done

info "Directorios base XDG:"
ensure_xdg_dirs

info "Carpeta de descargas: $(downloads_dir)"
ok "Entorno XDG listo"