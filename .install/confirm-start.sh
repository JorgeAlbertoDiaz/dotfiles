# ------------------------------------------------------
# Confirma inicio del script
# ------------------------------------------------------

warning_message "Puedes cancelar la instalación en cualquier momento con CTRL + C"
echo ""

USER=$(whoami)

if gum confirm "¿Deseas comenzar el proceso de instalación de los dotfiles?" ;then
    success_message "Instalación iniciada por el usuario: ${USER}."
elif [ $? -eq 130 ]; then
    exit 130
else
    warning_message ":: Instalación cancelada por el usuario: ${USER}. ::"
    exit;
fi
