#!/usr/bin/env bash
# sway-font.sh — personaliza la fuente de sway sobre la config APLICADA
# (~/.config/sway/config), no sobre la del repositorio.
#
# Uso:
#   sway-font.sh                      # interactivo: familia + tamaño en wofi
#   sway-font.sh <familia>            # aplica familia (tamaño actual o por defecto)
#   sway-font.sh <familia> <tamaño>   # aplica familia y tamaño
#
# Reescribe la línea "font pango:" del config de sway conservando el resto. Si
# esa línea delega en $font-family/$font-size, edita esas variables en vez de
# pisarla. Si la línea no existe, la agrega en la sección de Variables. Si hay
# una sesión de sway activa, recarga la configuración.
set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sway/config"
DEFAULT_FAMILY='JetBrainsMono Nerd Font'
# Módulo que define $font-family / $font-size. Solo se toca si la línea
# "font pango:" delega el valor en esas variables en vez de llevarlo literal.
VARS_FILE="$(dirname "${CONFIG_FILE}")/features/variables-colors.conf"

# Opciones base de wofi (estilo consistente con el launcher del sistema).
WOFI_OPTS=(--dmenu --insensitive)
[[ -f /etc/wofi/config ]] && WOFI_OPTS+=(--conf /etc/wofi/config)
[[ -f /etc/wofi/style.css ]] && WOFI_OPTS+=(--style /etc/wofi/style.css)

# Familias de fuentes mono instaladas (fc-list), ordenadas, sin duplicados.
# Usa fc-list ':spacing=100' (FC_MONO) y toma el nombre primario de cada
# familia (fc-list devuelve los alias separados por coma).
familias_mono() {
  fc-list ':spacing=100' family 2>/dev/null | cut -d, -f1 | sort -u
}

# Elige familia en wofi (la default aparece primero; Enter la selecciona).
elegir_familia() {
  local lista
  lista="$(printf '%s\n%s\n' "${DEFAULT_FAMILY}" "$(familias_mono)" | awk '!seen[$0]++')"
  printf '%s\n' "${lista}" | wofi "${WOFI_OPTS[@]}" --prompt "Fuente (Enter = ${DEFAULT_FAMILY}) > " || true
}

# Elige tamaño en wofi (8-14; la default aparece primero).
elegir_tamano() {
  local tamano_default="${1:-10}"
  printf '%s\n' 8 9 "${tamano_default}" 10 11 12 13 14 |
    awk '!seen[$0]++' |
    wofi "${WOFI_OPTS[@]}" --prompt 'Tamaño > ' || true
}

# Tamaño actual definido en la config (para usarlo como default al editar).
# La línea "font pango:" tiene dos formas válidas: literal
# ("font pango:JetBrainsMono Nerd Font 12") o delegada en variables
# ("font pango:$font-family $font-size"). En la segunda el número no está en
# esa línea, así que la captura devuelve la variable y el tamaño real se lee
# de "set $font-size".
tamano_actual() {
  local token
  token="$(sed -nE 's|^font pango:.* (\$[A-Za-z-]+\|[0-9]+)$|\1|p' "${CONFIG_FILE}" 2>/dev/null | head -n1)"
  if [[ "${token}" == \$* ]]; then
    token="$(sed -nE 's|^set \$font-size +([0-9]+).*$|\1|p' "${VARS_FILE}" 2>/dev/null | head -n1)"
  fi
  printf '%s' "${token}"
}

cambiar_fuente() {
  local familia="$1"
  local tamano="$2"
  local nueva_linea="font pango:${familia}"
  [[ -n "${tamano}" ]] && nueva_linea="font pango:${familia} ${tamano}"

  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "No existe ${CONFIG_FILE}; primero aplicá los dotfiles (scripts/04-setup-dotfiles.sh)." >&2
    return 1
  fi

  if grep -qE '^font pango:.* \$' "${CONFIG_FILE}"; then
    # La línea delega en $font-family/$font-size: el valor real no está ahí, así
    # que se edita el módulo de variables y la línea se deja intacta.
    if [[ ! -f "${VARS_FILE}" ]]; then
      echo "No existe ${VARS_FILE}; no se puede editar \$font-family/\$font-size." >&2
      return 1
    fi
    sed -i -E "s|^set \\\$font-family .*|set \\\$font-family ${familia}|" "${VARS_FILE}"
    if [[ -n "${tamano}" ]]; then
      sed -i -E "s|^set \\\$font-size .*|set \\\$font-size ${tamano}|" "${VARS_FILE}"
    fi
  elif grep -q '^font pango:' "${CONFIG_FILE}"; then
    sed -i -E "s|^font pango:.*|${nueva_linea}|" "${CONFIG_FILE}"
  else
    # No existe la línea: la agrega tras la sección de Variables (o al final).
    local linea_vars
    linea_vars="$(grep -n -iE '^# *variables' "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d: -f1 || true)"
    if [[ -n "${linea_vars}" ]]; then
      sed -i "${linea_vars}a ${nueva_linea}" "${CONFIG_FILE}"
    else
      printf '%s\n' "${nueva_linea}" >> "${CONFIG_FILE}"
    fi
  fi

  echo "Fuente de sway actualizada: ${nueva_linea}"
  recargar_si_activo
}

# Recarga sway solo si hay una sesión activa.
recargar_si_activo() {
  if command -v swaymsg &>/dev/null &&
     { [[ -S "${SWAYSOCK:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; } &&
     pgrep -x sway &>/dev/null; then
    swaymsg reload && echo 'Configuración de sway recargada.'
  fi
}

# --- Modo argumentos: sway-font.sh <familia> [tamaño] ---
if [[ $# -ge 1 ]]; then
  cambiar_fuente "$1" "${2:-}"
  exit 0
fi

# --- Modo interactivo ---
familia="$(elegir_familia)"
[[ -z "${familia}" ]] && { echo 'Cancelado.'; exit 0; }

tamano="$(elegir_tamano "$(tamano_actual)")"
[[ -z "${tamano}" ]] && { echo 'Cancelado.'; exit 0; }

cambiar_fuente "${familia}" "${tamano}"