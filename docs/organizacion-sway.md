# Organización Modular de la Configuración Sway para OpenDesk

## 1. Propósito

Este documento define la arquitectura modular para la configuración de Sway dentro del proyecto OpenDesk. El objetivo es garantizar mantenibilidad a largo plazo mediante una estructura de archivos basada en features, perfiles y hosts, tratando la configuración del compositor como código fuente que debe ser versionado, probado y generado de forma declarativa.

La propuesta se basa en los siguientes principios:

- **Separación por dominio**: cada aspecto de la configuración (hardware, atajos, reglas de ventana, etc.) reside en un archivo independiente.
- **Extensibilidad**: la adición de nuevos dispositivos, perfiles o funcionalidades no requiere modificar archivos existentes.
- **Generación declarativa**: la configuración final se genera desde una fuente de verdad única (profiles/, themes/, widgets/ y settings.yml), eliminando la edición manual directa.
- **Reproducibilidad**: el mismo conjunto de archivos produce siempre el mismo estado del compositor.

---

## 2. Estructura del Repositorio

La estructura propuesta para `config/sway/.config/sway/` es la siguiente:

```
config/sway/
└── .config/sway/
    ├── config
    │
    ├── features/
    │   ├── monitors.conf
    │   ├── inputs.conf
    │   ├── variables.conf
    │   ├── autostart.conf
    │   ├── keybindings.conf
    │   ├── workspaces.conf
    │   ├── window-rules.conf
    │   ├── appearance.conf
    │   ├── screenshots.conf
    │   ├── clipboard.conf
    │   ├── notifications.conf
    │   └── power.conf
    │
    ├── modes/
    │   ├── resize.conf
    │   ├── launcher.conf
    │   └── presentation.conf
    │
    ├── hosts/
    │   ├── desktop.conf
    │   ├── laptop.conf
    │   └── vm.conf
    │
    └── profiles/
        ├── developer.conf
        ├── devops.conf
        ├── llm.conf
        └── gaming.conf
```

---

## 3. Configuración Principal

El archivo `config` funciona como bootstrap. Su único propósito es cargar los módulos en el orden correcto. No contiene lógica de configuración directa; solo instrucciones de inclusión.

```sway
# Variables globales
include ~/.config/sway/features/variables.conf

# Hardware
include ~/.config/sway/features/monitors.conf
include ~/.config/sway/features/inputs.conf

# Apariencia
include ~/.config/sway/features/appearance.conf

# Ventanas
include ~/.config/sway/features/window-rules.conf
include ~/.config/sway/features/workspaces.conf

# Inicio
include ~/.config/sway/features/autostart.conf

# Funciones
include ~/.config/sway/features/screenshots.conf
include ~/.config/sway/features/clipboard.conf
include ~/.config/sway/features/notifications.conf
include ~/.config/sway/features/power.conf

# Atajos
include ~/.config/sway/features/keybindings.conf
```

El orden de inclusión es significativo. Las variables se cargan primero porque son consumidas por todos los módulos posteriores.

---

## 4. Módulos de Features

### 4.1. Variables (`features/variables.conf`)

Define los alias y valores por defecto que el resto de la configuración consume. Modificar este archivo es la única forma de cambiar el terminal, navegador o editor predeterminado.

```sway
set $mod Mod4

set $terminal wezterm
set $browser firefox
set $menu walker

set $filemanager thunar
set $editor nvim
```

### 4.2. Monitores (`features/monitors.conf`)

Contiene la configuración de salidas de video. Se mantiene separado porque es el archivo que más varía entre hosts (desktop, laptop, VM).

```sway
output DP-1 resolution 2560x1440 position 0 0
output HDMI-A-1 resolution 1920x1080 position 2560 0
```

### 4.3. Entradas (`features/inputs.conf`)

Configura teclados, touchpads y otros dispositivos de entrada.

```sway
input type:keyboard {
    xkb_layout latam
    xkb_variant
}

input type:touchpad {
    tap enabled
    natural_scroll enabled
}
```

### 4.4. Apariencia (`features/appearance.conf`)

Define la estética visual del compositor: bordes, gaps y tipografía.

