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

# QUIET=1 suprime info/ok (warn/error siempre visibles).
QUIET=${QUIET:-0}

# LOG_PREFIX se antepone a cada mensaje para sangrar la salida según el nivel
# de la operación (p. ej. "  " para el paso que corre un componente). Se
# exporta desde quien lo define para que los subprocesos lo hereden.
LOG_PREFIX=${LOG_PREFIX:-}

info()  { [[ ${QUIET} -eq 1 ]] || printf "${CYAN}[INFO]${RESET} %s%s\n" "${LOG_PREFIX}" "$*"; }
warn()  { printf "${YELLOW}[WARN]${RESET} %s%s\n" "${LOG_PREFIX}" "$*"; }
error() { printf "${RED}[ERROR]${RESET} %s%s\n" "${LOG_PREFIX}" "$*" >&2; }
ok()    { [[ ${QUIET} -eq 1 ]] || printf "${GREEN}[OK]${RESET} %s%s\n" "${LOG_PREFIX}" "$*"; }

# Ejecuta un comando como root (directo si ya es root, con sudo si no).
as_root() {
  if [[ ${EUID} -eq 0 ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

# has_gum -> 0 si gum está disponible y hay TTY interactiva.
has_gum() {
  command -v gum >/dev/null 2>&1 && [[ -t 0 && -t 1 ]]
}

# confirm "mensaje" -> 0 si sí, 1 si no (default: no).
# Usa gum si está disponible; si no, cae al prompt bash [s/N].
confirm() {
  local msg="$1" resp
  if has_gum; then
    gum confirm --default=false "${msg}"
    return $?
  fi
  while true; do
    read -r -p "${msg} [s/N]: " resp
    case "${resp}" in
      s|S|y|Y) return 0 ;;
      n|N|"")  return 1 ;;
      *)       warn "Respuesta no válida: ${resp}" ;;
    esac
  done
}

# confirm_yes "mensaje" -> 0 si sí, 1 si no (default: sí).
confirm_yes() {
  local msg="$1" resp
  if has_gum; then
    gum confirm --default=true "${msg}"
    return $?
  fi
  while true; do
    read -r -p "${msg} [S/n]: " resp
    case "${resp}" in
      s|S|y|Y|"") return 0 ;;
      n|N)        return 1 ;;
      *)          warn "Respuesta no válida: ${resp}" ;;
    esac
  done
}

# Directorios base XDG según las variables de entorno (o el estándar).
# Cada entrada tiene "nombre:ruta". Se devuelven con : separados.
xdg_dirs() {
  printf '%s\n' \
    "config:${XDG_CONFIG_HOME:-${HOME}/.config}" \
    "cache:${XDG_CACHE_HOME:-${HOME}/.cache}" \
    "data:${XDG_DATA_HOME:-${HOME}/.local/share}" \
    "state:${XDG_STATE_HOME:-${HOME}/.local/state}"
}

# Carpeta de descargas del usuario:
#   1. xdg-user-dir DOWNLOAD si está disponible
#   2. $XDG_DOWNLOAD_DIR si está definida
#   3. $HOME/Descargas si existe
#   4. $HOME/Downloads (se crea si falta)
downloads_dir() {
  local dir
  if command -v xdg-user-dir &>/dev/null \
      && dir="$(xdg-user-dir DOWNLOAD 2>/dev/null)" \
      && [[ -n "${dir}" && "${dir}" != "${HOME}" ]]; then
    printf '%s\n' "${dir}"
    mkdir -p "${dir}"
    return 0
  fi
  if [[ -n "${XDG_DOWNLOAD_DIR:-}" ]]; then
    printf '%s\n' "${XDG_DOWNLOAD_DIR}"
    mkdir -p "${XDG_DOWNLOAD_DIR}"
    return 0
  fi
  if [[ -d "${HOME}/Descargas" ]]; then
    printf '%s\n' "${HOME}/Descargas"
    return 0
  fi
  mkdir -p "${HOME}/Downloads"
  printf '%s\n' "${HOME}/Downloads"
}

# Verifica y crea (si faltan) los directorios XDG y la carpeta de descargas.
ensure_xdg_dirs() {
  local name dir
  while IFS=: read -r name dir; do
    [[ -z "${dir}" ]] && continue
    if [[ -d "${dir}" ]]; then
      ok "${dir} (${name}) existe"
    else
      # Crear un directorio es "algo que hacer": visible incluso con QUIET=1.
      QUIET=0 info "${dir} (${name}) no existe; creando..."
      mkdir -p "${dir}"
      QUIET=0 ok "${dir} (${name}) creado"
    fi
  done <<< "$(xdg_dirs)"

  mkdir -p "$(downloads_dir)"
  return 0
}