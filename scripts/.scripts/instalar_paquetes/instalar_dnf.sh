#!/bin/bash

# Especifica el nombre del archivo de lista de paquetes
paquetes="paquetes_dnf.txt"

# Verifica si el archivo de listado de paquetes existe
if [ -f "$paquetes" ]; then
	# Actualiza el listado de paquetes antes de intentar instalar los paquetes
	sudo dnf update -y

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

# Nombre del repositorio Copr que deseas activar
COPR_REPO="atim/lazygit"

# Comprobar si el repositorio Copr ya está habilitado
if dnf repolist enabled | grep "atim:lazygit"; then
	echo "El repositorio Copr '$COPR_REPO' ya está habilitado."
else
	# Agregar atim/lazygit para poder instalarlo
	echo "Habilitando el repositorio Copr '$COPR_REPO'..."
	sudo dnf copr enable -y $COPR_REPO

	# Comprobar si la habilitación fue exitosa
	if [ $? -eq 0 ]; then
		# Instala lazygit
		echo "Repositorio Copr '$COPR_REPO' habilitado con éxito."
		sudo dnf install lazygit -y
	else
		echo "Error al habilitar el repositorio Copr '$COPR_REPO'."
	fi
fi
