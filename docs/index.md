# Documentación

Índice de documentación del proyecto de dotfiles.

## Contenido

- [Arquitectura del proyecto](#arquitectura-del-proyecto)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Diagramas](#diagramas)
- [Ruta de desarrollo](#ruta-de-desarrollo)

## Arquitectura del proyecto

Este repositorio no solo guarda dotfiles: incluye un instalador que prepara un sistema **openSUSE Tumbleweed** desde una instalación limpia, gestionando repositorios, paquetes (zypper), controladores NVIDIA y las configuraciones del usuario.

| Ruta | Propósito |
|---|---|
| `install.sh` | Orquestador principal con interfaz TUI (gum) |
| `scripts/` | Scripts individuales, ejecutables de forma independiente |
| `packages/` | Archivos `.txt` planos con paquetes zypper (1 por línea) |
| `config/` | Configuraciones organizadas como paquetes stow (`target/` por app) |
| `docs/` | Documentación y diagramas (Mermaid en `.mmd`) |

### `packages/`

Cada archivo de texto agrupa paquetes por componente. El script
`scripts/02-install-packages.sh` los recorre línea por línea. Las líneas que
empiezan por `#` se ignoran.

| Archivo | Componente |
|---|---|
| `base.txt` | Herramientas base del sistema |
| `desktop-sway.txt` | Escritorio Sway + utilidades Wayland |
| `nvidia.txt` | Controladores NVIDIA (GTX 1060 3 GB) |
| `shell.txt` | Shell, terminal y editor |
| `dev.txt` | Herramientas de desarrollo |

### `config/` (stow)

Cada subdirectorio de `config/` es un *package* para GNU Stow. Al ejecutar
`stow -d config -t $HOME <package>` se crean symlinks, de modo que la fuente
de verdad es este repositorio. Los `customize.sh` que conviven con cada app
son ignorados por stow (`--ignore='^customize\.sh$'`) y se ejecutan desde
`05-install-fonts.sh` para personalizar la fuente (familia y tamaño).

```text
config/
├── home/                      # .bashrc, .zshrc, .gitconfig, .inputrc, .profile
├── sway/.config/sway/         # config del compositor (+ customize.sh)
├── foot/.config/foot/         # terminal foot (+ customize.sh)
├── waybar/.config/waybar/     # barra de estado (+ style.css y customize.sh)
└── environment.d/.config/     # variables de entorno (nvidia.conf)
```

## Requisitos

- openSUSE Tumbleweed (instalación limpia o reciente)
- Conexión a internet
- GPU NVIDIA GeForce GTX 1060 3 GB (soportada por los controladores G06)

## Instalación

```bash
git clone https://github.com/JorgeAlbertoDiaz/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh scripts/*.sh
./install.sh
```

El instalador:

1. Verifica que el sistema es openSUSE Tumbleweed.
2. Verifica y crea los directorios base XDG y la carpeta de descargas.
3. Instala `gum` desde el repositorio `repo-oss` (con fallback al binario de
   GitHub Releases) si no está presente.
4. Muestra un menú interactivo multi-selección de componentes (incluye
   `fonts`, para Nerd Fonts).
5. Instala paquetes, configura NVIDIA, instala/configura Nerd Fonts y aplica
   los dotfiles con stow.

### Componente `fonts`

`scripts/05-install-fonts.sh` verifica las Nerd Fonts instaladas (`fc-list`),
deja elegir qué familias instalar desde un catálogo curado (JetBrainsMono,
FiraCode, SourceCodePro, Hack, UbuntuMono, Ubuntu, RobotoMono, Monofur, más
entrada personalizada), las descarga por familia desde `ryanoasis/nerd-fonts`
a `~/.local/share/fonts` (sin sudo) y refresca `fc-cache`.

Después permite elegir, para cada aplicación con `customize.sh` (foot, sway,
waybar), qué fuente y tamaño aplicar; los cambios quedan en el repo y el
symlink de stow los refleja al instante. Si una fuente configurada falta,
fontconfig usará un fallback (p. ej. DejaVu Sans Mono).

> 💡 Si `gum` no pudiera instalarse (p. ej. sin red), `install.sh` usa un
> flujo de confirmación simple con bash.

## Diagramas

Los diagramas se definen con **Mermaid** en archivos `/docs/assets/*.mmd`
(referenciados desde el markdown, nunca incrustados):

| Diagrama | Descripción |
|---|---|
| [Flujo de instalación](./assets/flow.mmd) | Secuencia completa de `install.sh` |

Para visualizarlos localmente: abrir el `.mmd` en Obsidian, VS Code (con la
extensión habitual de Mermaid) o Typora.

## Ruta de desarrollo

- [ ] Probar `install.sh` en una instalación limpia
- [ ] Añadir configs de subida (Hyprland, nvim/LazyVim, wofi, etc.)
- [ ] Instaladores por fuente (npm global, AppImages, etc.)
- [ ] Soporte de otros SIDs (Arch, Fedora) manteniendo `common.sh`
- [ ] Tema de fondos de pantalla gestionado desde el repo