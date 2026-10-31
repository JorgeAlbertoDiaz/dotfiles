#!/usr/bin/env bash
# 04-setup-dotfiles: aplica dotfiles a ~/.config/<app> (y home/ a $HOME),
# con selección de componentes y recarga de sway si corresponde.
#
# Uso:
#   ./scripts/04-setup-dotfiles.sh            # menú interactivo de selección
#   ./scripts/04-setup-dotfiles.sh todos      # aplica todo sin preguntar
#   ./scripts/04-setup-dotfiles.sh sway waybar home
#   ./scripts/04-setup-dotfiles.sh zsh         # aplica solo ~/.zshrc
#   ./scripts/04-setup-dotfiles.sh git         # aplica solo ~/.gitconfig
#
# Despliegue y limpieza acotada
# -----------------------------
# El repo es la fuente de verdad: en cada corrida se recorre config/ y se
# calcula, sin listas a mano, exactamente qué archivos despliega cada app.
# Ese conjunto se guarda como inventario en
#   ${XDG_STATE_HOME:-~/.local/state}/dotfiles/desplegado.tsv
# y la limpieza borra solo entradas del inventario anterior que el repo ya no
# declara. Nunca hace "rm -rf" de un directorio del usuario: como mucho rmdir
# de directorios que quedaron vacíos, con tope en las bases XDG. El resto de
# $HOME (binarios propios, datos de apps, configuraciones ajenas) no se toca.
#
# Los destinos bajo ~/.local/share/ y ~/.local/state/ son datos mutables de
# una aplicación (los escribe la app, no el repo): se siembran si faltan y
# nunca se pisan ni se podan.
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
# Inventario y despliegue acotado.
# ---------------------------------------------------------------------------
STATE_DIR="${XDG_STATE_HOME:-${HOME_DIR}/.local/state}/dotfiles"
MANIFEST="${STATE_DIR}/desplegado.tsv"

# Rutas (relativas a $HOME) que el repo despliega para una app o para home.
# Se calculan con find en cada corrida: agregar o quitar un archivo del repo
# alcanza para que el despliegue y la poda lo reflejen.
rutas_gestionadas() {
  local app="$1" base
  if [[ "${app}" == "home" ]]; then
    base="${CONFIG_DIR}/home"
    [[ -d "${base}" ]] || return 0
    ( cd "${base}" && find . -mindepth 1 \( -type f -o -type l \) -printf '%P\n' )
  else
    base="${CONFIG_DIR}/${app}"
    [[ -d "${base}" ]] || return 0
    ( cd "${base}" && find . -mindepth 1 \( -type f -o -type l \) -printf ".config/${app}/%P\n" )
  fi
}

# Directorios del repo, para recrear también los que estén vacíos.
directorios_gestionados() {
  local app="$1" base
  if [[ "${app}" == "home" ]]; then
    base="${CONFIG_DIR}/home"
    [[ -d "${base}" ]] || return 0
    ( cd "${base}" && find . -mindepth 1 -type d -printf '%P\n' )
  else
    base="${CONFIG_DIR}/${app}"
    [[ -d "${base}" ]] || return 0
    ( cd "${base}" && find . -mindepth 1 -type d -printf ".config/${app}/%P\n" )
  fi
}

# Inventario nuevo (origen<TAB>ruta) de la selección, en un solo flujo.
inventario_de_seleccion() {
  local app rel
  for app in "$@"; do
    while IFS= read -r rel; do
      printf '%s\t%s\n' "${app}" "${rel}"
    done < <(rutas_gestionadas "${app}")
  done
}

