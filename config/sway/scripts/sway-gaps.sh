#!/usr/bin/env bash
# sway-gaps.sh — personaliza el espaciado interior (gaps inner) de sway
# sobre la config APLICADA (~/.config/sway/config), no sobre la del repo.
#
# Uso:
#   sway-gaps.sh              # menú interactivo con valores predefinidos
#   sway-gaps.sh <valor>      # aplica un valor directo (ej. sway-gaps.sh 8)
#
# Reescribe la línea "gaps inner N" del config de sway conservando el resto.
# Si no existe, la agrega. Si hay una sesión de sway activa, recarga.
set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sway/config"
VALORES_PREDEFINIDOS=(0 4 8 12 16 20)

# Opciones base de wofi (estilo consistente con el launcher del sistema).
WOFI_OPTS=(--dmenu --insensitive)
[[ -f /etc/wofi/config ]] && WOFI_OPTS+=(--conf /etc/wofi/config)
[[ -f /etc/wofi/style.css ]] && WOFI_OPTS+=(--style /etc/wofi/style.css)

cambiar_gaps() {
  local valor="$1"
  if [[ ! "${valor}" =~ ^[0-9]+$ ]]; then
    echo "Valor inválido: ${valor} (esperaba un número entero)" >&2
    return 2
  fi

  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "No existe ${CONFIG_FILE}; primero aplicá los dotfiles (scripts/04-setup-dotfiles.sh)." >&2
    return 1
  fi

  if grep -q '^gaps inner [0-9]' "${CONFIG_FILE}"; then
    sed -i -E "s|^gaps inner [0-9]+|gaps inner ${valor}|" "${CONFIG_FILE}"
  else
    # No existe la línea: la agrega junto a la apariencia (tras default_border),
    # o al final si no encuentra dónde.
    local linea_border
    linea_border="$(grep -n '^default_border ' "${CONFIG_FILE}" 2>/dev/null | head -n1 | cut -d: -f1 || true)"
    if [[ -n "${linea_border}" ]]; then
      sed -i "${linea_border}a gaps inner ${valor}" "${CONFIG_FILE}"
    else
      printf 'gaps inner %s\n' "${valor}" >> "${CONFIG_FILE}"
    fi
  fi

  echo "Gaps inner de sway actualizados: ${valor}px"
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

# --- Modo argumentos: sway-gaps.sh <valor> ---
if [[ $# -ge 1 ]]; then
  cambiar_gaps "$1"
  exit 0
fi

# --- Modo interactivo ---
valor="$(printf '%s\n' "${VALORES_PREDEFINIDOS[@]}" | wofi "${WOFI_OPTS[@]}" --prompt 'Gaps inner (px) > ' || true)"
[[ -z "${valor}" ]] && { echo 'Cancelado.'; exit 0; }

cambiar_gaps "${valor}"