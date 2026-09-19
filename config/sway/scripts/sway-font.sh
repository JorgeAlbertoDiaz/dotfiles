#!/usr/bin/env bash
# sway-font.sh — personaliza la fuente de sway sobre la config APLICADA
# (~/.config/sway/config), no sobre la del repositorio.
#
# Uso:
#   sway-font.sh                      # interactivo: familia + tamaño en wofi
#   sway-font.sh <familia>            # aplica familia (tamaño actual o por defecto)
#   sway-font.sh <familia> <tamaño>   # aplica familia y tamaño
#
# Reescribe la línea "font pango:" del config de sway conservando el resto.
# Si la línea no existe, la agrega en la sección de Variables. Si hay una
# sesión de sway activa, recarga la configuración.
set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sway/config"
DEFAULT_FAMILY='JetBrainsMono Nerd Font'

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
tamano_actual() {
  sed -nE 's/^font pango:[^ ]+ ([0-9]+)$/\1/p' "${CONFIG_FILE}" 2>/dev/null | head -n1
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

  if grep -q '^font pango:' "${CONFIG_FILE}"; then
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