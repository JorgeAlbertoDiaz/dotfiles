#!/bin/bash
figlet "Habilitar SDDM"
if [ -f /etc/systemd/system/display-manager.service ]; then
	echo ":: El gestor de pantalla ya se encuentra habilitado."
else
	if gum confirm "¿Deseas habilitar SDDM como tu gestor de pantalla?"; then
		sudo systemctl enable sddm.service
		echo ":: El gestor de pantalla SDDM ha sido activado."
		echo ":: ¡Por favor reinicia tu sistema!"
	fi
fi
sleep 3
