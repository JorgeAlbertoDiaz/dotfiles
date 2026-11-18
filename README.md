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
chmod +x install.sh scripts/*.sh scripts/drivers/*.sh
./install.sh
```

El instalador verifica el sistema, garantiza los directorios XDG, instala
`gum` si falta, y muestra un menú interactivo multi-selección para elegir los
componentes a instalar: paquetes base, escritorio Sway, shell, herramientas
dev, drivers de hardware y dotfiles.

## Estructura

```text
.
├── install.sh               # Orquestador principal (TUI con gum)
├── packages/                # Paquetes zypper en texto plano (1 por línea)
│   ├── base.txt
│   ├── desktop-sway.txt
│   ├── shell.txt
│   └── dev.txt
├── scripts/                 # Scripts independientes
│   ├── common.sh            # Funciones compartidas (log, sudo, confirm, XDG)
│   ├── 00-check-system.sh   # Verifica openSUSE Tumbleweed
│   ├── 00-xdg-dirs.sh       # Verifica/crea directorios XDG y descargas
│   ├── 01-install-gum.sh    # Instala gum (zypper + fallback GitHub)
│   ├── 02-install-packages.sh  # Recorre packages/*.txt e instala con zypper
│   ├── 04-setup-dotfiles.sh # Despliega config/ y home/ con inventario acotado
│   ├── 05-install-fonts.sh  # Instala y configura Nerd Fonts por app
│   ├── 08-setup-zsh.sh      # Instala los plugins de zsh (sin sudo)
│   ├── 09-setup-nvim.sh     # Instala plugins y LSP de nvim (sin sudo)
│   ├── 12-setup-handy.sh    # Dictado por voz: RPM pinneado + ajustes
│   ├── 13-setup-cloud-mounts.sh  # Monta Drive/OneDrive con rclone (por usuario)
│   ├── 14-setup-samba.sh    # Publica ~/Projects por SMB/CIFS a un solo usuario
│   └── drivers/              # Controladores por hardware (un script por placa)
│       ├── drivers-menu.sh   # Submenú: lista y lanza cada driver-*.sh
│       └── driver-nvidia-gtx1060.sh  # Repo NVIDIA + G06 + GRUB/modprobe
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
- `scripts/04-setup-dotfiles.sh` calcula en cada corrida qué archivos despliega
  `config/` y guarda ese inventario en `~/.local/state/dotfiles/desplegado.tsv`.
  La limpieza borra solo lo que el repo dejó de declarar: nunca hace `rm -rf`
  de directorios del usuario ni toca binarios propios, datos de apps o
  configuraciones ajenas. Detalle en [docs/aplicar-dotfiles.md](docs/aplicar-dotfiles.md).
- Los controladores de hardware viven en `scripts/drivers/`, un
  `driver-<vendor>-<modelo>.sh` autocontenido por placa. El submenú
  `drivers-menu.sh` los descubre solo, así que agregar una GPU nueva no
  requiere tocar `install.sh`. Los controladores NVIDIA se instalan desde el
  repositorio oficial de NVIDIA.
- Las Nerd Fonts se descargan por familia desde `ryanoasis/nerd-fonts`
  (GitHub Releases) y se instalan en `~/.local/share/fonts` sin sudo.
- El componente «Samba (share de Projects)» instala `samba` y
  `samba-client`, y `scripts/14-setup-samba.sh` escribe un `smb.conf`
  gestionado que publica `~/Projects` con lectura y escritura **sólo** al
  usuario que lo corre (`valid users`, `map to guest = Never`), habilita el
  servicio `smb` y abre el servicio `samba` en firewalld. La contraseña de
  Samba es un secreto del usuario y no se versiona: la define
  `sudo smbpasswd -a <usuario>` una sola vez. Un `smb.conf` ajeno no se pisa
  sin `--force`; `--check` es de sólo lectura. Detalle en
  [docs/samba.md](docs/samba.md).
- La shell por defecto se cambia a zsh (opcional durante la instalación).
- `config/home/.zshrc` también se **copia** a `$HOME`, no se enlaza: los cambios
  editados directamente en `~/.zshrc` se sobrescriben la próxima vez que se
  aplica `scripts/04-setup-dotfiles.sh`. Hay que editar siempre
  `config/home/.zshrc`.
- Los plugins de zsh (`zsh-autosuggestions` y `zsh-syntax-highlighting`) los
  instala `scripts/08-setup-zsh.sh` en
  `${XDG_DATA_HOME:-~/.local/share}/zsh/plugins`, sin sudo y con clones
  superficiales. `config/home/.zshrc` los carga comprobando que el archivo sea
  legible, de modo que la shell funciona igual aunque no estén instalados.
- El componente "Nvim" del instalador ejecuta `scripts/09-setup-nvim.sh` justo
  después de aplicar los dotfiles, porque necesita la configuración ya desplegada
  en `~/.config/nvim`. El script instala lazy.nvim y el set de plugins en
  `${XDG_DATA_HOME:-~/.local/share}/nvim`, sin sudo. Requiere `neovim` instalado
  (viene en "Dev Core", `packages/dev-core.txt`). La configuración declarativa
  vive en `config/nvim/` y la despliega `scripts/04-setup-dotfiles.sh`.
- **Aplicaciones Flatpak**: están en el menú principal del instalador
  (`Instalar aplicaciones Flatpak`) y como componente de la selección múltiple.
  El catálogo es `packages/flatpak-apps.txt` y las apps se eligen de a una; las
  ya instaladas se marcan `(instalada)` y no se reinstalan, y la "Instalación
  completa" instala el catálogo entero. `scripts/02b-install-flatpak.sh` acepta
  `--list`, `--apps A,B` y `--all` para uso no interactivo. Todo va a nivel de
  usuario (`--user`), sin `sudo`.
- El escritorio tiene **tema claro y oscuro** y se cambia desde el botón del
  centro de notificaciones o con `Super+Shift+t`. Cada app tiene un archivo
  nativo por tema y el archivo que lee es un enlace simbólico al tema activo; el
  estado vive en `~/.local/state/dotfiles/tema`. `04-setup-dotfiles.sh`
  re-aplica el tema elegido al final de cada corrida. Detalle en
  [docs/tema-claro-oscuro.md](docs/tema-claro-oscuro.md).
