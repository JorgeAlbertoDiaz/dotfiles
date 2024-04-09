#!/bin/bash
figlet "Desactiva SDDM"
if [ -f /etc/systemd/system/display-manager.service ]; then
	if gum confirm "¿Deseas desactivar SDDM como gestor de pantalla?"; then
		sudo rm /etc/systemd/system/display-manager.service
		echo ":: El gestor de pantalla fue quitado."
		echo ":: Por favor reinicia tu sistema."
	fi
else
	echo ":: No hay un gestor de pantalla habilitado."
fi
sleep 3
