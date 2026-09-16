#!/usr/bin/env bash
# Funciones compartidas para los scripts de instalación.
# Solo usa características de bash estándar para poder usarse
# incluso antes de instalar gum.

set -euo pipefail

readonly RESET='\033[0m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[0;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'

info()  { printf "${CYAN}[INFO]${RESET} %s\n" "$*"; }
warn()  { printf "${YELLOW}[WARN]${RESET} %s\n" "$*"; }
error() { printf "${RED}[ERROR]${RESET} %s\n" "$*" >&2; }
ok()    { printf "${GREEN}[OK]${RESET} %s\n" "$*"; }

# Ejecuta un comando como root (directo si ya es root, con sudo si no).
as_root() {
  if [[ ${EUID} -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# confirm "mensaje" -> 0 si sí, 1 si no
confirm() {
  local msg="$1" resp
  while true; do
    read -r -p "${msg} [s/N]: " resp
    case "${resp}" in
      s|S|y|Y) return 0 ;;
      n|N|"")  return 1 ;;
      *)       warn "Respuesta no válida: ${resp}" ;;
    esac
  done
}