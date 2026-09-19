# Sway - Arquitectura Personal de Workstation

## Filosofía

SwayDesk NO busca ser una plataforma multiusuario ni un sistema declarativo complejo.

El usuario siempre será una sola persona y el objetivo principal es:

- Mantener los dotfiles organizados.
- Facilitar el mantenimiento a largo plazo.
- Tener una experiencia moderna en Sway.
- Evitar complejidad innecesaria.
- Utilizar archivos reales en lugar de configuraciones generadas.

Principio fundamental:

> Tratar la configuración como código bien organizado, no como artefactos generados.

---

# Objetivos

## Técnicos

- openSUSE Tumbleweed.
- NVIDIA.
- Sway.
- Waybar.
- SwayNC.
- Walker.
- AGS (futuro).
- GNU Stow.

## Arquitectónicos

- Configuración modular.
- Separación por features.
- Recarga en caliente.
- Simplicidad.
- Git como fuente de verdad.

---

# Qué NO será SwayDesk

No habrá:

- Generadores de configuración.
- YAML como fuente principal.
- Compilación de configuraciones.
- Motores de templates.
- Capas de abstracción innecesarias.

Todas las configuraciones serán archivos nativos de las aplicaciones.

---

# Arquitectura General

```text
openSUSE
│
├── NVIDIA
├── Sway
├── Waybar
├── SwayNC
├── Walker
├── Foot
├── WezTerm
└── GNU Stow
        │
        ▼
   SwayDesk
        │
        ├── Dotfiles
        ├── Themes
        ├── Profiles
        ├── Scripts
        └── Dashboard
```

---

# Árbol Completo del Proyecto

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
│   ├── desktop-sway.txt
│   ├── shell.txt
│   ├── dev.txt
│   ├── nvidia.txt
│   └── fonts.txt
│
├── scripts/
│   ├── 00-check-system.sh
│   ├── 00-xdg-dirs.sh
│   ├── 01-install-gum.sh
│   ├── 02-install-packages.sh
│   ├── 03-nvidia-setup.sh
│   ├── 04-setup-dotfiles.sh
│   ├── 05-install-fonts.sh
│   ├── profile-devops.sh
│   ├── profile-llm.sh
│   ├── profile-gaming.sh
│   └── profile-presentation.sh
│
├── config/
│   ├── sway/
│   ├── waybar/
│   ├── foot/
│   ├── walker/
│   ├── swaync/
│   └── environment.d/
│
├── profiles/
├── themes/
└── assets/
```

---

# Organización de Sway

## Estructura

```text
.config/sway/
│
├── config
│
├── features/
│   ├── variables.conf
│   ├── monitors.conf
│   ├── inputs.conf
│   ├── appearance.conf
│   ├── autostart.conf
│   ├── workspaces.conf
│   ├── windows.conf
│   ├── notifications.conf
│   ├── screenshots.conf
│   ├── clipboard.conf
│   └── power.conf
│
├── keybindings/
│   ├── applications.conf
│   ├── navigation.conf
│   ├── workspaces.conf
│   ├── media.conf
│   ├── system.conf
│   └── swaydesk.conf
│
├── hosts/
│   ├── desktop.conf
│   ├── laptop.conf
│   └── dock.conf
│
└── modes/
    ├── resize.conf
    └── launcher.conf
```

---

# Config Principal de Sway

El archivo principal únicamente importa módulos.

```text
config
│
├── variables
├── hardware
├── apariencia
├── ventanas
├── inicio
├── utilidades
└── keybindings
```

Ventajas:

- Fácil mantenimiento.
- Archivos pequeños.
- Navegación rápida.
- Recarga inmediata.

---

# Recarga en Caliente

Se modifican directamente los archivos:

```bash
~/.config/sway/features/appearance.conf
```

Posteriormente:

```bash
swaymsg reload
```

No existe generación previa.

No existe compilación.

No existe paso intermedio.

---

# Organización de Waybar

```text
.config/waybar/
│
├── config.jsonc
│
├── modules/
│   ├── cpu.jsonc
│   ├── memory.jsonc
│   ├── gpu.jsonc
│   ├── docker.jsonc
│   ├── weather.jsonc
│   ├── clock.jsonc
│   └── notifications.jsonc
│
└── styles/
    ├── colors.css
    ├── widgets.css
    ├── workspaces.css
    └── notifications.css
```

---

# Perfiles

Los perfiles no generan configuración.

Simplemente activan o desactivan elementos específicos.

```text
profiles/
├── developer
├── devops
├── llm
├── gaming
└── presentation
```

Ejemplos:

- Developer
- DevOps
- LLM Local
- Gaming
- Presentaciones

---

# Dashboard Futuro

Basado en AGS.

Atajos sugeridos:

```text
SUPER + A
```

Dashboard.

```text
SUPER + N
```

Centro de notificaciones.

```text
SUPER + C
```

Control Center.

```text
SUPER + D
```

Walker Launcher.

---

# Explorador de Archivos

Recomendación principal:

```text
Yazi
```

Apoyo gráfico:

```text
Thunar
```

Atajo sugerido:

```text
SUPER + E
```

---

# Roadmap Técnico

## Fase 1

Instalador.

- openSUSE
- NVIDIA
- Sway
- Stow

## Fase 2

Experiencia moderna.

- Waybar
- SwayNC
- Walker
- SwayOSD
- Swww

## Fase 3

Modularización completa.

- Features
- Keybindings
- Modes
- Hosts

## Fase 4

Dashboard AGS.

- Calendario
- Estado sistema
- Acciones rápidas

## Fase 5

Perfiles.

- Developer
- DevOps
- LLM
- Gaming
- Presentation

## Fase 6

Centro de control.

- Temas
- Notificaciones
- Widgets
- Atajos

---

# Conclusión

SwayDesk es un entorno personal basado en archivos de configuración reales, organizados por responsabilidad y mantenidos mediante Stow. La prioridad es la simplicidad, la claridad y la mantenibilidad a largo plazo, evitando sistemas de generación o capas de abstracción que no aporten valor para un único usuario.

