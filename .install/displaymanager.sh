disman=0
# Intenta forzar la instalación de sddm
info_message "Instala sddm"
yay -S --noconfirm sddm sddm-sugar-candy-git --ask 4

if [ -f /etc/systemd/system/display-manager.service ]; then
    sudo rm /etc/systemd/system/display-manager.service
fi
sudo systemctl enable sddm.service

if [ ! -d /etc/sddm.conf.d/ ]; then
    sudo mkdir /etc/sddm.conf.d
    message "Directorio /etc/sddm.conf.d creado."
fi

sudo cp sddm/sddm.conf /etc/sddm.conf.d/
message "Archivo /etc/sddm.conf.d/sddm.conf actualizado."

if [ -f /usr/share/sddm/themes/sugar-candy/theme.conf ]; then

    # Archivo cache para mantener el wallpaper actual
    sudo cp wallpapers/default.jpg /usr/share/sddm/themes/sugar-candy/Backgrounds/current_wallpaper.jpg
    echo "El fondo de pantalla por defecto se copió dentro de /usr/share/sddm/themes/sugar-candy/Backgrounds/"

    sudo cp sddm/theme.conf /usr/share/sddm/themes/sugar-candy/
    sudo sed -i 's/CURRENTWALLPAPER/'"current_wallpaper.jpg"'/' /usr/share/sddm/themes/sugar-candy/theme.conf
    echo "Archivo theme.conf actualizado en /usr/share/sddm/themes/sugar-candy/"

fi