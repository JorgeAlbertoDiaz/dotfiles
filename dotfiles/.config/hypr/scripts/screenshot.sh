#!/bin/bash
#  ____                               _           _    
# / ___|  ___ _ __ ___  ___ _ __  ___| |__   ___ | |_  
# \___ \ / __| '__/ _ \/ _ \ '_ \/ __| '_ \ / _ \| __| 
#  ___) | (__| | |  __/  __/ | | \__ \ | | | (_) | |_  
# |____/ \___|_|  \___|\___|_| |_|___/_| |_|\___/ \__| 
#                                                      
# ----------------------------------------------------- 

DIR="$HOME/Pictures/screenshots/"
NAME="screenshot_$(date +%d%m%Y_%H%M%S).png"

if [ ! -d "$DIR" ]; then
    # Crear el directorio si no existe
    mkdir -p "$DIR"
fi

option2="Area seleccionada"
option3="Pantalla completa (espera 3 seg.)"

options="$option2\n$option3"

choice=$(echo -e "$options" | rofi -dmenu -replace -config ~/.config/rofi/config-screenshot.rasi -i -no-show-icons -l 2 -width 30 -p "Captura de pantalla")

case $choice in
    $option2)
        grim -g "$(slurp)" "$DIR$NAME"
        xclip -selection clipboard -t image/png -i "$DIR$NAME"
        notify-send "Captura de pantalla creada y copiada al portapapeles" "Modo: Area seleccioanda"
        swappy -f "$DIR$NAME"
    ;;
    $option3)
        sleep 3
        grim "$DIR$NAME" 
        xclip -selection clipboard -t image/png -i "$DIR$NAME"
        notify-send "Captura de pantalla creada y copiada al portapapeles" "Modo: Pantalla completa"
        swappy -f "$DIR$NAME"
    ;;
esac
