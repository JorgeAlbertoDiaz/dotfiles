# -----------------------------------------------------------------
# Verifica que los paquetes requeridos para correr la instalación
# -----------------------------------------------------------------

# Sincronización de paquetes
sudo pacman -Sy
echo ""

# Verificación de paquetes instalados
info_message ":: Verficando que los paquetes necesarios para la instalación se encuentren instalados..."
_installPackagesPacman "rsync" "gum" "figlet" "python";
echo ""

# Doble verificación para rsync
if ! command -v rsync &> /dev/null; then
    info_message ":: Forzar la instalación de rsync"
    sudo pacman -S rsync --noconfirm
else
    success_message ":: rsync doblemente verificado"
fi
echo ""

