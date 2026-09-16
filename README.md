# dotfiles

Dotfiles y script de instalación para un sistema funcional sobre **openSUSE Tumbleweed** partiendo de una instalación limpia.

## Objetivo

No solo guardar configuraciones, sino proveer una forma automatizada de instalar todo lo necesario para tener un entorno de trabajo completo: controladores, paquetes, fuentes, configuraciones de shell, terminal, editor, etc.

## Requisitos

- **Sistema operativo:** openSUSE Tumbleweed (instalación limpia o reciente)
- **GPU:** NVIDIA GeForce GTX 1060 3 GB (se instalan los controladores propietarios nvidia)

## Estructura del repositorio

```
.
├── README.md
├── install.sh          # Script principal de instalación
├── packages.txt        # Lista de paquetes zypper a instalar
└── config/             # Dotfiles (copiados al $HOME)
    ├── .bashrc
    ├── .zshrc
    ├── nvim/
    └── ...
```

> La estructura es flexible; se ajustará a medida que se añadan configuraciones.

## Uso

```bash
git clone https://github.com/JorgeAlbertoDiaz/dotfiles.git ~/dotfiles
cd ~/dotfiles
chmod +x install.sh
./install.sh
```

## Qué instala `install.sh`

| Categoría | Detalle |
|---|---|
| **NVIDIA** | Controladores propietarios vía repositorio oficial de NVIDIA para Tumbleweed |
| **Paquetes base** | Herramientas esenciales de sistema y desarrollo |
| **Shell** | Configuración de zsh / bash |
| **Terminal** | Emulador de terminal y fuentes |
| **Editor** | Neovim u otro editor (según preferencia) |
| **Dotfiles** | Symlinks o copia de configuraciones al `$HOME` |

## Notas

- El script está pensado para ejecutarse en una instalación reciente de Tumbleweed.
- Se asume conexión a internet durante la instalación.
- Los controladores NVIDIA se configuran para la GTX 1060 3 GB; si se cambia de GPU, revisar la compatibilidad con `zypper se -i | grep nvidia`.
