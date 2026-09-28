#!/usr/bin/env bash
# 09-setup-nvim: prepara el estado mutable de Neovim fuera de config/nvim/.
#
# Uso: 09-setup-nvim.sh [--update] [--quiet]
#
#   --update   Actualiza todo el set con ':Lazy! update', sin preguntar. Respeta
#              el lockfile y el pin de versión de cada spec.
#   --quiet    Silencia los mensajes de progreso (info/ok). Los avisos (warn)
#              y los errores siempre se muestran.
#
# Orden de ejecución: primero 04-setup-dotfiles.sh (que deja la config en
# ~/.config/nvim), después este script. Al revés no funciona y el script lo
# avisa en vez de fallar en silencio.
#
# Qué hace:
#   - Verifica que git y nvim estén disponibles y que la config esté desplegada.
#   - Clona lazy.nvim en ${XDG_DATA_HOME:-~/.local/share}/nvim/lazy/ si no está.
#   - Corre Neovim en headless una vez (':Lazy! install') para que lazy clone el
#     resto del set.
#   - Es idempotente: la segunda vez no clona nada y solo informa.
#
# Ruido esperado: lazy.nvim muestra "E150: No es un directorio" durante su tarea
# interna de docs al pedir :helptags sobre plugins que no tienen directorio
# doc/ (nvim-go, mini.comment, plenary, telescope, mason, ...). Es cosmético,
# no frena la instalación y no aparece en un arranque normal.
#
# Dónde vive cada cosa:
#   ~/.config/nvim        configuración declarativa, la trae 04-setup-dotfiles.sh
#                         desde config/nvim/ de este repo.
#   ~/.local/share/nvim    plugins (lazy.nvim y el set de 16), ESTE script.
#   ~/.local/state/nvim    shada y log de lazy.
#   ~/.config/nvim/lazy-lock.json
#                         lockfile. Ojo: vive en el DIRECTORIO DE CONFIG, no
#                         junto a los plugins, porque lazy lo escribe en
#                         stdpath("config"). Por eso 04-setup-dotfiles.sh con
#                         reset=1 lo borra y se regenera en el próximo update.
#
# Por qué no usa "nvim -u config/nvim/init.lua":
#   Con -u <ruta>, Neovim SÍ ejecuta ese archivo pero NO agrega su directorio
#   al 'runtimepath'. Entonces require("config.options") falla con E5113 y el
#   arranque entero se cae. El rtp lo arma Neovim solo a partir del directorio
#   de configuración estándar, y por eso este script materializa la config ya
#   desplegada en ~/.config/nvim en lugar de la del repo.
#
# Por qué no hace "git pull" de lazy.nvim:
#   El gestor NO lleva pin de versión: folke/lazy.nvim no tiene rama `stable`
#   (solo `main`), así que "version = stable" no resuelve a nada y el propio
#   lazy la resuelve a la rama por defecto en silencio. El pin real vive en
#   config/nvim/lazy-lock.json, que se commitea y despliega con la config.
#   Actualizar el gestor a mano compite con eso, y además el clon queda en
#   HEAD detachado, donde "git pull --ff-only" falla siempre con "no estás en
#   una rama". Acá las actualizaciones pasan por lazy, no por git.
#
# Nunca escribe dentro de ~/.config/nvim: es el directorio que
# 04-setup-dotfiles.sh borra con reset=1.
# No usa sudo: todo queda en el espacio del usuario.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

REPO_DIR="$(dirname "${SCRIPT_DIR}")"
REPO_CONFIG_DIR="${REPO_DIR}/config/nvim"

# Mismos destinos que dentro de Neovim.
NVIM_DATA_DIR="${XDG_DATA_HOME:-${HOME}/.local/share}/nvim"
PLUGINS_DIR="${NVIM_DATA_DIR}/lazy"
NVIM_CONFIG_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/nvim"
LOCKFILE="${NVIM_CONFIG_DIR}/lazy-lock.json"

# "url|directorio" — el directorio es el nombre dentro de PLUGINS_DIR.
# El separador es "|" y no ":" porque la URL ya contiene "https:".
#
# Esta tabla NO es la lista de plugins que se instalan: esa vive declarativa en
# config/nvim/lua/plugins/*.lua y lazy.nvim la lee. Sólo se declara aquí el
# gestor, porque es lo único que hace falta para que el arranque funcione.
PLUGINS=(
  "https://github.com/folke/lazy.nvim|lazy.nvim"
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
    error "git no está disponible; lazy.nvim no se puede clonar."
    warn "Instálalo con: sudo zypper in git"
    exit 1
  fi
}

