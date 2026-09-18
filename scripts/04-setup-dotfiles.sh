#!/usr/bin/env bash
# 04-setup-dotfiles: copia los dotfiles a ~/.config/<app> (y home/ a $HOME)
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

# Copia el contenido de cada app a ~/.config/<app> (excepto home/).
# customize.sh es una herramienta del repo y no se copia.
shopt -s nullglob
for app_dir in "${CONFIG_DIR}"/*/; do
  app="$(basename "${app_dir}")"
  [[ "${app}" == "home" ]] && continue
  dest="${HOME_DIR}/.config/${app}"
  info "Aplicando ${app} → ~/.config/${app}"
  mkdir -p "${dest}"
  cp -r "${app_dir}." "${dest}/"
  find "${dest}" -name 'customize.sh' -type f -delete
  ok "Aplicado ${app}"
done

# Los dotfiles de home/ se copian directo a $HOME.
home_dir="${CONFIG_DIR}/home"
if [[ -d "${home_dir}" ]]; then
  info "Aplicando home → ${HOME_DIR}"
  for file in "${home_dir}"/* "${home_dir}"/.*; do
    [[ -f "${file}" ]] || continue
    cp -a "${file}" "${HOME_DIR}/"
  done
  ok "Aplicado home"
fi

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

ok "Dotfiles aplicados"