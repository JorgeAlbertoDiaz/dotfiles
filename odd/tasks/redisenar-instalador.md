# Rediseñar install.sh como entrada de instalación

## Objetivo

Convertir `install.sh` en la entrada de configuración de una nueva instalación, con un menú principal que permita: instalación completa, selección de componentes (separando obligatorio de accesorio), conexión WiFi y configuración de red (IP estática/DHCP).

## Problema

El menú actual volvió a una versión descartada. `install.sh` mezcla la selección de componentes con opciones de teclado/red que nunca se implementaron, y `dev.txt` mezcla todos los stacks de desarrollo en un solo archivo sin granularidad.

## Por qué

El usuario quiere una instalación reproducible y granular: obligatorio (base + shell) siempre automático, y lo accesorio (Sway, fuentes, NVIDIA, stacks de desarrollo) elegible por separado. También necesita gestión de red (WiFi y estática/DHCP) desde el mismo script.

## Scope

- Rediseñar el menú principal de `install.sh`.
- Base + shell siempre automáticos al seleccionar componentes.
- Sway instala todo lo necesario (waybar, wofi, fzf, fuentes, etc.).
- Conexión WiFi simple desde el menú principal (nmcli).
- Configuración de red (IP estática/máscara/gateway o DHCP) desde el menú principal (nmcli).
- Nerd Fonts: obligatorias para Sway y para Neovim (Dev Core).
- Dividir `packages/dev.txt` en stacks: PHP, Rust, Python, Dev Core, Angular/Node — mantener Go fuera (no seleccionado).

## Constraints

- openSUSE Tumbleweed, zypper.
- gum como TUI con fallback bash.
- Scripts en `scripts/` modulares e idempotentes.
- Convención de commits en español.

## Tareas

- [x] T1: Dividir packages — crear dev-core.txt, dev-php.txt, dev-rust.txt, dev-python.txt, dev-angular.txt (mantener Go fuera); actualizar/remover dev.txt
- [x] T2: Crear scripts/06-network-wifi.sh — conexión WiFi con nmcli (escaneo, selección SSID, contraseña)
- [x] T3: Crear scripts/07-network-config.sh — configurar IP estática (IP/máscara/gateway/DNS) o DHCP con nmcli
- [x] T4: Reescribir install.sh — menú principal (Instalar todo / Seleccionar componentes / WiFi / Red / Salir), obligatorios automáticos, dependencias de Sway y fuentes, orquestar scripts de red
- [x] T5: Verificación — bash -n OK en install.sh + 06 + 07 + 05; staging separado (WIP base.txt/shell.txt fuera)

## Progreso

- T1-T4 implementados por writer delegado; T5 verificado por el orquestador (bash -n OK, spot-check de parsing --family, stage limpio).
- Comentario de desviación del writer: `--family` se agregó a 05-install-fonts.sh; Git rm de dev.txt rechazado por WIP local → rm + add -A. Pendientes: actualizar README.md y docs/index.md (referencias a dev.txt).

## Autorización

Solo esta feature. No tocar configuraciones de sway ni otros componentes.