require_nvim() {
  if ! command -v nvim &>/dev/null; then
    error "nvim no está disponible; no hay configuración que preparar."
    warn "Instálalo con: sudo zypper in neovim"
    exit 1
  fi
  if [[ ! -f "${NVIM_CONFIG_DIR}/init.lua" ]]; then
    error "No hay configuración desplegada en ${NVIM_CONFIG_DIR}/init.lua"
    warn "Este script no crea la configuración: la trae 04-setup-dotfiles.sh."
    warn "Corré 04 primero y después volvé a correr este script."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# Instalación
# ---------------------------------------------------------------------------

# Un destino que ya existe NO se vuelve a clonar. El gestor se clona sin
# --depth ni --branch a propósito: --branch deja HEAD detachado, y el
# bootstrap de init.lua tampoco lo usa por la misma razón. El pin de versión
# lo aplica lazy, no el clon.
#
# El clon NO lleva '|| true' a propósito: si falla hay que saberlo en lugar de
# seguir como si el gestor estuviera instalado.
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
    return 0
  fi

  info "Clonando ${name} en ${dest}..."
  git clone "${url}" "${dest}"
  ok "Instalado: ${name}"
}

# arrancar_neovim <comando_lazy>: corre un comando :Lazy en headless.
#
# "Lazy! install" y no "Lazy sync": el "!" de :Lazy es `wait`, y los clones
# quedan en vuelo sin él, con lo que el "+qa" cerraría Neovim antes de
# terminar. Y sync NO porque Manage.sync() empieza con clean(), que borra los
# plugins ya instalados: para preparar una máquina eso no aporta nada y obliga
# a volver a descargar todo en cada corrida.
#
# Sin -u a propósito: ver la nota de cabecera sobre 'runtimepath'.
arrancar_neovim() {
  local accion="$1" descripcion="$2"
  info "${descripcion}..."
  if nvim --headless "+${accion}" +qa; then
    ok "Hecho: ${descripcion}"
  else
    error "Neovim falló en: ${descripcion}"
    warn "Revisá la red y volvé a correrlo. La configuración base sigue funcionando."
    return 1
  fi
}

# materializar_plugins: primer arranque en headless. lazy clona el set completo
# declarado en config/nvim/lua/plugins/ y escribe lazy-lock.json.
materializar_plugins() {
  arrancar_neovim "Lazy! install" "Materializando el set de plugins (Lazy! install)"
}

actualizar_plugins() {
  arrancar_neovim "Lazy! update" "Actualizando el set de plugins (Lazy! update)"
}

resumen() {
  local entry name count
  for entry in "${PLUGINS[@]}"; do
    name="${entry##*|}"
    if [[ -d "${PLUGINS_DIR}/${name}" ]]; then
      ok "  ${name}: instalado"
    else
      warn "  ${name}: no instalado (init.lua lo reintenta en el próximo arranque)"
    fi
  done

  if [[ -f "${LOCKFILE}" ]]; then
    ok "  lockfile: ${LOCKFILE}"
  else
    # Ausente es lo normal la primera vez: el lockfile se escribe al resolver
    # commits, y este script corre antes de que haya hecho un update.
    info "  lockfile: aún no existe (lazy lo escribe en ${NVIM_CONFIG_DIR})"
  fi

  # El set real lo cuenta lazy.nvim, no esta tabla.
  if [[ -d "${PLUGINS_DIR}" ]]; then
    count="$(find "${PLUGINS_DIR}" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)"
    ok "  directorios de plugin en ${PLUGINS_DIR}: ${count}"
  fi
}

# ---------------------------------------------------------------------------
# Flujo
# ---------------------------------------------------------------------------
require_git
require_nvim

info "Configuración en el repo:  ${REPO_CONFIG_DIR}"
info "Configuración desplegada: ${NVIM_CONFIG_DIR}"
info "Directorio de datos:      ${NVIM_DATA_DIR}"
mkdir -p "${PLUGINS_DIR}"

for entry in "${PLUGINS[@]}"; do
  install_plugin "${entry%%|*}" "${entry##*|}"
done

materializar_plugins

if [[ ${UPDATE} -eq 1 ]]; then
  actualizar_plugins
fi

ok "Resumen de plugins de Neovim en ${NVIM_DATA_DIR}:"
resumen
ok "Preparación de Neovim completada"
