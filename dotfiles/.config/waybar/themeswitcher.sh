#!/bin/bash
#  _____ _                                       _ _       _
# |_   _| |__   ___ _ __ ___   ___  _____      _(_) |_ ___| |__   ___ _ __
#   | | | '_ \ / _ \ '_ ` _ \ / _ \/ __\ \ /\ / / | __/ __| '_ \ / _ \ '__|
#   | | | | | |  __/ | | | | |  __/\__ \\ V  V /| | || (__| | | |  __/ |
#   |_| |_| |_|\___|_| |_| |_|\___||___/ \_/\_/ |_|\__\___|_| |_|\___|_|
# -----------------------------------------------------

# -----------------------------------------------------
# Directorio por defecto para los temas
# -----------------------------------------------------
themes_path="$HOME/.config/waybar/themes"

# -----------------------------------------------------
# Inicialización de los arrays
# -----------------------------------------------------
listThemes=""
listNames=""

# -----------------------------------------------------
# Lee el directorio de temas
# -----------------------------------------------------
sleep 0.2
options=$(find $themes_path -maxdepth 2 -type d)
for value in $options; do
	if [ ! $value == "$HOME/.config/waybar/themes/assets" ]; then
		if [ ! $value == "$themes_path" ]; then
			if [ $(find $value -maxdepth 1 -type d | wc -l) = 1 ]; then
				result=$(echo $value | sed "s#$HOME/.config/waybar/themes/#/#g")
				IFS='/' read -ra arrThemes <<<"$result"
				listThemes[${#listThemes[@]}]="/${arrThemes[1]};$result"
				if [ -f $themes_path$result/config.sh ]; then
					source $themes_path$result/config.sh
					listNames+="$theme_name\n"
				else
					listNames+="/${arrThemes[1]};$result\n"
				fi
			fi
		fi
	fi
done

# -----------------------------------------------------
# Muestra el diálogo de rofi
# -----------------------------------------------------
listNames=${listNames::-2}
choice=$(echo -e "$listNames" | rofi -dmenu -replace -i -config ~/.config/rofi/config-themes.rasi -no-show-icons -width 30 -p "Temas" -format i)

# -----------------------------------------------------
# Establece el nuevo tema escribiendo sobre ~/.cache/.themestyle.sh
# -----------------------------------------------------
if [ "$choice" ]; then
	echo "Cargarndo tema waybar..."
	echo "${listThemes[$choice + 1]}" >~/.cache/.themestyle.sh
	~/.config/waybar/launch.sh
fi
