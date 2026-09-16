#!/usr/bin/env bash
# 04-setup-dotfiles: aplica los dotfiles con GNU Stow (symlinks)
# y cambia la shell por defecto a zsh.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

REPO_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_DIR="${REPO_DIR}/config"
HOME_DIR="${HOME}"

if [[ ! -d "${CONFIG_DIR}" ]]; then
  error "No existe la carpeta de configuraciones: ${CONFIG_DIR}"
  exit 1
fi

if ! command -v stow &>/dev/null; then
  info "GNU Stow no está instalado. Instalando..."
  as_root zypper -n in stow
fi

mapfile -t packages < <(find "${CONFIG_DIR}" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)

if [[ ${#packages[@]} -eq 0 ]]; then
  warn "No hay paquetes de configuración en ${CONFIG_DIR}"
  exit 1
fi

info "Aplicando dotfiles con stow: ${packages[*]}"
stow -v -d "${CONFIG_DIR}" -t "${HOME_DIR}" --ignore='^customize\.sh$' "${packages[@]}"
ok "Dotfiles aplicados con symlinks"

if command -v zsh &>/dev/null; then
  zsh_path="$(command -v zsh)"
  if [[ "${SHELL}" != *"/zsh" ]]; then
    if confirm "¿Cambiar la shell por defecto a zsh?"; then
      chsh -s "${zsh_path}"
      ok "Shell por defecto cambiada a ${zsh_path} (se aplicará al reabrir sesión)"
    else
      warn "Omitiendo cambio de shell por defecto"
    fi
  else
    ok "La shell por defecto ya es zsh"
  fi
else
  warn "zsh no está instalado; no se cambia la shell (instálalo con shell.txt)"
fi

ok "Configuración de dotfiles completada"