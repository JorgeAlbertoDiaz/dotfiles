#!/usr/bin/env bash
# 04-setup-dotfiles: aplica dotfiles a ~/.config/<app> (y home/ a $HOME),
# con selección de componentes y recarga de sway si corresponde.
#
# Uso:
#   ./scripts/04-setup-dotfiles.sh            # menú interactivo de selección
#   ./scripts/04-setup-dotfiles.sh todos      # aplica todo sin preguntar
#   ./scripts/04-setup-dotfiles.sh sway waybar home
#   ./scripts/04-setup-dotfiles.sh zsh         # aplica solo ~/.zshrc
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
  "wob|wob"
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
  local app="$1" reset="$2"
  local app_dir dest file
  app_dir="${CONFIG_DIR}/${app}"
  if [[ "${app}" == "home" ]]; then
    dest="${HOME_DIR}"
    if [[ -d "${app_dir}" ]]; then
      info "Aplicando home → ${HOME_DIR}"
      # dotglob+nullglob: un solo glob cubre los archivos ocultos y los
      # subdirectorios, y nullglob evita colgar ".", ".." o un literal sin
      # coincidencia cuando la carpeta está vacía. El patrón anterior
      # ("${app_dir}"/* "${app_dir}"/.*) se saltaba los directorios por el
      # [[ -f ]] y los ocultos por el glob sin dotglob.
      shopt -s dotglob nullglob
      for file in "${app_dir}"/*; do
        # El borrado del reset es acotado a los nombres que declara el repo:
        # se borra cada destino por su nombre, nunca con un comodín sobre
        # $HOME. El "rm -rf" de config/<app>/home no toca nada fuera de la lista.
        if [[ "${reset}" == "1" ]]; then
          rm -rf "${HOME_DIR}/$(basename "${file}")"
        fi
        # "cp -a" sobre un directorio crea ${HOME_DIR}/<basename>; sobre un
        # archivo, lo sobreescribe conservando modo y timestamps.
        cp -a "${file}" "${HOME_DIR}/"
      done
      shopt -u dotglob nullglob
      ok "Aplicado home"
    fi
    return 0
  fi

  dest="${HOME_DIR}/.config/${app}"
  if [[ "${reset}" == "1" && -d "${dest}" ]]; then
    info "Reset de fábrica: borrando ${dest} y recreándolo desde el repo"
    rm -rf "${dest}"
  fi
  info "Aplicando ${app} → ~/.config/${app}"
  mkdir -p "${dest}"
  cp -r "${app_dir}/." "${dest}/"
  # Garantiza que los scripts se copien ejecutables: cp conserva los modos al
  # crear archivos, pero un destino preexistente mantendría los suyos.
  if [[ -d "${dest}/scripts" ]]; then
    find "${dest}/scripts" -type f -name '*.sh' -exec chmod +x {} +
  fi
  ok "Aplicado ${app}"
}

# ---------------------------------------------------------------------------
# Aplica solo la configuración de zsh (~/.zshrc) desde config/home/.
# Es una acción separada de "home" (que copia todo config/home/) y de cambiar
# la shell por defecto: aplicar la config no implica cambiar de shell.
# ---------------------------------------------------------------------------
aplicar_zsh_config() {
  local src="${CONFIG_DIR}/home/.zshrc" dest="${HOME_DIR}/.zshrc"
  if [[ ! -f "${src}" ]]; then
    warn "No existe ${src}; no se aplicó la configuración de zsh."
    return 0
  fi
  if [[ "${RESET_FABRICA}" == "1" && -e "${dest}" ]]; then
    info "Reset de fábrica: borrando ${dest}"
    rm -f "${dest}"
  fi
  info "Aplicando configuración de zsh → ${dest}"
  cp -a "${src}" "${dest}"
  ok "Aplicado zsh (~/.zshrc)"
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
  local opciones=("Todos" "${apps[@]}" "home" "Configuración de zsh" "(terminar)")
  local elegidos=() sel final=false

  if command -v gum &>/dev/null; then
    while true; do
      if ! sel="$(gum choose --header "Elegí qué aplicar (Enter confirma cada opción)." "${opciones[@]}")"; then
        # ESC/Ctrl+C: si ya hay elecciones, terminá y aplicá; si no, cancelá.
        if [[ ${#elegidos[@]} -eq 0 ]]; then
          warn "No elegiste nada; para salir elegí \"(terminar)\" o ESC."
          exit 1
        fi
        info "Selección finalizada con ESC."
        final=true
        break
      fi
      case "${sel}" in
        "(terminar)")
          final=true
          ;;
        "Todos")
          elegidos=("Todos")
          final=true
          ;;
        "Configuración de zsh")
          # Valor interno "zsh": aplica config/home/.zshrc a ~/.zshrc.
          if [[ " ${elegidos[*]} " != *" zsh "* ]]; then
            elegidos+=("zsh")
          fi
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
      ok "Agregado: ${sel}"
      # Una sola opción + Enter debe bastar: el confirm cierra el bucle con
      # respuesta "no" (Enter en el default) sin exigir elegir "(terminar)".
      if ! gum confirm --default=false "¿Aplicar algo más?"; then
        final=true
        break
      fi
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
        item="${opciones[$index]}"
        # "Configuración de zsh" se guarda como valor interno "zsh".
        [[ "${item}" == "Configuración de zsh" ]] && item="zsh"
        elegidos+=("${item}")
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
      home|sway|waybar|foot|environment.d|zsh) elegidos+=("${arg}") ;;
      *) warn "Componente desconocido, ignorado: ${arg}" ;;
    esac
  done
  [[ ${#elegidos[@]} -eq 0 ]] && { error "Sin componentes válidos."; exit 1; }
else
  seleccionar_apps
  elegidos=("${SELECCION[@]}")
fi

aplicados=()
RESET_FABRICA=0

# Lista concreta de apps a aplicar (sin "zsh", que es una acción interna).
apps_a_aplicar=()
if [[ " ${elegidos[*]} " == *" Todos "* ]]; then
  apps_a_aplicar=("${apps[@]}" "home")
else
  for app in "${elegidos[@]}"; do
    [[ "${app}" == "zsh" ]] && continue
    apps_a_aplicar+=("${app}")
  done
fi

# Reset de fábrica: una sola confirmación que borra y recrea los destinos.
# Aplica tanto a .config/<app> como a home/; en home/ el borrado es acotado a
# los nombres que declara el repo (sin comodines sobre $HOME), así que lo que
# el usuario tenga fuera de config/home/ no se toca nunca.
if [[ ${#apps_a_aplicar[@]} -gt 0 ]]; then
  if confirm "¿Reset de fábrica? (Sí: borrar y recrear desde el repo / No: solo copiar) [${apps_a_aplicar[*]}]"; then
    RESET_FABRICA=1
    info "Reset de fábrica activado para: ${apps_a_aplicar[*]}"
  fi
fi

aplicar_apps() {
  local app
  for app in "$@"; do
    aplicar_app "${app}" "${RESET_FABRICA}"
    aplicados+=("${app}")
  done
}

if [[ " ${elegidos[*]} " == *" Todos "* ]]; then
  verificar_dependencias "todos"
  aplicar_apps "${apps_a_aplicar[@]}"
else
  for app in "${apps_a_aplicar[@]}"; do
    verificar_dependencias "${app}"
    aplicar_app "${app}" "${RESET_FABRICA}"
    aplicados+=("${app}")
  done
fi

# Configuración de zsh: sólo si se eligió explícitamente (CLI o submenú). Con
# "Todos" o "home" ya viene dentro de config/home/, así que no se repite.
if [[ " ${elegidos[*]} " == *" zsh "* ]]; then
  aplicar_zsh_config
fi

# Cambio de shell por defecto: se pregunta sólo si se aplicó la config de zsh
# (opción "zsh", "home" o "Todos") y zsh está instalado pero no es la shell
# real de la cuenta. Aplicar la config no cambia la shell por sí solo.
if [[ " ${elegidos[*]} " == *" Todos "* || " ${elegidos[*]} " == *" home "* || " ${elegidos[*]} " == *" zsh "* ]]; then
  if ! command -v zsh &>/dev/null; then
    warn "zsh no está instalado; no se puede cambiar la shell por defecto."
  else
    zsh_path="$(command -v zsh)"
    # Shell real de la cuenta (getent passwd), no ${SHELL} de la sesión.
    shell_actual="$(getent passwd "$(id -un)" | cut -d: -f7)"
    if [[ "${shell_actual}" != *"/zsh" ]]; then
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
fi

for app in "${aplicados[@]}"; do
  [[ "${app}" == "sway" ]] && recargar_sway
done

ok "Dotfiles aplicados"