#!/usr/bin/env bash
# 08-setup-zsh: instala los plugins de zsh que carga config/home/.zshrc.
#
# Uso: 08-setup-zsh.sh [--update] [--quiet]
#
#   --update   Fuerza la actualización (git pull --ff-only) de los plugins ya
#              instalados, sin preguntar. Sin este flag ofrece actualizarlos
#              todos en bloque (valor por defecto: no).
#   --quiet    Silencia los mensajes de progreso (info/ok). Los avisos (warn)
#              y los errores siempre se muestran.
#
# Qué hace:
#   - Verifica que git y fzf estén disponibles.
#   - Clona zsh-autosuggestions y zsh-syntax-highlighting en
#     ${XDG_DATA_HOME:-~/.local/share}/zsh/plugins/ con clones superficiales
#     (--depth 1): para usarlos no hace falta conservar la historia completa.
#   - Es idempotente: si el directorio ya existe no clona de nuevo, ofrece
#     actualizarlo.
#
# No usa sudo: todo queda en el espacio del usuario.
# El .zshrc carga cada plugin con una guarda, así que el shell funciona igual
# si este script nunca se ejecutó.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

PLUGINS_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/zsh/plugins"

# "url|directorio" — el directorio es el nombre dentro de PLUGINS_DIR.
# El separador es "|" y no ":" porque la URL ya contiene "https:".
# El orden importa: el .zshrc carga los plugins de abajo hacia arriba.
PLUGINS=(
  "https://github.com/zsh-users/zsh-autosuggestions|zsh-autosuggestions"
  "https://github.com/zsh-users/zsh-syntax-highlighting|zsh-syntax-highlighting"
)

UPDATE=0
for arg in "$@"; do
  case "${arg}" in
    --update) UPDATE=1 ;;
    --quiet)  QUIET=1 ;;
    *)        warn "Argumento desconocido ignorado: ${arg}" ;;
  esac
done

# ---------------------------------------------------------------------------
# Comprobaciones previas
# ---------------------------------------------------------------------------
require_git() {
  if ! command -v git &>/dev/null; then
    error "git no está disponible; no se pueden clonar los plugins de zsh."
    warn "Instálalo con: sudo zypper in git"
    exit 1
  fi
}

check_fzf() {
  if ! command -v fzf &>/dev/null; then
    warn "fzf no está instalado: se pierde la búsqueda incremental del historial."
    warn "Está declarado en packages/shell.txt; instálalo con: sudo zypper in fzf"
  fi
}

# ---------------------------------------------------------------------------
# Instalación
# ---------------------------------------------------------------------------
update_plugin() {
  local dir="$1" name="$2"
  info "Actualizando ${name} (${dir})..."
  git -C "${dir}" pull --ff-only
  ok "Actualizado: ${name}"
}

# Un destino que ya existe NO se vuelve a clonar: se registra en INSTALADOS
# para ofrecer la actualización en bloque más abajo.
# El clone no lleva '|| true' a propósito; si falla hay que saberlo en lugar
# de seguir como si el plugin estuviera instalado.
install_plugin() {
  # Ojo: en bash, "local a=1 b=$a" deja "$a" vacía en "b" (todas las variables
  # se declaran y se limpian antes de asignar). Por eso se declaran los nombres
  # juntos y se asignan en líneas separadas.
  local url name dest
  url="$1"
  name="$2"
  dest="${PLUGINS_DIR}/${name}"

  if [[ -d "${dest}" ]]; then
    ok "Ya instalado: ${name}"
    # La actualización se ofrece en bloque luego de clonar los faltantes.
    INSTALADOS+=("${name}")
    return 0
  fi

  info "Clonando ${name} en ${dest}..."
  git clone --depth 1 "${url}" "${dest}"
  ok "Instalado: ${name}"
}

resumen() {
  local entry name
  for entry in "${PLUGINS[@]}"; do
    name="${entry##*|}"
    if [[ -d "${PLUGINS_DIR}/${name}" ]]; then
      ok "  ${name}: instalado"
    else
      warn "  ${name}: no instalado (el .zshrc lo omite)"
    fi
  done
}

# ---------------------------------------------------------------------------
# Flujo
# ---------------------------------------------------------------------------
require_git
check_fzf

info "Directorio de plugins: ${PLUGINS_DIR}"
mkdir -p "${PLUGINS_DIR}"

INSTALADOS=()
for entry in "${PLUGINS[@]}"; do
  install_plugin "${entry%%|*}" "${entry##*|}"
done

# Actualización en bloque: una sola confirmación (default: sí) en vez de un
# s/N por plugin. --update fuerza sin preguntar.
if [[ ${#INSTALADOS[@]} -gt 0 ]]; then
  if [[ ${UPDATE} -eq 1 ]] || confirm_yes "¿Actualizar los ${#INSTALADOS[@]} plugins de zsh (git pull --ff-only)?"; then
    for name in "${INSTALADOS[@]}"; do
      update_plugin "${PLUGINS_DIR}/${name}" "${name}"
    done
  else
    info "Se mantiene la versión actual de los plugins."
  fi
fi

ok "Resumen de plugins de zsh en ${PLUGINS_DIR}:"
resumen
ok "Instalación de plugins de zsh completada"