```sway
default_border pixel 2

gaps inner 8
gaps outer 4

font pango:JetBrainsMono Nerd Font 10
```

### 4.5. Workspaces (`features/workspaces.conf`)

Mapea espacios de trabajo a monitores específicos. Crítico en configuraciones multi-monitor.

```sway
workspace 1 output DP-1
workspace 2 output DP-1
workspace 3 output DP-1

workspace 8 output HDMI-A-1
workspace 9 output HDMI-A-1
workspace 10 output HDMI-A-1
```

### 4.6. Reglas de Ventana (`features/window-rules.conf`)

Define comportamientos específicos por aplicación o título de ventana.

```sway
for_window [app_id="pavucontrol"] floating enable
for_window [app_id="blueman-manager"] floating enable
for_window [title="OpenDesk Dashboard"] floating enable
```

### 4.7. Autostart (`features/autostart.conf`)

Lista de servicios y procesos que se ejecutan al iniciar la sesión de Sway. Es una de las secciones con mayor tasa de crecimiento.

```sway
exec swaync
exec waybar
exec swww-daemon
exec nm-applet
exec cliphist store
```

### 4.8. Capturas (`features/screenshots.conf`)

Atajos de teclado para la captura de pantalla mediante `grim` y `slurp`.

```sway
bindsym Print exec grim ~/Pictures/screenshot.png
bindsym Shift+Print exec grim -g "$(slurp)"
```

### 4.9. Notificaciones (`features/notifications.conf`)

Atajos para la interacción con el daemon de notificaciones SwayNC.

```sway
bindsym $mod+n exec swaync-client -t
```

### 4.10. Energía (`features/power.conf`)

Atajos para el menú de energía del sistema.

```sway
bindsym $mod+Shift+e exec wlogout
```

---

## 5. Subdivisión de Keybindings

Para mantener el archivo principal limpio, los keybindings se subdividen en un directorio propio:

```
features/keybindings/
├── navigation.conf
├── applications.conf
├── workspaces.conf
├── media.conf
├── screenshots.conf
├── opendesk.conf
└── modes.conf
```

El archivo principal los carga mediante:

```sway
include ~/.config/sway/features/keybindings/*.conf
```

---

## 6. Integración con OpenDesk

El módulo `opendesk.conf` dentro de `keybindings/` define los atajos exclusivos del proyecto. Sway actúa únicamente como disparador de acciones; la lógica reside en OpenDesk.

```sway
bindsym $mod+a exec opendesk dashboard
bindsym $mod+c exec opendesk control-center
bindsym $mod+p exec opendesk projects
bindsym $mod+o exec opendesk launcher
bindsym $mod+comma exec opendesk settings
```

---

## 7. Perfiles de Trabajo

Los perfiles permiten activar conjuntos de configuración específicos por caso de uso. Cada perfil se carga mediante inclusión directa:

```
profiles/
├── developer.conf
├── devops.conf
├── llm.conf
└── presentation.conf
```

Ejemplo de contenido por perfil:

**DevOps** (`profiles/devops.conf`):
```sway
bindsym $mod+d exec lazydocker
bindsym $mod+k exec kubectl
```

**LLM** (`profiles/llm.conf`):
```sway
bindsym $mod+l exec opendesk ollama
```

---

## 8. Hosts

Los archivos de host permiten aplicar configuraciones específicas al hardware donde se ejecuta Sway. Se incluyen condicionalmente según el dispositivo detectado.

```
hosts/
├── desktop.conf
├── laptop.conf
└── vm.conf
```

---

## 9. Estrategia de Generación

La configuración final no debe ser editada manualmente. Los archivos `.conf` se generan automáticamente desde la configuración declarativa de OpenDesk:

| Fuente declarativa | Artefacto generado |
|---------------------|---------------------|
| `profiles/*.yml` | `sway/profiles/*.conf` |
| `themes/` | `sway/features/appearance.conf` |
| `widgets/` | `sway/features/autostart.conf` |
| `settings.yml` | `sway/features/variables.conf` |

Este patrón es análogo a un compilador que genera código binario a partir de una fuente de verdad única. La configuración resultante es limpia, reproducible y mantenible a largo plazo.

