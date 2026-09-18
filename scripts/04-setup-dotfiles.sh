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

# ---------------------------------------------------------------------------
# Dependencias de la config referenciada (comando → paquete openSUSE).
# La config del repo usa binds/comandos que pueden no estar instalados
# (p.ej. wl-copy con un sway del sistema); se ofrecen antes de copiar.
# ---------------------------------------------------------------------------
DEPENDENCIAS_CONFIG=(
  "wofi|wofi"
  "wl-copy|wl-clipboard"
  "grim|grim"
  "slurp|slurp"
  "jq|jq"
  "swaylock|swaylock"
  "swaync|swaync"
  "playerctl|playerctl"
  "pamixer|pamixer"
  "brightnessctl|brightnessctl"
  "bc|bc"
)

faltantes=()
for dep in "${DEPENDENCIAS_CONFIG[@]}"; do
  cmd="${dep%%|*}"
  pkg="${dep#*|}"
  if ! command -v "${cmd}" &>/dev/null; then
    warn "Falta '${cmd}' (paquete '${pkg}') usado por la config del repo."
    faltantes+=("${pkg}")
  fi
done

if [[ ${#faltantes[@]} -gt 0 ]]; then
  if confirm "¿Instalar los paquetes faltantes con zypper (${faltantes[*]})?"; then
    as_root zypper -n in "${faltantes[@]}"
    ok "Paquetes instalados: ${faltantes[*]}"
  else
    warn "Omitiendo paquetes faltantes; algunos accesos de la config pueden fallar."
  fi
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