# Una ruta del inventario solo puede ser relativa a $HOME y sin componentes
# "..", "." ni vacíos: si el archivo se corrompe o lo editan a mano, la poda
# no puede salirse del home del usuario.
ruta_valida() {
  local rel="$1"
  [[ -n "${rel}" ]] || return 1
  [[ "${rel}" != /* ]] || return 1
  case "/${rel}/" in
    *"/../"*|*"/./"*|*"//"*) return 1 ;;
  esac
  return 0
}

# Los datos de una app (no config) se siembran pero no se pisan: la app los
# escribe en tiempo de ejecución y perderlos no es reconstruible.
es_dato_de_app() {
  case "$1" in
    .local/share/*|.local/state/*) return 0 ;;
  esac
  return 1
}

# Ruta de origen en el repo para una entrada del inventario.
origen_en_repo() {
  local origen="$1" rel="$2"
  if [[ "${origen}" == "home" ]]; then
    printf '%s/%s\n' "${CONFIG_DIR}/home" "${rel}"
  else
    printf '%s/%s/%s\n' "${CONFIG_DIR}" "${origen}" "${rel#.config/"${origen}"/}"
  fi
}

desplegar_archivo() {
  local origen="$1" rel="$2" src abs
  if ! ruta_valida "${rel}"; then
    warn "Ruta insegura en el inventario; se ignora: ${rel}"
    return 0
  fi
  src="$(origen_en_repo "${origen}" "${rel}")"
  abs="${HOME_DIR}/${rel}"

  if es_dato_de_app "${rel}" && { [[ -e "${abs}" ]] || [[ -L "${abs}" ]]; }; then
    info "Se conserva (dato de la app): ${rel}"
    return 0
  fi

  mkdir -p -- "$(dirname -- "${abs}")"
  if [[ -d "${abs}" && ! -L "${abs}" ]]; then
    # Un archivo gestionado no reemplaza un directorio con contenido ajeno.
    if ! rmdir -- "${abs}" 2>/dev/null; then
      warn "Se esperaba un archivo y hay un directorio con contenido; se omite: ${rel}"
      return 0
    fi
  fi
  # rm del destino antes de copiar: si es un enlace simbólico, se reemplaza el
  # enlace (no se escribe a través de él) y el modo queda el del repo.
  rm -f -- "${abs}"
  cp -a -- "${src}" "${abs}"
}

podar_directorios_vacios() {
  local dir abs
  dir="$(dirname -- "$1")"
  while [[ "${dir}" != "." ]]; do
    case "${dir}" in
      .config|.local|.local/share|.local/state|.local/bin) break ;;
    esac
    abs="${HOME_DIR}/${dir}"
    [[ -d "${abs}" && ! -L "${abs}" ]] || break
    rmdir -- "${abs}" 2>/dev/null || break
    info "Directorio vacío eliminado: ${dir}"
    dir="$(dirname -- "${dir}")"
  done
}

borrar_gestionado() {
  local rel="$1" abs
  if ! ruta_valida "${rel}"; then
    warn "Ruta insegura en el inventario; se ignora: ${rel}"
    return 0
  fi
  # Los datos de apps no se podan nunca: el repo solo los sembró.
  if es_dato_de_app "${rel}"; then
    info "Se conserva (dato de la app): ${rel}"
    return 0
  fi
  abs="${HOME_DIR}/${rel}"
  if [[ -L "${abs}" || -f "${abs}" ]]; then
    rm -f -- "${abs}"
    info "Eliminado (el repo ya no lo despliega): ${rel}"
    podar_directorios_vacios "${rel}"
  elif [[ -d "${abs}" ]]; then
    warn "El repo ya no despliega ${rel} y ahora es un directorio; no se borra."
  fi
}

aplicar_app() {
  local app="$1" rel
  if [[ "${app}" == "home" ]]; then
    info "Aplicando home → ${HOME_DIR}"
  else
    info "Aplicando ${app} → ~/.config/${app}"
  fi

  while IFS= read -r rel; do
    mkdir -p -- "${HOME_DIR}/${rel}"
  done < <(directorios_gestionados "${app}")

  while IFS= read -r rel; do
    desplegar_archivo "${app}" "${rel}"
  done < <(rutas_gestionadas "${app}")

  if [[ "${app}" == "home" ]]; then
    ok "Aplicado home"
  else
    ok "Aplicado ${app}"
  fi
}

# Poda: solo entradas del inventario cuyo origen está en la selección actual y
# que el repo ya no declara. Lo que no salió de config/ nunca se considera.
podar_obsoletos() {
  local origen rel
  [[ -f "${MANIFEST}" ]] || return 0
  while IFS=$'\t' read -r origen rel; do
    [[ -z "${origen}" || -z "${rel}" ]] && continue
    seleccionado "${origen}" || continue
    if grep -Fxq -- "${origen}"$'\t'"${rel}" "${inventario_nuevo}"; then
      continue
    fi
    borrar_gestionado "${rel}"
  done < <(leer_inventario)
}

leer_inventario() {
  [[ -f "${MANIFEST}" ]] || return 0
  grep -v '^#' "${MANIFEST}" || true
}

seleccionado() {
  local origen="$1" app
  for app in "${apps_a_aplicar[@]}"; do
    [[ "${app}" == "${origen}" ]] && return 0
  done
  # Con "Todos" también se limpia una app que ya no existe en config/: nada
  # de lo que desplegó sigue siendo reconstruible por el repo.
  if [[ ${MODO_TODOS} -eq 1 ]]; then
    [[ "${origen}" == "home" ]] && return 0
    case "${origen}" in
      */*|..|.) return 1 ;;
    esac
    [[ ! -d "${CONFIG_DIR}/${origen}" ]] && return 0
  fi
  return 1
}

escribir_inventario() {
  local tmp="${MANIFEST}.tmp.$$"
  mkdir -p -- "${STATE_DIR}"
  {
    printf '# Inventario de scripts/04-setup-dotfiles.sh.\n'
    printf '# Formato: origen<TAB>ruta relativa al home del usuario. No editar a mano.\n'
    while IFS=$'\t' read -r origen rel; do
      [[ -z "${origen}" || -z "${rel}" ]] && continue
      seleccionado "${origen}" && continue
      printf '%s\t%s\n' "${origen}" "${rel}"
    done < <(leer_inventario)
    sort -u "${inventario_nuevo}"
  } > "${tmp}"
  mv -f -- "${tmp}" "${MANIFEST}"
}

# ---------------------------------------------------------------------------
# Aplica un archivo suelto de config/home/ a $HOME (p. ej. .zshrc, .gitconfig).
# Es una acción separada de "home" (que copia todo config/home/): permite
# aplicar sólo la config de una herramienta.
# ---------------------------------------------------------------------------
aplicar_home_file() {
  local nombre="$1" etiqueta="$2"
  local src="${CONFIG_DIR}/home/${nombre}" dest="${HOME_DIR}/${nombre}"
  if [[ ! -f "${src}" ]]; then
    warn "No existe ${src}; no se aplicó ${etiqueta}."
    return 0
  fi
  info "Aplicando ${etiqueta} → ${dest}"
  desplegar_archivo "home" "${nombre}"
  printf 'home\t%s\n' "${nombre}" >> "${inventario_nuevo}"
  ok "Aplicado ${etiqueta} (${dest})"
}

aplicar_zsh_config() { aplicar_home_file ".zshrc" "configuración de zsh"; }
aplicar_git_config() { aplicar_home_file ".gitconfig" "configuración de git"; }

# ---------------------------------------------------------------------------
# Selección interactiva de componentes.
# Con gum usa un menú iterativo single-select (como el menú principal, donde
# flechas + Enter seleccionan directo) hasta elegir "(terminar)" o "Todos".
# Sin gum usa el menú bash numerado. Guarda el resultado en la variable
# global SELECCION (no usa stdout, porque el fallback bash imprime el menú).
# ---------------------------------------------------------------------------
SELECCION=()

seleccionar_apps() {
  local opciones=("Todos" "${apps[@]}" "home" "Configuración de zsh" "Configuración de git" "(terminar)")
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
        "Configuración de git")
          # Valor interno "git": aplica config/home/.gitconfig a ~/.gitconfig.
          if [[ " ${elegidos[*]} " != *" git "* ]]; then
            elegidos+=("git")
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
        # "Configuración de zsh"/"git" se guardan como valores internos.
        [[ "${item}" == "Configuración de zsh" ]] && item="zsh"
        [[ "${item}" == "Configuración de git" ]] && item="git"
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
      home|sway|waybar|foot|environment.d|zsh|git) elegidos+=("${arg}") ;;
      *) warn "Componente desconocido, ignorado: ${arg}" ;;
    esac
  done
  [[ ${#elegidos[@]} -eq 0 ]] && { error "Sin componentes válidos."; exit 1; }
else
  seleccionar_apps
  elegidos=("${SELECCION[@]}")
fi

# Lista concreta de apps a aplicar ("zsh" y "git" son acciones internas que se
# resuelven por separado con aplicar_*_config).
apps_a_aplicar=()
MODO_TODOS=0
if [[ " ${elegidos[*]} " == *" Todos "* ]]; then
  MODO_TODOS=1
  apps_a_aplicar=("${apps[@]}" "home")
else
  for app in "${elegidos[@]}"; do
    [[ "${app}" == "zsh" || "${app}" == "git" ]] && continue
    apps_a_aplicar+=("${app}")
  done
fi

# ---------------------------------------------------------------------------
# Aplicación: inventario nuevo → despliegue → poda acotada → inventario.
# ---------------------------------------------------------------------------
inventario_nuevo="$(mktemp "${TMPDIR:-/tmp}/dotfiles-inventario.XXXXXX")"
trap 'rm -f -- "${inventario_nuevo}"' EXIT

inventario_de_seleccion "${apps_a_aplicar[@]}" | sort -u > "${inventario_nuevo}"

if [[ " ${elegidos[*]} " == *" Todos "* ]]; then
  verificar_dependencias "todos"
  for app in "${apps_a_aplicar[@]}"; do
    aplicar_app "${app}"
  done
else
  for app in "${apps_a_aplicar[@]}"; do
    verificar_dependencias "${app}"
    aplicar_app "${app}"
  done
fi

# Config de zsh/git: sólo si se eligió explícitamente (CLI o submenú). Con
# "Todos" o "home" ya vienen dentro de config/home/, así que no se repiten.
if [[ " ${elegidos[*]} " == *" zsh "* ]]; then
  aplicar_zsh_config
fi
if [[ " ${elegidos[*]} " == *" git "* ]]; then
  aplicar_git_config
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

podar_obsoletos
escribir_inventario

for app in "${apps_a_aplicar[@]}"; do
  [[ "${app}" == "sway" ]] && recargar_sway
done

gestionados="$(grep -vc '^#' "${MANIFEST}" || true)"
ok "Dotfiles aplicados (${gestionados} archivos en el inventario: ${MANIFEST})"
info "Solo se despliega lo declarado en config/; el resto de \$HOME no se modifica."
