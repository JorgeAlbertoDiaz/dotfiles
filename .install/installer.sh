# ------------------------------------------------------
# Como vas a Installar los paquetes requeridos
# ------------------------------------------------------
message "$(figlet 'Paquetes')"
echo ""
message "¿Quieres instalar solo los paquetes nuevos? (instalación más rápida)\nprefieres reinstalar todos los paquetes otra vez? (más robusta y puede ayudar a reparar problemas)"

if gum confirm "¿Cómo deseas proceder??" --affirmative "Solo paquetes nuevos" --negative "Forzar reinstalación" ;then
    force_install=0
elif [ $? -eq 130 ]; then
    warning_message "Instalación cancelada."
    exit 130
else
    force_install=1
fi