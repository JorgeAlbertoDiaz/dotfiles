#!/bin/bash
#  _              _     _           _ _                  d
# | | _____ _   _| |__ (_)_ __   __| (_)_ __   __ _ ___
# | |/ / _ \ | | | '_ \| | '_ \ / _` | | '_ \ / _` / __|
# |   <  __/ |_| | |_) | | | | | (_| | | | | | (_| \__ \
# |_|\_\___|\__, |_.__/|_|_| |_|\__,_|_|_| |_|\__, |___/
#           |___/                             |___/
# -----------------------------------------------------

# -----------------------------------------------------
# Get keybindings location based on variation
# -----------------------------------------------------
config_file=$(cat ~/.config/hypr/conf/keybinding.conf)
config_file=${config_file/source = ~/}
config_file=${config_file/source=~/}

# -----------------------------------------------------
# Ruta al archivo de configuración de las configuraciones de teclas
# -----------------------------------------------------
config_file="/home/$USER$config_file"
echo "Leyendo desde: $config_file"

# -----------------------------------------------------
# Analiza las combinaciones de teclas
# -----------------------------------------------------
keybinds=$(grep -oP '(?<=bind = ).*' $config_file)
keybinds=$(echo "$keybinds" | sed 's/$mainMod/SUPER/g' | sed 's/,\([^,]*\)$/ = \1/' | sed 's/, exec//g' | sed 's/^,//g')

# -----------------------------------------------------
# Mostrar configuraciones de teclas en rofi
# -----------------------------------------------------
sleep 0.2
rofi -dmenu -i -replace -p "Keybinds" -config ~/.config/rofi/config-compact.rasi <<<"$keybinds"
