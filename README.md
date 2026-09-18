# dotfiles

Dotfiles e instalador para un sistema funcional sobre **openSUSE Tumbleweed**,
incluyendo soporte para la **NVIDIA GTX 1060 3 GB**, desde una instalación limpia.

## Objetivo

No solo guardar configuraciones: provee un instalador interactivo para preparar
todo el sistema — repositorios, paquetes, controladores NVIDIA, shell y dotfiles.

## Requisitos

- **Sistema:** openSUSE Tumbleweed (instalación limpia o reciente)
- **GPU:** NVIDIA GeForce GTX 1060 3 GB (controladores propietarios G06)
- **Conexión a internet**

## Uso

```bash
git clone https://github.com/JorgeAlbertoDiaz/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh scripts/*.sh
./install.sh
```

El instalador verifica el sistema, garantiza los directorios XDG, instala
`gum` si falta, y muestra un menú interactivo multi-selección para elegir los
componentes a instalar: paquetes base, escritorio Sway, shell, herramientas
dev, NVIDIA y dotfiles.

## Estructura

```text
.
├── install.sh               # Orquestador principal (TUI con gum)
├── packages/                # Paquetes zypper en texto plano (1 por línea)
│   ├── base.txt
│   ├── desktop-sway.txt
│   ├── nvidia.txt
│   ├── shell.txt
│   └── dev.txt
├── scripts/                 # Scripts independientes
│   ├── common.sh            # Funciones compartidas (log, sudo, confirm, XDG)
│   ├── 00-check-system.sh   # Verifica openSUSE Tumbleweed
│   ├── 00-xdg-dirs.sh       # Verifica/crea directorios XDG y descargas
│   ├── 01-install-gum.sh    # Instala gum (zypper + fallback GitHub)
│   ├── 02-install-packages.sh  # Recorre packages/*.txt e instala con zypper
│   ├── 03-nvidia-setup.sh   # Repo NVIDIA + controladores + GRUB/modprobe
│   ├── 04-setup-dotfiles.sh # Copia dotfiles a ~/.config/<app> + zsh
│   └── 05-install-fonts.sh  # Instala y configura Nerd Fonts por app
├── config/                  # Copia directa: cada app en ~/.config/<app>
│   ├── home/                # Dotfiles que van directo a $HOME
│   └── <app>/customize.sh   # Personalizan la fuente de cada aplicación
└── docs/                    # Documentación y diagramas Mermaid (.mmd)
```

## Documentación

Más detalles en [docs/index.md](docs/index.md).

## Notas

- `config/` no usa GNU Stow: cada subdirectorio de `config/` (excepto
  `home/`) se copia tal cual a `~/.config/<app>/` con
  `scripts/04-setup-dotfiles.sh`. `home/` se copia a `$HOME`. Los
  `customize.sh` son herramientas del repo y no se copian; se ejecutan desde
  `05-install-fonts.sh` para configurar la fuente por app.
- Los controladores NVIDIA se instalan desde el repositorio oficial de NVIDIA.
- Las Nerd Fonts se descargan por familia desde `ryanoasis/nerd-fonts`
  (GitHub Releases) y se instalan en `~/.local/share/fonts` sin sudo.
- La shell por defecto se cambia a zsh (opcional durante la instalación).