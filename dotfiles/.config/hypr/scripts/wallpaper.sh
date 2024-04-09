#!/bin/bash
#                _ _
# __      ____ _| | |_ __   __ _ _ __   ___ _ __
# \ \ /\ / / _` | | | '_ \ / _` | '_ \ / _ \ '__|
#  \ V  V / (_| | | | |_) | (_| | |_) |  __/ |
#   \_/\_/ \__,_|_|_| .__/ \__,_| .__/ \___|_|
#                   |_|         |_|
# -----------------------------------------------------

# Archivo de cache para mantener el fondo de pantalla actual
cache_file="$HOME/.cache/current_wallpaper"
blurred="$HOME/.cache/blurred_wallpaper.png"
rasi_file="$HOME/.cache/current_wallpaper.rasi"
blur_file="$HOME/.config/.settings/blur.sh"

blur="50x30"
blur=$(cat $blur_file)

# Crea un archivo de cache si no existe
if [ ! -f $cache_file ]; then
	touch $cache_file
	echo "$HOME/wallpaper/default.jpg" >"$cache_file"
fi

# Crea archivo rasi si no existe
if [ ! -f $rasi_file ]; then
	touch $rasi_file
	echo "* { imagen actual: url(\"$HOME/wallpaper/default.jpg\", height); }" >"$rasi_file"
fi

current_wallpaper=$(cat "$cache_file")

case $1 in

# Carga el fondo de pantalla desde .cache de la última sesión
"init")
	sleep 1
	if [ -f $cache_file ]; then
		wal -q -i $current_wallpaper
	else
		wal -q -i ~/wallpaper/
	fi
	;;

# Selecciona el fondo de pantalla con rofi
"select")
	sleep 0.2
	selected=$(find "$HOME/wallpaper" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" \) -exec basename {} \; | sort -R | while read rfile; do
		echo -en "$rfile\x00icon\x1f$HOME/wallpaper/${rfile}\n"
	done | rofi -dmenu -i -replace -config ~/.config/rofi/config-wallpaper.rasi)
	if [ ! "$selected" ]; then
		echo "No seleccionaste un fondo de pantalla"
		exit
	fi
	wal -q -i ~/wallpaper/$selected
	;;

# Selecciona un fondo de pantalla de manera aleatoria
*)
	wal -q -i ~/wallpaper/
	;;

esac

# -----------------------------------------------------
# Carga el esquema de color actual de pywal
# -----------------------------------------------------
source "$HOME/.cache/wal/colors.sh"
echo ":: Fondo de pantalla: $wallpaper"

# -----------------------------------------------------
# Obtener el nombre de la imagen
# -----------------------------------------------------
newwall=$(echo $wallpaper | sed "s|$HOME/wallpaper/||g")

# -----------------------------------------------------
# Recargar la waybar con los nuevos colores
# -----------------------------------------------------
~/.config/waybar/launch.sh

# -----------------------------------------------------
# Establece el nuevo fondo de pantalla
# -----------------------------------------------------
# transition_type="wipe"
# transition_type="outer"
transition_type="random"

swww img $wallpaper \
	--transition-bezier .43,1.19,1,.4 \
	--transition-fps=60 \
	--transition-type=$transition_type \
	--transition-duration=0.7 \
	--transition-pos "$(hyprctl cursorpos)"

if [ "$1" == "init" ]; then
	echo ":: Init"
else
	sleep 1
	dunstify "Cambiando fondo de pantalla..." " con la imagen $newwall" -h int:value:33 -h string:x-dunst-stack-tag:wallpaper
	sleep 2
fi

# -----------------------------------------------------
# Crear fondo de pantalla difuminado
# -----------------------------------------------------
if [ "$1" == "init" ]; then
	echo ":: Inicio"
else
	dunstify "Creando la versión difuminada..." "con la imagen $newwall" -h int:value:66 -h string:x-dunst-stack-tag:wallpaper
fi

magick $wallpaper -resize 75% $blurred
echo ":: Redimensionar a 75%"
if [ ! "$blur" == "0x0" ]; then
	magick $blurred -blur $blur $blurred
	echo ":: Difuminado"
fi

# -----------------------------------------------------
# Escribir el wallpaper seleccionado en los archivos .cache
# -----------------------------------------------------
echo "$wallpaper" >"$cache_file"
echo "* { current-image: url(\"$blurred\", height); }" >"$rasi_file"

# -----------------------------------------------------
# Enviar notificación
# -----------------------------------------------------

if [ "$1" == "init" ]; then
	echo ":: Inicio"
else
	dunstify "¡Cambio del wallpaper completo!" "con la imagen $newwall" -h int:value:100 -h string:x-dunst-stack-tag:wallpaper
fi

echo "FINALIZADO!"
