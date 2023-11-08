#!/bin/bash

# Especifica el nombre del archivo de lista de paquetes
paquetes="paquetes_fronda.txt"

# Verifica si el archivo de listado de paquetes existe
if [ -f "$paquetes" ]; then
	# Utiliza el comando dnf para instalar paquetes de acuerdo al contenido del archivo
	sudo dnf install -y $(cat "$paquetes")
	# Verifica el código de salida de dnf para comprobar si la instalación fue exitosa
	if [ $? -eq 0 ]; then
		echo "Instalación exitosa."
	else
		echo "Error durante la instalación."
	fi
else
	echo "El archivo '$paquetes' no se encuentra en el directorio actual."
fi
