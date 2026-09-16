#!/usr/bin/env bash
# 03-nvidia-setup: añade el repositorio NVIDIA de openSUSE Tumbleweed
# e instala los controladores propietarios (GTX 1060 3 GB).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

NVIDIA_REPO_URL="https://download.nvidia.com/opensuse/tumbleweed"

if zypper repos | grep -qiE 'nvidia'; then
  ok "Repositorio nvidia ya configurado"
else
  info "Añadiendo repositorio NVIDIA: ${NVIDIA_REPO_URL}"
  as_root zypper addrepo --refresh "${NVIDIA_REPO_URL}" nvidia
fi

info "Actualizando la cache de repositorios..."
as_root zypper refresh
ok "Repositorios actualizados"

export ZYPPER_OPTS="-n --auto-agree-with-licenses"
"${SCRIPT_DIR}/02-install-packages.sh" nvidia.txt

info "Comprobando la GPU detectada..."
lspci | grep -i nvidia || warn "No se encontró ningún dispositivo NVIDIA visible."

ok "Configuración NVIDIA completada"