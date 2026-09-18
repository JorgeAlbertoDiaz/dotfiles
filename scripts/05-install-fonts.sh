#!/usr/bin/env bash
# 05-install-fonts: verifica, instala y configura Nerd Fonts.
#
#   - Muestra las Nerd Fonts ya instaladas (fc-list).
#   - Deja elegir qué familias instalar (menú gum multi-selección, o bash).
#   - Descarga cada familia desde GitHub Releases (ryanoasis/nerd-fonts),
#     la descomprime en ~/.local/share/fonts y refresca el cache de fontconfig.
#   - Permite elegir qué fuente (y tamaño) se usa en cada aplicación con
#     la que el repo tiene customizer (foot, sway, waybar).
#
# Flags opcionales:
#   --install-only   Solo instalar fuentes, sin configurar aplicaciones.
#   --config-only    Solo configurar aplicaciones, sin instalar fuentes.
#   --family <label> Instalar una familia concreta sin menú interactivo
#                    (repetible). El label puede ser una etiqueta del
#                    catálogo (ej. JetBrainsMono) o un asset de nerd-fonts.
#   NERD_TAG=vX.Y.Z  Fijar una versión de nerd-fonts (por defecto: latest).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

REPO_DIR="$(dirname "${SCRIPT_DIR}")"
CONFIG_DIR="${REPO_DIR}/config"

NERD_REPO="ryanoasis/nerd-fonts"
API_URL="https://api.github.com/repos/${NERD_REPO}/releases/latest"
DL_URL="https://github.com/${NERD_REPO}/releases/download"

# Catálogo curado (etiqueta|asset). Las etiquetas se muestran en el menú y
# el asset es el nombre del .zip en las releases de nerd-fonts.
CANDIDATAS=(
  "JetBrainsMono|JetBrainsMono"
  "FiraCode|FiraCode"
  "SourceCodePro|SourceCodePro"
  "Hack|Hack"
  "UbuntuMono|UbuntuMono"
  "Ubuntu|Ubuntu"
  "RobotoMono|RobotoMono"
  "Monofur|Monofur"
)

