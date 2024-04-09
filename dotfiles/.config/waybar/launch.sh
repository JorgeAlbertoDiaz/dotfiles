#!/bin/bash
#  ____  _             _    __        __          _
# / ___|| |_ __ _ _ __| |_  \ \      / /_ _ _   _| |__   __ _ _ __
# \___ \| __/ _` | '__| __|  \ \ /\ / / _` | | | | '_ \ / _` | '__|
#  ___) | || (_| | |  | |_    \ V  V / (_| | |_| | |_) | (_| | |
# |____/ \__\__,_|_|   \__|    \_/\_/ \__,_|\__, |_.__/ \__,_|_|
#                                           |___/
# -----------------------------------------------------

# Verifica si el archivo waybar-disabled existe
if [ -f $HOME/.cache/waybar-disabled ]; then
	killall waybar
	pkill waybar
	exit 1
fi

# -----------------------------------------------------
# Detiene todas las instancias de waybar activas
# -----------------------------------------------------
killall waybar
pkill waybar
sleep 0.2

# -----------------------------------------------------
# Tema por defecto: /THEMEFOLDER;/VARIATION
# -----------------------------------------------------
themestyle="/ml4w;/ml4w/light"

# -----------------------------------------------------
# Obtiene la información del tema activo desde .cache/.themestyle.sh
# -----------------------------------------------------
if [ -f ~/.cache/.themestyle.sh ]; then
	themestyle=$(cat ~/.cache/.themestyle.sh)
else
	touch ~/.cache/.themestyle.sh
	echo "$themestyle" >~/.cache/.themestyle.sh
fi

IFS=';' read -ra arrThemes <<<"$themestyle"
echo "Tema: ${arrThemes[0]}"

if [ ! -f ~/.config/waybar/themes${arrThemes[1]}/style.css ]; then
	themestyle="/ml4w;/ml4w/light"
fi

# -----------------------------------------------------
# Cargar la configuración
# -----------------------------------------------------
config_file="config"
style_file="style.css"

# Los archivos estandar pueden sobre escribirse con una configuración con los archivos config-custom o style-custom.css
if [ -f ~/.config/waybar/themes${arrThemes[0]}/config-custom ]; then
	config_file="config-custom"
fi
if [ -f ~/.config/waybar/themes${arrThemes[1]}/style-custom.css ]; then
	style_file="style-custom.css"
fi

waybar -c ~/.config/waybar/themes${arrThemes[0]}/$config_file -s ~/.config/waybar/themes${arrThemes[1]}/$style_file &
