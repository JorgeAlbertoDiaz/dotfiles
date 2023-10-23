# Información de algunos de los paquetes instalados

## Herramientas y Librerías de Desarrollo en C

Esto es necesario para desarrollo en C, tambien la utiliza mi configuración de neovim y específicamente nvim-treesitter

Para ello se tiene que instalar el equivalente de **build-essential** en fedora

```bash
dnf group info "C Development Tools and Libraries"
```

Se utiliza en Fedora (y otras distribuciones basadas en Red Hat) para obtener información detallada sobre un grupo de paquetes. En este caso, estás buscando información sobre el grupo "C Development Tools and Libraries". Este grupo generalmente incluye paquetes esenciales para el desarrollo en el lenguaje de programación C en un sistema Fedora.

La información que obtendrás incluirá una lista de los paquetes que forman parte del grupo, una breve descripción de los paquetes y la descripción del grupo en sí.

Ten en cuenta que debes ejecutar este comando con privilegios de administrador o utilizando sudo para obtener la información detallada del grupo.

```bash
Grupo: Herramientas y Librerías de Desarrollo en C
 Descripción: Estas herramientas incluyen herramientas clave de desarrollo como automake, gcc y debuggers.
 Paquetes obligatorios:
   autoconf
   automake
   binutils
   bison
   flex
   gcc
   gcc-c++
   gdb
   glibc-devel
   libtool
   make
   pkgconf
   strace
 Paquetes predeterminados:
   byacc
   ccache
   cscope
   ctags
   elfutils
   indent
   ltrace
   perf
   valgrind
 Paquetes opcionales:
   ElectricFence
   astyle
   cbmc
   check
   cmake
   coan
   cproto
   insight
   nasm
   pscan
   python3-scons
   remake
   scorep
   splint
   yasm
   zzuf
```

Esta información te proporciona una descripción general de los paquetes esenciales que se instalan al seleccionar el grupo "C Development Tools and Libraries".