INSTALL_ONLY=0
CONFIG_ONLY=0
FAMILIAS_AUTO=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --install-only) INSTALL_ONLY=1; shift ;;
    --config-only)  CONFIG_ONLY=1; shift ;;
    --family)
      if [[ $# -lt 2 ]]; then
        error "--family requiere una etiqueta de familia (ej: --family JetBrainsMono)"
        exit 1
      fi
      FAMILIAS_AUTO+=("$2")
      shift 2
      ;;
    *) warn "Argumento desconocido ignorado: $1"; shift ;;
  esac
done

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

app_dir() { printf '%s/%s' "${CONFIG_DIR}" "$1"; }

fonts_dir() {
  local data_dir="${XDG_DATA_HOME:-${HOME}/.local/share}"
  printf '%s/fonts' "${data_dir}"
}

# Familias Nerd Font instaladas (únicas), según fontconfig.
installed_families() {
  fc-list 2>/dev/null | cut -d: -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | rg -i 'Nerd Font$' | sort -u || true
}

asset_from_label() {
  local label="$1" entry
  for entry in "${CANDIDATAS[@]}"; do
    [[ "${entry%%|*}" == "${label}" ]] && printf '%s\n' "${entry#*|}" && return 0
  done
  return 1
}

label_from_asset() {
  local asset="$1" entry
  for entry in "${CANDIDATAS[@]}"; do
    [[ "${entry#*|}" == "${asset}" ]] && printf '%s\n' "${entry%%|*}" && return 0
  done
  printf '%s\n' "${asset}"
}

# Versión más reciente de nerd-fonts (jq si está, sino grep).
latest_tag() {
  if command -v jq &>/dev/null; then
    curl -fsSL "${API_URL}" | jq -r '.tag_name'
  else
    curl -fsSL "${API_URL}" | grep -oP '"tag_name"\s*:\s*"\K[^"]+' | head -n1
  fi
}

# Elegir una familia instalada (una sola) o devolver vacío para saltear.
ask_installed_family() {
  local header="$1" families line
  mapfile -t families < <(installed_families)
  if [[ ${#families[@]} -eq 0 ]]; then
    warn "No hay Nerd Fonts instaladas; salteando configuración."
    return 1
  fi

  if command -v gum &>/dev/null; then
    if ! line="$(gum choose --header "${header}" "Saltear (mantener actual)" "${families[@]}" 2>/dev/null)"; then
      return 1
    fi
  else
    info "Fuentes instaladas disponibles:" >&2
    line="$(ask_bash_select "Elige fuente para ${header}:" "Saltear (mantener actual)" "${families[@]}")"
  fi

  [[ "${line}" == "Saltear"* ]] && return 1
  printf '%s\n' "${line}"
  return 0
}

# Menú de selección simple con bash.
ask_bash_select() {
  local prompt="$1" choice
  shift
  while true; do
    local i=1
    for opt in "$@"; do
      printf '  %d) %s\n' "${i}" "${opt}" >&2
      i=$((i + 1))
    done
    read -r -p "${prompt} " choice || return 1
    if [[ "${choice}" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= $# )); then
      shift $((choice - 1))
      printf '%s\n' "$1"
      return 0
    fi
  done
}

ask_size() {
  local app="$1" default="$2" size
  default="${default:-}"
  if command -v gum &>/dev/null; then
    if ! size="$(gum input --prompt "Tamaño fuente ${app}: " --value "${default}" 2>/dev/null)"; then
      return 1
    fi
  else
    read -r -p "Tamaño fuente ${app} [${default}]: " size || return 1
  fi
  size="${size:-${default}}"
  if [[ -z "${size}" || ! "${size}" =~ ^[0-9]+$ ]]; then
    warn "Tamaño no válido: '${size}'; salteando ${app}."
    return 1
  fi
  printf '%s\n' "${size}"
}

# ---------------------------------------------------------------------------
# Selección de familias a instalar
# ---------------------------------------------------------------------------

select_families_install() {
  local labels=() chosen=() entry label asset line custom
  for entry in "${CANDIDATAS[@]}"; do
    labels+=("${entry%%|*}")
  done

  if command -v gum &>/dev/null; then
    local selected
    if ! selected="$(gum choose --no-limit --height 12 \
        --header "Nerd Fonts a instalar (Espacio=seleccionar, Enter=continuar):" \
        "${labels[@]}")"; then
      return 1
    fi
    mapfile -t chosen <<< "${selected}"
    if command -v gum &>/dev/null && confirm "¿Instalar también otra familia personalizada?"; then
      if custom="$(gum input --prompt "Asset de nerd-fonts (ej. Iosevka): " 2>/dev/null)"; then
        [[ -n "${custom}" ]] && chosen+=("${custom}")
      fi
    fi
  else
    info "Selecciona las Nerd Fonts a instalar:"
    for label in "${labels[@]}"; do
      if confirm "¿Instalar ${label}?"; then
        chosen+=("${label}")
      fi
    done
  fi

  [[ ${#chosen[@]} -eq 0 ]] && return 1

  assets=()
  for item in "${chosen[@]}"; do
    if asset="$(asset_from_label "${item}")"; then
      assets+=("${asset}")
    else
      # Intentar sin el sufijo "Nerd Font" (ej. si el usuario escribe el nombre completo)
      stripped="${item% Nerd Font}"
      if asset="$(asset_from_label "${stripped}")"; then
        assets+=("${asset}")
      else
        warn "Familia no reconocida; se usará el asset tal cual: ${item}"
        assets+=("${item}")
      fi
    fi
  done
}

# ---------------------------------------------------------------------------
# Instalación
# ---------------------------------------------------------------------------

install_assets() {
  local tag="${NERD_TAG:-}"
  if [[ -z "${tag}" ]]; then
    info "Obteniendo la última versión de nerd-fonts..."
    tag="$(latest_tag)" || {
      error "No se pudo obtener la última versión desde GitHub."
      exit 1
    }
    ok "Versión detectada: ${tag}"
  fi

  ensure_xdg_dirs >/dev/null

  local asset url target dest download_dir
  local fonts
  fonts="$(fonts_dir)"
  mkdir -p "${fonts}"
  download_dir="$(downloads_dir)"

  for asset in "$@"; do
    target="${fonts}/${asset}"
    if installed_asset "${asset}"; then
      ok "Ya instalada: ${asset}"
      continue
    fi
    url="${DL_URL}/${tag}/${asset}.zip"
    dest="${download_dir}/${asset}.zip"
    info "Descargando ${asset} desde ${url}"
    curl -fsSL --output "${dest}" "${url}" || {
      error "Fallo al descargar ${asset}"
      rm -f "${dest}"
      continue
    }
    install -d "${target}"
    unzip -oq "${dest}" -d "${target}"
    rm -f "${dest}"
    info "Extrayendo en ${target}"
  done

  info "Actualizando el cache de fuentes (fc-cache)..."
  fc-cache -f >/dev/null 2>&1 || warn "fc-cache no disponible"
  ok "Cache de fuentes actualizado"
}

installed_asset() {
  local asset="$1"
  fc-list 2>/dev/null | cut -d: -f2 | rg -qi "${asset}" && return 0
  return 1
}

verify_installs() {
  local asset
  for asset in "$@"; do
    if installed_asset "${asset}"; then
      ok "Verificada: $(label_from_asset "${asset}")"
    else
      warn "No se encontró '${asset}' en fontconfig tras la instalación."
    fi
  done
}

warn_configured_missing() {
  local fams
  fams="$(fc-list 2>/dev/null | cut -d: -f2 | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | sort -u)"
  local cfg missing=0

  cfg="$(sed -nE 's/^font=([^:]+).*/\1/p' "${CONFIG_DIR}/foot/.config/foot/foot.ini" 2>/dev/null)"
  cfg="${cfg}"$'\n'"$(sed -nE '/^font pango:/{s/^font pango:(.+)/\1/;s/ [0-9]+$//;p}' "${CONFIG_DIR}/sway/.config/sway/config" 2>/dev/null | head -n1)"
  cfg="${cfg}"$'\n'"$(sed -nE 's/^[[:space:]]*font-family: "([^"]+)";/\1/p' "${CONFIG_DIR}/waybar/.config/waybar/style.css" 2>/dev/null | head -n1)"

  declare -A warned=()
  local fam
  while IFS= read -r fam; do
    fam="$(printf '%s' "${fam}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "${fam}" ]] && continue
    [[ -n "${warned[${fam}]:-}" ]] && continue
    if ! grep -qi "${fam}" <<< "${fams}"; then
      warn "La fuente configurada '${fam}' no está instalada; se usará un fallback."
      warned["${fam}"]=1
      missing=1
    fi
  done <<< "${cfg}"

  if [[ ${missing} -eq 0 ]]; then
    ok "Todas las fuentes configuradas están instaladas"
  fi
}

current_family() {
  local app="$1"
  case "${app}" in
    foot)   sed -nE 's/^font=([^:]+).*/\1/p' "${CONFIG_DIR}/foot/.config/foot/foot.ini" | head -n1 ;;
    sway)   sed -nE '/^font pango:/{s/^font pango:(.+)/\1/;s/ [0-9]+$//;p}' "${CONFIG_DIR}/sway/.config/sway/config" | head -n1 ;;
    waybar) sed -nE 's/^[[:space:]]*font-family: "([^"]+)";/\1/p' "${CONFIG_DIR}/waybar/.config/waybar/style.css" | head -n1 ;;
    *)      printf '' ;;
  esac
}

current_size() {
  local app="$1"
  case "${app}" in
    foot)   sed -nE 's/^font=.*:size=([0-9]+)$/\1/p' "${CONFIG_DIR}/foot/.config/foot/foot.ini" | head -n1 ;;
    sway)   sed -nE 's/^font pango:.* ([0-9]+)$/\1/p' "${CONFIG_DIR}/sway/.config/sway/config" | head -n1 ;;
    waybar) sed -nE 's/font-size: ([0-9]+)px;/\1/p' "${CONFIG_DIR}/waybar/.config/waybar/style.css" | head -n1 ;;
    *)      printf '' ;;
  esac
}

# ---------------------------------------------------------------------------
# Configuración de la fuente por aplicación
# ---------------------------------------------------------------------------

configure_apps() {
  local apps=(foot sway waybar) app customizer family size current_f
  for app in "${apps[@]}"; do
    customizer="${CONFIG_DIR}/${app}/customize.sh"
    [[ -x "${customizer}" ]] || continue
    current_f="$(current_family "${app}")"
    current_f="${current_f:-DejaVu Sans Mono}"
    info "Configurando fuente de ${app} (actual: ${current_f})"
    if ! family="$(ask_installed_family "Fuente para ${app} (actual: ${current_f})")"; then
      info "Manteniendo fuente actual de ${app}"
      continue
    fi
    if ! size="$(ask_size "${app}" "$(current_size "${app}")")"; then
      continue
    fi
    info "Aplicando a ${app}: ${family} tamaño ${size}"
    "${customizer}" "${family}" "${size}"
    ok "${app} configurado con ${family} (${size})"
    case "${app}" in
      sway) warn "Recarga sway (Mod+Shift+C) para ver el cambio." ;;
      waybar) warn "Reinicia waybar o recarga sway para ver el cambio." ;;
      foot) warn "Las nuevas ventanas de foot usarán la fuente." ;;
    esac
  done
}

