# dotfiles
Administración de mis dotfiles con la herramienta **GNU Stow**, cual sirve para administrar dotfiles en distribuciones de Linux.

## **Instalación de Stow:**

1. Abre una terminal en Fedora.

2. Asegúrate de tener el gestor de paquetes `dnf` actualizado:

   ```bash
   sudo dnf update
   ```

3. Instala Stow utilizando `dnf`:

   ```bash
   sudo dnf install stow
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


