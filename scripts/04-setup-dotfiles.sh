#!/usr/bin/env bash
# 04-setup-dotfiles: aplica dotfiles a ~/.config/<app> (y home/ a $HOME),
# con selección de componentes y recarga de sway si corresponde.
#
# Uso:
#   ./scripts/04-setup-dotfiles.sh            # menú interactivo de selección
#   ./scripts/04-setup-dotfiles.sh todos      # aplica todo sin preguntar
#   ./scripts/04-setup-dotfiles.sh sway waybar home
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
# Apps disponibles = subdirectorios de config/ (home/ se maneja aparte).
# ---------------------------------------------------------------------------
apps=()
for app_dir in "${CONFIG_DIR}"/*/; do
  app="$(basename "${app_dir}")"
  [[ "${app}" == "home" ]] && continue
  apps+=("${app}")
done

# ---------------------------------------------------------------------------
# Dependencias de la config por app (comando → paquete openSUSE).
# ---------------------------------------------------------------------------
DEPENDENCIAS_CONFIG=(
  "wl-copy|wl-clipboard"
  "wofi|wofi"
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

# Deps que aplican según qué se copie (todo = lista completa).
deps_para() {
  local app="$1"
  case "${app}" in
    sway|todos) printf '%s\n' "${DEPENDENCIAS_CONFIG[@]}" ;;
    *)          return 0 ;;
  esac
}

verificar_dependencias() {
  local app="$1" cmd pkg
  local faltantes=()
  while IFS='|' read -r cmd pkg; do
    [[ -z "${cmd}" ]] && continue
    if ! command -v "${cmd}" &>/dev/null; then
      warn "Falta '${cmd}' (paquete '${pkg}') usado por la config del repo."
      faltantes+=("${pkg}")
    fi
  done <<< "$(deps_para "${app}")"

  if [[ ${#faltantes[@]} -gt 0 ]]; then
    if confirm "¿Instalar los paquetes faltantes con zypper (${faltantes[*]})?"; then
      as_root zypper -n in "${faltantes[@]}"
      ok "Paquetes instalados: ${faltantes[*]}"
    else
      warn "Omitiendo paquetes faltantes; algunos accesos de la config pueden fallar."
    fi
  fi
}

# ---------------------------------------------------------------------------
# Copia una app de config/ a ~/.config/<app> (excepto home/, que va a $HOME).
# ---------------------------------------------------------------------------
aplicar_app() {
  local app="$1"
  local app_dir dest
  app_dir="${CONFIG_DIR}/${app}"
  if [[ "${app}" == "home" ]]; then
    dest="${HOME_DIR}"
    if [[ -d "${app_dir}" ]]; then
      info "Aplicando home → ${HOME_DIR}"
      for file in "${app_dir}"/* "${app_dir}"/.*; do
        [[ -f "${file}" ]] || continue
        cp -a "${file}" "${HOME_DIR}/"
      done
      ok "Aplicado home"
    fi
    return 0
  fi

  dest="${HOME_DIR}/.config/${app}"
  info "Aplicando ${app} → ~/.config/${app}"
  mkdir -p "${dest}"
  cp -r "${app_dir}/." "${dest}/"
  find "${dest}" -name 'customize.sh' -type f -delete
  ok "Aplicado ${app}"
}

# ---------------------------------------------------------------------------
# Selección interactiva de componentes.
# Con gum usa un menú iterativo single-select (como el menú principal, donde
# flechas + Enter seleccionan directo) hasta elegir "(terminar)" o "Todos".
# Sin gum usa el menú bash numerado. Guarda el resultado en la variable
# global SELECCION (no usa stdout, porque el fallback bash imprime el menú).
# ---------------------------------------------------------------------------
SELECCION=()

seleccionar_apps() {
  local opciones=("Todos" "${apps[@]}" "home" "(terminar)")
  local elegidos=() sel final=false

  if command -v gum &>/dev/null; then
    while true; do
      sel="$(gum choose --header "¿Qué querés aplicar? Elegí '(terminar)' para finalizar." "${opciones[@]}")" \
        || { warn "Operación cancelada."; exit 1; }
      case "${sel}" in
        "(terminar)")
          final=true
          ;;
        "Todos")
          elegidos=("Todos")
          final=true
          ;;
        "")
          warn "Ninguna opción seleccionada."
          exit 1
          ;;
        *)
          # Evita duplicados manteniendo el orden de elección.
          if [[ " ${elegidos[*]} " != *" ${sel} "* ]]; then
            elegidos+=("${sel}")
          fi
          ;;
      esac
      [[ "${final}" == "true" ]] && break
    done
  else
    echo "¿Qué querés aplicar? (t = todos, números separados por espacios, vacío = cancelar)"
    for i in "${!opciones[@]}"; do
      printf '  %d) %s\n' "$((i + 1))" "${opciones[$i]}"
    done
    read -r -p "Opción(es): " sel
    [[ -z "${sel}" ]] && { warn "Operación cancelada."; exit 1; }
    if [[ "${sel}" == "t" || "${sel}" == "todos" ]]; then
      elegidos=("Todos")
    else
      for n in ${sel}; do
        index=$((n - 1))
        [[ ${index} -ge 0 && ${index} -lt ${#opciones[@]} ]] || continue
        [[ "${opciones[$index]}" == "(terminar)" ]] && continue
        elegidos+=("${opciones[$index]}")
      done
      if [[ ${#elegidos[@]} -eq 0 ]]; then
        error "Selección inválida."
        exit 1
      fi
    fi
  fi

  if [[ ${#elegidos[@]} -eq 0 ]]; then
    warn "Ninguna opción seleccionada."
    exit 1
  fi
  SELECCION=("${elegidos[@]}")
}

# ---------------------------------------------------------------------------
# Recarga la config de sway si hay una sesión activa.
# ---------------------------------------------------------------------------
recargar_sway() {
  if ! command -v swaymsg &>/dev/null || ! pgrep -x sway &>/dev/null || [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    warn "No hay sesión sway activa; la config de sway se aplicará al reiniciar la sesión."
    return 0
  fi
  if confirm "¿Recargar la configuración de sway ahora?"; then
    if swaymsg reload; then
      ok "Configuración de sway recargada."
    else
      warn "swaymsg reload falló; revisá la config con: swaymsg -t get_config"
    fi
  else
    info "Recordá recargar después con \$mod+Shift+c o reiniciando la sesión."
  fi
}

# ---------------------------------------------------------------------------
# Resolución de objetivo (argumentos CLI o menú interactivo).
# ---------------------------------------------------------------------------
if [[ $# -gt 0 ]]; then
  elegidos=()
  for arg in "$@"; do
    case "${arg}" in
      todos|all) elegidos=("Todos") ;;
      home|sway|waybar|foot|environment.d) elegidos+=("${arg}") ;;
      *) warn "Componente desconocido, ignorado: ${arg}" ;;
    esac
  done
  [[ ${#elegidos[@]} -eq 0 ]] && { error "Sin componentes válidos."; exit 1; }
else
  seleccionar_apps
  elegidos=("${SELECCION[@]}")
fi

aplicados=()
if [[ " ${elegidos[*]} " == *" Todos "* ]]; then
  verificar_dependencias "todos"
  for app in "${apps[@]}" "home"; do
    aplicar_app "${app}"
    aplicados+=("${app}")
  done
else
  for app in "${elegidos[@]}"; do
    verificar_dependencias "${app}"
    aplicar_app "${app}"
    aplicados+=("${app}")
  done
fi

# zsh como shell por defecto solo en la instalación completa (todos).
if [[ " ${elegidos[*]} " == *" Todos "* ]] && command -v zsh &>/dev/null; then
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
fi

for app in "${aplicados[@]}"; do
  [[ "${app}" == "sway" ]] && recargar_sway
done

ok "Dotfiles aplicados"