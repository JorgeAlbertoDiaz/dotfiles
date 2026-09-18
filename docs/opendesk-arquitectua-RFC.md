# OpenDesk Architecture RFC

## Visión General

OpenDesk es la evolución de un repositorio tradicional de dotfiles hacia una plataforma completa de provisión, personalización, automatización y operación de estaciones de trabajo Linux basadas en Wayland.

Objetivos:

- Instalación reproducible de openSUSE Tumbleweed.
- Configuración declarativa.
- Workstation as Code.
- Separación entre plataforma, compositor, widgets y experiencia de usuario.
- Portabilidad futura entre Sway, Hyprland, Niri y otros compositores.
- Gestión centralizada mediante CLI y TUI.

---

# Arquitectura de Alto Nivel

```text
┌───────────────────────────────────────┐
│ OpenDesk                              │
├───────────────────────────────────────┤
│ CLI / TUI                             │
├───────────────────────────────────────┤
│ Profiles │ Themes │ Widgets │ Modules │
├───────────────────────────────────────┤
│ OpenDesk Core                         │
├───────────────────────────────────────┤
│ Adapters                              │
├───────────────┬───────────────────────┤
│ Sway          │ Hyprland │ Niri │ ... │
└───────────────┴───────────────────────┘
```

---

# Árbol Completo del Repositorio

```text
dotfiles/
│
├── install.sh
│
├── docs/
│   ├── architecture.md
│   ├── roadmap.md
│   ├── decisions/
│   ├── diagrams/
│   └── assets/
│
├── packages/
│   ├── base.txt
│   ├── shell.txt
│   ├── dev.txt
│   ├── desktop-sway.txt
│   ├── nvidia.txt
│   ├── fonts.txt
│   ├── opendesk-core.txt
│   ├── opendesk-ui.txt
│   └── opendesk-widgets.txt
│
├── scripts/
│   ├── 00-check-system.sh
│   ├── 00-xdg-dirs.sh
│   ├── 01-install-gum.sh
│   ├── 02-install-packages.sh
│   ├── 03-nvidia-setup.sh
│   ├── 04-setup-dotfiles.sh
│   ├── 05-install-fonts.sh
│   ├── 06-install-opendesk.sh
│   ├── 07-generate-configs.sh
│   ├── 08-apply-profile.sh
│   └── lib/
│
├── config/
│   ├── home/
│   ├── sway/
│   ├── waybar/
│   ├── swaync/
│   ├── ags/
│   ├── foot/
│   ├── walker/
│   └── environment.d/
│
├── adapters/
│   ├── sway/
│   │   ├── generator.sh
│   │   ├── keymaps/
│   │   └── templates/
│   ├── hyprland/
│   ├── niri/
│   └── river/
│
├── modules/
│   ├── system/
│   ├── notifications/
│   ├── calendar/
│   ├── weather/
│   ├── docker/
│   ├── kubernetes/
│   ├── ollama/
│   ├── backup/
│   ├── vpn/
│   ├── media/
│   ├── power/
│   └── github/
│
├── widgets/
│   ├── cpu/
│   ├── ram/
│   ├── gpu/
│   ├── ollama/
│   ├── notifications/
│   ├── calendar/
│   ├── weather/
│   └── quick-actions/
│
├── profiles/
│   ├── developer.yml
│   ├── devops.yml
│   ├── llm.yml
│   ├── gaming.yml
│   └── presentation.yml
│
├── themes/
│   ├── catppuccin/
│   ├── gruvbox/
│   ├── nord/
│   ├── dracula/
│   └── custom/
│
└── opendesk/
    ├── cli/
    ├── tui/
    ├── generators/
    ├── diagnostics/
    ├── services/
    └── core/
```

---

# Componentes Estratégicos

## OpenDesk Core

Responsable de:

- Gestión de configuración declarativa.
- Carga de perfiles.
- Carga de temas.
- Resolución de dependencias.
- Generación de configuraciones.
- Descubrimiento de módulos.

