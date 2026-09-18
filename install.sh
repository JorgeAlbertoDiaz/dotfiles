#!/usr/bin/env bash
#
# install.sh — instalador de dotfiles para openSUSE Tumbleweed.
#
# Flujo:
#   1. Verifica que el sistema es openSUSE Tumbleweed.
#   2. Verifica y crea los directorios base XDG y de descargas.
#   3. Verifica (e instala si falta) gum para la interfaz TUI.
#   4. Muestra un menú interactivo para elegir componentes.
#   5. Ejecuta los scripts correspondientes.
#
# Si gum no puede instalarse, usa un flujo bash simple como fallback.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/common.sh"

REPO_DIR="${SCRIPT_DIR}"

# ---------------------------------------------------------------------------
# 1) Verificación de sistema y directorios base
# ---------------------------------------------------------------------------
"${SCRIPT_DIR}/scripts/00-check-system.sh"
"${SCRIPT_DIR}/scripts/00-xdg-dirs.sh"

# ---------------------------------------------------------------------------
# 2) Verificar/instalar gum
# ---------------------------------------------------------------------------
"${SCRIPT_DIR}/scripts/01-install-gum.sh"

# Componentes disponibles (grupo -> archivo/script)
COMPONENTES=(
  base
  desktop-sway
  shell
  dev
  nvidia
  fonts
  dotfiles
)

run_component() {
  local item="$1"
  info "Procesando componente: ${item}"
  
  case "${item}" in
    base|desktop-sway|shell|dev)
      "${SCRIPT_DIR}/scripts/02-install-packages.sh" "${item}.txt"
      # Mostrar resumen después de instalar paquetes
      info "Finalizado: ${item}"
      ;;
    nvidia)
      "${SCRIPT_DIR}/scripts/03-nvidia-setup.sh"
      info "Finalizado: configuración NVIDIA"
      ;;
    fonts)
      "${SCRIPT_DIR}/scripts/05-install-fonts.sh"
      info "Finalizado: configuración de fuentes"
      ;;
    dotfiles)
      "${SCRIPT_DIR}/scripts/04-setup-dotfiles.sh"
      info "Finalizado: aplicación de dotfiles"
      ;;
    *)
      warn "Componente desconocido: ${item}"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# 3) Menú interactivo (gum)
# ---------------------------------------------------------------------------
select_gum() {
  local selected
  if ! selected="$(gum choose --no-limit --height 12 \
      --header "Selecciona los componentes a instalar (Espacio=seleccionar, Enter=continuar):" \
      "${COMPONENTES[@]}")"; then
    warn "No se seleccionó ningún componente."
    return 1
  fi

  mapfile -t sel <<< "${selected}"

  if [[ ${#sel[@]} -eq 0 ]]; then
    warn "No se seleccionó ningún componente."
    return 1
  fi

  info "Componentes seleccionados:"
  for s in "${sel[@]}"; do printf '  - %s\n' "${s}"; done

  if ! gum confirm --default=true "¿Confirmas la instalación de estos componentes?"; then
    warn "Instalación cancelada por el usuario."
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# 3b) Fallback sin gum
# ---------------------------------------------------------------------------
select_fallback() {
  sel=()
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
  info "Componentes seleccionados: ${sel[*]}"
  if ! confirm "¿Confirmas la instalación de estos componentes?"; then
    warn "Instalación cancelada por el usuario."
    exit 1
  fi
}

# ---------------------------------------------------------------------------
# 4) Ejecución
# ---------------------------------------------------------------------------
if command -v gum &>/dev/null; then
  if ! select_gum; then
    exit 1
  fi
else
  warn "gum no está disponible; usando flujo bash simple."
  select_fallback
fi

# Si se eligieron fonts y dotfiles, se procesan fonts primero para que la
# config enlazada por stow ya traiga la fuente seleccionada.
if [[ " ${sel[*]} " == *" dotfiles "* && " ${sel[*]} " == *" fonts "* ]]; then
  ordered=()
  for item in "${sel[@]}"; do
    [[ "${item}" == "dotfiles" ]] && continue
    ordered+=("${item}")
  done
  ordered+=("dotfiles")
  sel=("${ordered[@]}")
fi

for item in "${sel[@]}"; do
  run_component "${item}"
done

ok "¡Instalación completada! Reinicia la sesión o el sistema según sea necesario."