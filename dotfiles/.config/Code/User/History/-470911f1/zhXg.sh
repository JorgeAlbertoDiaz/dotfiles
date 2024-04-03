#!/bin/bash
source .install/includes/colors.sh
source .install/includes/library.sh

# ACTUALIZAR EL SISTEMA

clear
source .install/required.sh
source .install/confirm-start.sh
source .install/update_system.sh
source .install/yay.sh
source .install/installer.sh

# Instalación de los paquetes necesarios para el sistema
source .install/packages/general-packages.sh
source .install/install-packages.sh

# Instalación de los paquetes necesarios para Hyperland (quitar si usas otro escritorio)
info_message "Intalar los paquetes necesarios para Hyperland"
source .install/packages/hyprland-packages.sh
source .install/install-packages.sh
source .install/displaymanager.sh

source .install/init-pywall.sh