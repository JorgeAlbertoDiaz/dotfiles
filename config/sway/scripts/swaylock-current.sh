#!/usr/bin/env bash
# Bloquea la pantalla usando la MISMA imagen que el fondo de escritorio actual.
#
# azote guarda su elección en ~/.azotebg, con líneas del estilo:
#   swaybg -o '<display>' -i "<imagen>" -m <modo> &
# Este wrapper toma la primera imagen de ahí y la usa como fondo del lock, así
# que cambiar el wallpaper (con azote) también cambia el lock sin pasos extra.
# Si no hay ~/.azotebg (o no tiene imagen), cae a la imagen por defecto.
#
# Lo invoca $screenlock (features/variables-colors.conf) en lugar de swaylock
# directo. Para un lock con imagen FIJA y distinta del escritorio, editá
# image= en ~/.config/swaylock/config y usá `swaylock` (sin --image) en su lugar.
set -euo pipefail

default_img="/usr/share/wallpapers/openSUSEdefault/contents/images/default-dark.png"
azotebg="${HOME}/.azotebg"

img=""
if [[ -r "${azotebg}" ]]; then
  img="$(grep -oE '\-i "[^"]+"' "${azotebg}" | head -n1 | sed -E 's/^-i "//; s/"$//')" || true
fi
if [[ -z "${img}" || ! -f "${img}" ]]; then
  img="${default_img}"
fi

args=(--image "${img}")
cfg="${XDG_CONFIG_HOME:-${HOME}/.config}/swaylock/config"
if [[ -f "${cfg}" ]]; then
  args=(--config "${cfg}" "${args[@]}")
fi

exec swaylock "${args[@]}"