# ---------------------------------------------------------------------------
# Flujo
# ---------------------------------------------------------------------------

info "Comprobando Nerd Fonts instaladas..."
mapfile -t installed < <(installed_families)
if [[ ${#installed[@]} -gt 0 ]]; then
  ok "Nerd Fonts encontradas: ${installed[*]}"
else
  warn "No hay Nerd Fonts instaladas aún."
fi

assets=()
if [[ ${CONFIG_ONLY} -eq 0 ]]; then
  if [[ ${#FAMILIAS_AUTO[@]} -gt 0 ]]; then
    # Modo no interactivo: instalar directamente las familias de --family,
    # mapeando la etiqueta al asset del catálogo (o usándola tal cual).
    info "Familias solicitadas con --family: ${FAMILIAS_AUTO[*]}"
    for item in "${FAMILIAS_AUTO[@]}"; do
      if asset="$(asset_from_label "${item}")"; then
        assets+=("${asset}")
      else
        warn "Familia no reconocida; se usará el asset tal cual: ${item}"
        assets+=("${item}")
      fi
    done
    install_assets "${assets[@]}"
    verify_installs "${assets[@]}"
  elif select_families_install; then
    install_assets "${assets[@]}"
    verify_installs "${assets[@]}"
  else
    warn "No se seleccionó ninguna fuente para instalar."
  fi
fi

warn_configured_missing

if [[ ${INSTALL_ONLY} -eq 0 ]]; then
  configure_apps
fi

ok "Configuración de Nerd Fonts completada"