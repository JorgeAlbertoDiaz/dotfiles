#!/bin/bash
#  _   _           _       _                 _     _
# | | | |_ __   __| | __ _| |_ ___   ___  __| | __| |_ __ ___
# | | | | '_ \ / _` |/ _` | __/ _ \ / __|/ _` |/ _` | '_ ` _ \
# | |_| | |_) | (_| | (_| | ||  __/ \__ \ (_| | (_| | | | | | |
#  \___/| .__/ \__,_|\__,_|\__\___| |___/\__,_|\__,_|_| |_| |_|
#       |_|
# -----------------------------------------------------
cache_file="$HOME/.cache/current_wallpaper"
sleep 1
clear
figlet "Establece el fondo de pantalla"
echo
echo "Establece el fondo de pantalla actual como fondo de pantalla de SDDM"
echo
if [ ! -d /etc/sddm.conf.d/ ]; then
	sudo mkdir /etc/sddm.conf.d
	echo "Directorio /etc/sddm.conf.d creado."
fi

sudo cp $HOME/.config/sddm/sddm.conf /etc/sddm.conf.d/
echo "Archivo /etc/sddm.conf.d/sddm.conf actualizado."

current_wallpaper=$(cat "$cache_file")
extension="${current_wallpaper##*.}"

sudo cp $current_wallpaper /usr/share/sddm/themes/sugar-candy/Backgrounds/current_wallpaper.$extension
echo "Current wallpaper copied into /usr/share/sddm/themes/sugar-candy/Backgrounds/"
echo "Fondo de pantalla actual copiado dentro de /usr/share/sddm/themes/sugar-candy/Backgrounds/"
new_wall=$(echo $current_wallpaper | sed "s|$HOME/wallpaper/||g")
sudo cp $HOME/.config/sddm/theme.conf /usr/share/sddm/themes/sugar-candy/
sudo sed -i 's/CURRENTWALLPAPER/'"current_wallpaper.$extension"'/' /usr/share/sddm/themes/sugar-candy/theme.conf

echo "File theme.conf updated in /usr/share/sddm/themes/sugar-candy/"
echo "Archivo theme.conf actualizado en /usr/share/sddm/themes/sugar-candy/"

echo "¡Hecho! Por favor cierra sesión para probar sddm."
sleep 3
