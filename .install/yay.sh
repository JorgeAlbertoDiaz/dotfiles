# ------------------------------------------------------
# Verifica si yay esta instalado en el sistema
# ------------------------------------------------------
message "$(figlet 'yay')"
if sudo pacman -Qs yay > /dev/null ; then
    success_message ":: !YAY se encuentra instalado en el sistema!"
else
    warning_message ":: !YAY no esta instalado. Comienzo el proceso de instalación!"
    _installPackagesPacman "base-devel"
    # SCRIPT=$(realpath "$0")
    DOWNLOAD_PATH="/home/$USER/Downloads"
    SCRIPT=$(realpath "$0")
    SCRIPTPATH=$(dirname "$SCRIPT")
    if ! [ -d "$DOWNLOAD_PATH" ]; then
        message "El directorio '$DOWNLOAD_PATH' no existe, se procede a crearlo."
	mkdir "$DOWNLOAD_PATH"
    fi
    info_message "$SCRIPT"
    info_message "$SCRIPTPATH"

    git clone https://aur.archlinux.org/yay-git.git "${DOWNLOAD_PATH}/yay-git"
    cd "${DOWNLOAD_PATH}/yay-git"
    makepkg -si
    cd $SCRIPTPATH
    success_message ":: YAY ha sido instalado correctamente."
fi

echo ""
info_message "Es importante que tu sistema se encuentre actualizado antes de continuar con la instalación de los dotfiles."
if gum confirm "¿Deseas actualizar los paquetes de tu sistema con YAY ahora?" ;then
    yay
fi

echo ""


