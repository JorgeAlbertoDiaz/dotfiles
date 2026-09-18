#!/usr/bin/env bash
#
# install.sh — instalador de dotfiles para openSUSE Tumbleweed.
#
# Flujo:
#   1. Verifica que el sistema es openSUSE Tumbleweed.
#   2. Verifica y crea los directorios base XDG y de descargas.
#   3. Verifica (e instala si falta) gum para la interfaz TUI.
#   4. Muestra un menú principal en bucle:
#      - Instalación completa (todos los componentes)
#      - Seleccionar componentes (multi-selección)
#      - Conectar a red WiFi (scripts/06-network-wifi.sh)
#      - Configurar red — estática/DHCP (scripts/07-network-config.sh)
#      - Salir
#   5. Instala los componentes obligatorios (base, shell) y los opcionales
#      elegidos, ejecutando los scripts correspondientes en el orden correcto.
#
# Si gum no puede instalarse, usa un flujo bash simple como fallback.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/common.sh"

REPO_DIR="${SCRIPT_DIR}"

# Componentes opcionales (las obligatorios: base, shell — siempre se instalan).
COMPONENTES=(
  "Escritorio Sway"
  "Nerd Fonts"
  "NVIDIA"
  "Dev Core"
  "Dev PHP"
  "Dev Rust"
  "Dev Python"
  "Dev Angular/Node"
  "Dotfiles"
)

# ---------------------------------------------------------------------------
# 1) Verificación de sistema y directorios base
# ---------------------------------------------------------------------------
"${SCRIPT_DIR}/scripts/00-check-system.sh"
"${SCRIPT_DIR}/scripts/00-xdg-dirs.sh"

# ---------------------------------------------------------------------------
# 2) Verificar/instalar gum
# ---------------------------------------------------------------------------
"${SCRIPT_DIR}/scripts/01-install-gum.sh"

# ---------------------------------------------------------------------------
# Ejecuta un componente dado su nombre legible.
# ---------------------------------------------------------------------------
run_component() {
  local item="$1"
  info "Procesando componente: ${item}"

  case "${item}" in
    base|shell)
      "${SCRIPT_DIR}/scripts/02-install-packages.sh" "${item}.txt"
      info "Finalizado: ${item}"
      ;;
    "Escritorio Sway")
      "${SCRIPT_DIR}/scripts/02-install-packages.sh" desktop-sway.txt
      info "Finalizado: Escritorio Sway"
      ;;
    "NVIDIA")
      "${SCRIPT_DIR}/scripts/03-nvidia-setup.sh"
      info "Finalizado: configuración NVIDIA"
      ;;
    "Nerd Fonts")
      "${SCRIPT_DIR}/scripts/05-install-fonts.sh" --install-only
      info "Finalizado: instalación de fuentes"
      ;;
    "Dev Core")
      "${SCRIPT_DIR}/scripts/02-install-packages.sh" dev-core.txt
      info "Finalizado: Dev Core"
      ;;
    "Dev PHP")
      "${SCRIPT_DIR}/scripts/02-install-packages.sh" dev-php.txt
      info "Finalizado: Dev PHP"
      ;;
    "Dev Rust")
      "${SCRIPT_DIR}/scripts/02-install-packages.sh" dev-rust.txt
      info "Finalizado: Dev Rust"
      ;;
    "Dev Python")
      "${SCRIPT_DIR}/scripts/02-install-packages.sh" dev-python.txt
      info "Finalizado: Dev Python"
      ;;
    "Dev Angular/Node")
      "${SCRIPT_DIR}/scripts/02-install-packages.sh" dev-angular.txt
      if confirm "¿Instalar también el CLI de Angular globalmente (npm install -g @angular/cli)?"; then
        as_root npm install -g @angular/cli
        ok "Angular CLI instalado globalmente"
      else
        warn "Omitiendo la instalación del Angular CLI"
      fi
      info "Finalizado: Dev Angular/Node"
      ;;
    "Dotfiles")
      "${SCRIPT_DIR}/scripts/04-setup-dotfiles.sh"
      info "Finalizado: aplicación de dotfiles"
      ;;
    *)
      warn "Componente desconocido: ${item}"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 3) Menú principal en bucle
#     Las opciones 3 y 4 ejecutan su script y vuelven al menú.
# ---------------------------------------------------------------------------
while true; do
  if command -v gum &>/dev/null; then
    OPCIONES_MENU=(
      "Instalación completa (todo)"
      "Seleccionar componentes"
      "Conectar a red WiFi"
      "Configurar red (estática/DHCP)"
      "Salir"
    )
    if ! opcion_main="$(gum choose --height 6 "${OPCIONES_MENU[@]}")"; then
      warn "Ninguna opción seleccionada."
      exit 1
    fi
  else
    info "gum no está disponible; usando flujo bash simple."
    PS3="> "
    select opcion_main in \
      "Instalación completa (todo)" \
      "Seleccionar componentes" \
      "Conectar a red WiFi" \
      "Configurar red (estática/DHCP)" \
      "Salir"; do
      [[ -n "${opcion_main}" ]] && break
      warn "Opción inválida, intente de nuevo."
    done
  fi

  case "${opcion_main}" in
    "Instalación completa (todo)")
      info "Instalación completa seleccionada."
      break
      ;;
    "Seleccionar componentes")
      info "Selección de componentes."
      break
      ;;
    "Conectar a red WiFi")
      "${SCRIPT_DIR}/scripts/06-network-wifi.sh"
      continue
      ;;
    "Configurar red (estática/DHCP)")
      "${SCRIPT_DIR}/scripts/07-network-config.sh"
      continue
      ;;
    "Salir")
      ok "Instalación cancelada."
      exit 0
      ;;
    *)
      warn "Opción no reconocida."
      ;;
  esac
