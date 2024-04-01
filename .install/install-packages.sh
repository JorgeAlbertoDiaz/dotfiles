if [[ "$force_install" == "1" ]] ;then
    # echo "Forzar la instalación de todos los paquetes..."
    _forcePackagesPacman "${packagesPacman[@]}";
    _forcePackagesYay "${packagesYay[@]}";
else
    # echo "Instalar solo los paquetes no instalados..."
    _installPackagesPacman "${packagesPacman[@]}";
    _installPackagesYay "${packagesYay[@]}";
fi
echo ""