## Adapters

Permiten desacoplar OpenDesk del compositor.

Ejemplo:

```bash
opendesk wm sway
```

Genera:

```text
~/.config/sway/config
```

Mientras:

```bash
opendesk wm hyprland
```

Genera:

```text
~/.config/hypr/hyprland.conf
```

## Modules

Contienen lógica reutilizable.

Ejemplo:

```text
modules/ollama
├── status.sh
├── models.sh
├── start.sh
└── stop.sh
```

## Widgets

Representación visual de los módulos.

Un mismo módulo puede aparecer en:

- Waybar
- Dashboard AGS
- TUI
- Notification Center

---

# Interfaz del Usuario

## Launcher

SUPER+D

Walker como lanzador principal.

## Dashboard

SUPER+A

Contendrá:

- Calendario
- CPU
- RAM
- GPU
- Ollama
- Docker
- Acciones rápidas
- Estado VPN

## Notification Center

SUPER+N

Basado en SwayNC.

## Control Center

SUPER+C

Panel rápido inspirado en KDE y GNOME.

## OpenDesk TUI

```text
Profiles
Themes
Widgets
Services
Diagnostics
Updates
WM Adapter
Keybindings
```

---

# Roadmap Técnico

## Fase 0 - Fundación

Duración estimada: 1 semana

Objetivos:

- Normalizar estructura actual.
- Consolidar scripts.
- Modularizar paquetes.
- Publicar documentación.

Entregables:

- Repositorio organizado.
- Diagramas actualizados.
- Convenciones de nomenclatura.

---

## Fase 1 - Base Sway Moderna

Duración estimada: 1-2 semanas

Componentes:

- Sway
- Waybar
- SwayNC
- Walker
- SwayOSD
- Foot
- WezTerm
- wl-clipboard
- cliphist
- grim
- slurp
- swww

Objetivo:

Tener una workstation completa lista para producción.

---

## Fase 2 - OpenDesk Core

Duración estimada: 2 semanas

Implementar:

- CLI principal.
- Cargador de perfiles.
- Motor de configuración.
- Sistema de templates.

Comandos:

```bash
opendesk doctor
opendesk update
opendesk profile
opendesk theme
```

---

## Fase 3 - Dashboard

Duración estimada: 2-3 semanas

Tecnologías:

- AGS
- GTK4
- TypeScript

Funciones:

- Calendario.
- Estado sistema.
- Quick actions.
- Integración Ollama.
- Integración Docker.

---

## Fase 4 - Sistema de Widgets

Duración estimada: 3 semanas

Características:

- Registro automático.
- Widgets desacoplados.
- Hot reload.
- Configuración declarativa.

---

## Fase 5 - Perfiles

Duración estimada: 1 semana

Perfiles iniciales:

- Developer
- DevOps
- LLM
- Gaming
- Presentation

---

## Fase 6 - TUI

Duración estimada: 3 semanas

Stack sugerido:

- Rust + Ratatui

Funciones:

- Theme manager.
- Widget manager.
- Diagnostics.
- Logs.
- Gestión de perfiles.

---

## Fase 7 - Adaptadores Multi-WM

Duración estimada: 4 semanas

Objetivo:

Separar OpenDesk completamente de Sway.

Soporte:

- Sway
- Hyprland
- Niri
- River

---

## Fase 8 - Plataforma Completa

Duración estimada: continua

Capacidades futuras:

- Plugins.
- Marketplace de widgets.
- Sincronización entre equipos.
- Exportación/importación de configuraciones.
- Workstation as Code.

---

# Visión Final

OpenDesk se convierte en una plataforma personal compuesta por:

- Instalador.
- Gestor de dotfiles.
- Motor de configuración.
- Framework de widgets.
- Dashboard.
- Sistema de perfiles.
- TUI administrativa.
- Adaptadores para múltiples compositores.

Sway pasa a ser solamente una implementación inicial, mientras que la experiencia completa del usuario permanece independiente y reutilizable.
