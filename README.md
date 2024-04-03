# Dotfiles (Archlinux)
Administración de mis dotfiles con la herramienta **GNU Stow**, cual sirve para administrar dotfiles en distribuciones de Linux.

## **Instalación de Stow:**

1. Abre una terminal.

2. Asegúrate de tener el gestor de paquetes actualizado:

   ```bash
   # Actualizar con pacman
   sudo pacman -Syu

   # Actualizar con yay
   yay
   ```

3. Instala Stow utilizando `pacman`:

   ```bash
   sudo pacman -S stow
   ```

Con Stow instalado, ahora puedes comenzar a administrar tus dotfiles:

### **Uso de Stow para administrar tus dotfiles:**

Supongamos que tienes una estructura de directorio donde almacenas tus dotfiles en una carpeta llamada `dotfiles` en tu directorio de inicio.
Los dotfiles individuales, como `.bashrc` o `.vimrc`, estarán en subdirectorios dentro de `dotfiles`.

1. Crea una estructura de directorio similar a la siguiente:

   ```plaintext
   ~/dotfiles/
   ├── bash/
   │   └── .bashrc
   ├── vim/
   │   └── .vimrc
   └── ...
   ```

2. Para "instalar" un dotfile en tu sistema, ve al directorio `dotfiles` y usa el comando `stow` junto con el nombre del subdirectorio correspondiente.
Por ejemplo, para instalar tu archivo `.bashrc`:

   ```bash
   cd ~/dotfiles
   stow bash
   ```

   Esto creará un enlace simbólico desde el archivo `.bashrc` en tu directorio `dotfiles/bash/` al directorio de inicio, de manera que los cambios en tu archivo `.bashrc` se reflejarán en tu sistema.

3. Si deseas eliminar un dotfile previamente instalado, simplemente ejecuta:

   ```bash
   stow -D bash
   ```

4. Puedes administrar varios subdirectorios de esta manera. Stow es útil para organizar dotfiles en diferentes categorías y mantenerlos separados.

5. Para administrar otros dotfiles, repite los pasos anteriores para cada subdirectorio correspondiente (por ejemplo, `vim`, `tmux`, etc.).

Con Stow, puedes mantener tus dotfiles organizados y sincronizados en múltiples sistemas de manera eficiente.
Esto facilita la gestión de la configuración de tu entorno de usuario en diferentes máquinas.

## configuración Nvidia
Para tener funcionando correctamente el sistema se debe instalar los controladores y configurarlo como lo indica [esta guía de hyperland](https://wiki.hyprland.org/Nvidia/)

1. Instalar el controlador `nvidia-dkms` y el paquete `linux-headers`.

```bash
sudo pacman -S linux-headers nvidia-dkms
```

2. Agregar la siguiente línea al archivo:

`/boot/loader/entries/arch.conf`
```bash
nvidia_drm.modeset=1
```

3. Agrega a los módulos las siguientes opciones:

`/etc/mkinitcpio.conf`
```bash
nvidia nvidia_modeset nvidia_uvm nvidia_drm
```

4. Ejecuta el comando:

```bash
mkinitcpio --config /etc/mkinitcpio.conf --generate /boot/initramfs-custom.img
```

5. Por último agrega la siguiente línea al archivo.

`/etc/modprobe.d/nvidia.conf`
```bash
options nvidia-drm modeset=1
```

> ¡Si el archivo no existe debes crearlo!