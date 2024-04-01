#!/bin/bash

# ------------------------------------------------------
# Función: Verifica si el paquete está instalado
# ------------------------------------------------------
_isInstalledPacman() {
    package="$1";
    check="$(sudo pacman -Qs --color always "${package}" | grep "local" | grep "${package} ")";
    if [ -n "${check}" ] ; then
        echo 0; #'0' significa 'true' en Bash
        return; #true
    fi;
    echo 1; #'1' significa 'false' en Bash
    return; #false
}

_isInstalledYay() {
    package="$1";
    check="$(yay -Qs --color always "${package}" | grep "local" | grep "\." | grep "${package} ")";
    if [ -n "${check}" ] ; then
        echo 0; #'0' significa 'true' en Bash
        return; #true
    fi;
    echo 1; #'1' significa 'false' en Bash
    return; #false
}

_isFolderEmpty() {
    folder="$1"
    if [ -d $folder ] ;then
        if [ -z "$(ls -A $folder)" ]; then
            echo 0
        else
            echo 1
        fi
    else
        echo 1
    fi
}

# -----------------------------------------------------------
# Función: Instala todos los paquetes si no están instalados
# -----------------------------------------------------------
_installPackagesPacman() {
    toInstall=();
    for pkg; do
        if [[ $(_isInstalledPacman "${pkg}") == 0 ]]; then
            echo ":: ${pkg} ya se encuentra instalado.";
            continue;
        fi;
        toInstall+=("${pkg}");
    done;

    if [[ "${toInstall[@]}" == "" ]] ; then
        # echo "Todos los paquetes de pacman se encuentran instalados.";
        return;
    fi;

    # printf "Paquete no instalado:\n%s\n" "${toInstall[@]}";
    sudo pacman --noconfirm -S "${toInstall[@]}";
}

_forcePackagesPacman() {
    toInstall=();
    for pkg; do
        toInstall+=("${pkg}");
    done;

    if [[ "${toInstall[@]}" == "" ]] ; then
        # echo "Todos los paquetes de pacman ya se encuentran instalados.";
        return;
    fi;

    # printf "Paquete no instalado:\n%s\n" "${toInstall[@]}";
    sudo pacman --noconfirm -S "${toInstall[@]}" --ask 4;
}

_installPackagesYay() {
    toInstall=();
    for pkg; do
        if [[ $(_isInstalledYay "${pkg}") == 0 ]]; then
            echo ":: ${pkg} ya se encuentra instalado.";
            continue;
        fi;
        toInstall+=("${pkg}");
    done;

    if [[ "${toInstall[@]}" == "" ]] ; then
        # echo "Todos los paquetes ya se encuentran instalados.";
        return;
    fi;

    # printf "Paquetes AUR no instalados:\n%s\n" "${toInstall[@]}";
    yay --noconfirm -S "${toInstall[@]}";
}

_forcePackagesYay() {
    toInstall=();
    for pkg; do
        toInstall+=("${pkg}");
    done;

    if [[ "${toInstall[@]}" == "" ]] ; then
        # echo "Todos los paquetes estan instalados.";
        return;
    fi;

    # printf "Paquetes AUR no instalados:\n%s\n" "${toInstall[@]}";
    yay --noconfirm -S "${toInstall[@]}" --ask 4;
}

# ------------------------------------------------------
# Crea links simbólicos
# ------------------------------------------------------
_installSymLink() {
    name="$1"
    symlink="$2";
    linksource="$3";
    linktarget="$4";
    
    if [ -L "${symlink}" ]; then
        rm ${symlink}
        ln -s ${linksource} ${linktarget} 
        echo ":: Symlink ${linksource} -> ${linktarget} creado."
    else
        if [ -d ${symlink} ]; then
            rm -rf ${symlink}/ 
            ln -s ${linksource} ${linktarget}
            echo ":: Symlink para directorio ${linksource} -> ${linktarget} creado."
        else
            if [ -f ${symlink} ]; then
                rm ${symlink} 
                ln -s ${linksource} ${linktarget} 
                echo ":: Symlink para archivo ${linksource} -> ${linktarget} creado."
            else
                ln -s ${linksource} ${linktarget} 
                echo ":: Nuevo symlink ${linksource} -> ${linktarget} creado."
            fi
        fi
    fi
}

# ------------------------------------------------------
# Instalación en una Máquina Virtual KVM
# ------------------------------------------------------
_isKVM() {
    iskvm=$(sudo dmesg | grep "Hypervisor detectado")
    if [[ "$iskvm" =~ "KVM" ]] ;then
        echo 0
    else
        echo 1
    fi
}

# _replaceInFile $startMarket $endMarker $customtext $targetFile
_replaceInFile() {

    # Establece parámetros para la función
    start_string=$1
    end_string=$2
    new_string="$3"
    file_path="$4"

    # Contadores
    start_line_counter=0
    end_line_counter=0
    start_found=0
    end_found=0

    if [ -f $file_path ] ;then

        # Detecta el inicio del String
        while read -r line
        do
            ((start_line_counter++))
            if [[ $line = *$start_string* ]]; then
                # echo "Inicio contrado en $start_line_counter"
                start_found=$start_line_counter
                break
            fi 
        done < "$file_path"

        # Detecta el final del String
        while read -r line
        do
            ((end_line_counter++))
            if [[ $line = *$end_string* ]]; then
                # echo "Final encontrado en $end_line_counter"
                end_found=$end_line_counter
                break
            fi 
        done < "$file_path"

        # Verifica que los delimitadores existen
        if [[ "$start_found" == "0" ]] ;then
            echo "ERROR: Delimitador de inicio no encontrado."
            sleep 2
        fi
        if [[ "$end_found" == "0" ]] ;then
            echo "ERROR: Delimitador final no encontrado."
            sleep 2
        fi

        # Replace text between delimiters
        if [[ ! "$start_found" == "0" ]] && [[ ! "$end_found" == "0" ]] && [ "$start_found" -le "$end_found" ] ;then
            # Remueve la antigua línea
            ((start_found++))

            if [ ! "$start_found" == "$end_found" ] ;then    
                ((end_found--))
                sed -i "$start_found,$end_found d" $file_path
            fi
            # Agrega la nueva línea
            sed -i "$start_found i $new_string" $file_path
        else
            echo "ERROR: Sintaxis de los delimitadores."
            sleep 2
        fi
    else
        echo "ERROR: Archivo de destino no encontrado."
        sleep 2
    fi
}

# replaceLineInFile $findText $customtext $targetFile
_replaceLineInFile() {
   # Establece parámetros para la función
    find_string="$1"
    new_string="$2"
    file_path=$3

    # Contadores
    find_line_counter=0
    line_found=0

    if [ -f $file_path ] ;then

        # Detecta la línea
        while read -r line
        do
            ((find_line_counter++))
            if [[ $line = *$find_string* ]]; then
                # echo "Inicio encontrado en $start_line_counter"
                line_found=$find_line_counter
                break
            fi 
        done < "$file_path"

        if [[ ! "$line_found" == "0" ]] ;then
            
            # Remueve la línea antigua
            sed -i "$line_found d" $file_path

            # Agrega la nueva línea
            sed -i "$line_found i $new_string" $file_path            

        else
            echo "ERROR: Línea objetivo no encontrada."
            sleep 2
        fi   

    else
        echo "ERROR: Archivo objetivo no encontrado."
        sleep 2
    fi
}


