# ------------------------------------------------------
# Incia pywal con el fondo de pantalla por defecto
# ------------------------------------------------------

if [ ! -f ~/.cache/wal/colors-hyprland.conf ]; then
    _installSymLink wal ~/.config/wal ~/dotfiles/wal/ ~/.config
    wal -i ~/dotfiles/wallpapers/default.jpg
    info_message "Pywal y plantillas activadas."
    echo ""
else
    echo "Pywal ya se encuentra instalado."
    echo ""
fi