done

# ---------------------------------------------------------------------------
# 4) Selección de componentes opcionales
# ---------------------------------------------------------------------------
sel=()
if [[ "${opcion_main}" == "Instalación completa (todo)" ]]; then
  sel=("${COMPONENTES[@]}")
  info "Componentes seleccionados: ${sel[*]}"
else
  if command -v gum &>/dev/null; then
    if ! seleccion="$(gum choose --no-limit --height 12 \
        --header "Selecciona los componentes a instalar (Espacio=seleccionar, Enter=continuar):" \
        "${COMPONENTES[@]}")"; then
      warn "No se seleccionó ningún componente."
      exit 1
    fi
    mapfile -t sel <<< "${seleccion}"
    if [[ ${#sel[@]} -eq 0 ]]; then
      warn "No se seleccionó ningún componente."
      exit 1
    fi
    if ! gum confirm --default=true "¿Confirmas la instalación de estos componentes?"; then
      warn "Instalación cancelada por el usuario."
      exit 1
    fi
  else
    info "Modo sin gum: selecciona componentes con s/N."
    for c in "${COMPONENTES[@]}"; do
      if confirm "¿Instalar ${c}?"; then
        sel+=("${c}")
      fi
    done
    if [[ ${#sel[@]} -eq 0 ]]; then
      warn "No se seleccionó ningún componente."
      exit 1
    fi
    if ! confirm "¿Confirmas la instalación de estos componentes?"; then
      warn "Instalación cancelada por el usuario."
      exit 1
    fi
  fi

  info "Componentes seleccionados:"
  for s in "${sel[@]}"; do printf '  - %s\n' "${s}"; done
fi

# ---------------------------------------------------------------------------
# 5) Dependencia automática de Nerd Fonts
#     Si se eligió "Escritorio Sway" o "Dev Core" (neovim) pero NO
#     "Nerd Fonts" explícitamente, se instala JetBrainsMono automáticamente.
#     Se ejecuta ANTES de "Dotfiles" para que stow enlace la config con
#     la fuente ya instalada.
# ---------------------------------------------------------------------------
FONT_EXPLICITA=0
FONT_AUTO=0
if [[ " ${sel[*]} " == *" Nerd Fonts "* ]]; then
  FONT_EXPLICITA=1
elif [[ " ${sel[*]} " == *" Escritorio Sway "* || " ${sel[*]} " == *" Dev Core "* ]]; then
  FONT_AUTO=1
fi

# Reordenar: las fuentes antes de dotfiles, dotfiles al final
if [[ " ${sel[*]} " == *" Dotfiles "* ]]; then
  ordered=()
  for item in "${sel[@]}"; do
    [[ "${item}" == "Dotfiles" ]] && continue
    ordered+=("${item}")
  done
  ordered+=("Dotfiles")
  sel=("${ordered[@]}")
fi

# ---------------------------------------------------------------------------
# 6) Instalación
# ---------------------------------------------------------------------------

# Obligatorios
info "Instalando componentes obligatorios (base, shell)..."
run_component base
run_component shell

# Fuentes automáticas: se ejecutan cuando no se eligieron explícitamente
FONT_AUTO_DONE=0
run_fonts_auto() {
  if [[ ${FONT_AUTO_DONE} -eq 1 ]]; then
    return
  fi
  info "Instalando automáticamente JetBrainsMono Nerd Font (dependencia de Sway/Dev Core)..."
  "${SCRIPT_DIR}/scripts/05-install-fonts.sh" --install-only --family JetBrainsMono
  FONT_AUTO_DONE=1
}

# Opcionales en orden
for item in "${sel[@]}"; do
  # Inyectar fuentes automáticas justo antes de dotfiles
  if [[ "${item}" == "Dotfiles" && ${FONT_AUTO} -eq 1 && ${FONT_AUTO_DONE} -eq 0 ]]; then
    run_fonts_auto
  fi
  run_component "${item}"
done

# Si dotfiles no estaba en la lista pero hay fuentes automáticas pendientes
if [[ ${FONT_AUTO} -eq 1 && ${FONT_AUTO_DONE} -eq 0 ]]; then
  run_fonts_auto
fi

# ---------------------------------------------------------------------------
# 7) Conclusión
# ---------------------------------------------------------------------------
ok "¡Instalación completada! Resumen:"
printf '  - Obligatorios: base, shell\n'
for item in "${sel[@]}"; do printf '  - %s\n' "${item}"; done
if [[ ${FONT_AUTO} -eq 1 && ${FONT_EXPLICITA} -eq 0 ]]; then
  printf '  - Nerd Fonts automáticas (JetBrainsMono)\n'
fi
ok "Reinicia la sesión o el sistema según sea necesario."