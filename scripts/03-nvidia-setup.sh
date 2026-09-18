#!/usr/bin/env bash
# 03-nvidia-setup: añade el repositorio NVIDIA de openSUSE Tumbleweed,
# instala los controladores propietarios (GTX 1060 3 GB) y configura
# los parámetros del kernel para Wayland.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

NVIDIA_REPO_URL="https://download.nvidia.com/opensuse/tumbleweed"

# ---------------------------------------------------------------------------
# 1) Repositorio NVIDIA
# ---------------------------------------------------------------------------

if zypper repos | grep -qiE 'nvidia'; then
  ok "Repositorio nvidia ya configurado"
else
  info "Añadiendo repositorio NVIDIA: ${NVIDIA_REPO_URL}"
  as_root zypper addrepo --refresh "${NVIDIA_REPO_URL}" nvidia
fi

info "Actualizando la cache de repositorios..."
as_root zypper refresh
ok "Repositorios actualizados"

# ---------------------------------------------------------------------------
# 2) Controladores propietarios NVIDIA
#    La EULA de NVIDIA no se acepta automáticamente: zypper se ejecuta en
#    modo interactivo (sin -n ni --auto-agree-with-licenses) para que el
#    usuario acepte la licencia en pantalla. Si los paquetes ya están
#    instalados, se omite la instalación.
# ---------------------------------------------------------------------------

PACKAGES_DIR="$(dirname "${SCRIPT_DIR}")/packages"
NVIDIA_PKGS_FILE="${PACKAGES_DIR}/nvidia.txt"
missing_pkgs=()

while IFS= read -r line || [[ -n "${line}" ]]; do
  # Quitar comentarios (#) y espacios sobrantes.
  pkg="${line%%#*}"
  pkg="${pkg//[[:space:]]/}"
  [[ -z "${pkg}" ]] && continue
  if rpm -q "${pkg}" &>/dev/null; then
    ok "${pkg} ya instalado"
  else
    missing_pkgs+=("${pkg}")
  fi
done < "${NVIDIA_PKGS_FILE}"

if [[ ${#missing_pkgs[@]} -eq 0 ]]; then
  ok "Controladores NVIDIA ya instalados; omitiendo instalación"
else
  info "Instalando controladores NVIDIA pendientes: ${missing_pkgs[*]}"
  info "La licencia de NVIDIA requiere aceptación interactiva (EULA) en pantalla."
  # Sin -n ni --auto-agree-with-licenses: zypper muestra la EULA y pregunta.
  as_root zypper in "${missing_pkgs[@]}"
  ok "Controladores NVIDIA instalados"
fi

# ---------------------------------------------------------------------------
# 3) Parámetro del kernel nvidia_drm.modeset=1
# ---------------------------------------------------------------------------

GRUB_FILE="/etc/default/grub"
MODPROBE_FILE="/etc/modprobe.d/50-nvidia.conf"
MODPROBE_CONTENT="options nvidia_drm modeset=1"
GRUB_PARAM="nvidia_drm.modeset=1"

if [[ -f "${GRUB_FILE}" ]]; then
  if grep -q "${GRUB_PARAM}" "${GRUB_FILE}"; then
    ok "Parámetro ${GRUB_PARAM} ya presente en ${GRUB_FILE}"
  else
    info "Añadiendo ${GRUB_PARAM} a GRUB_CMDLINE_LINUX_DEFAULT..."
    as_root sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 ${GRUB_PARAM}\"/" "${GRUB_FILE}"
    ok "Parámetro añadido a GRUB"
  fi
else
  warn "${GRUB_FILE} no existe; omitiendo configuración de GRUB"
fi

if [[ -f "${MODPROBE_FILE}" ]]; then
  if grep -q "${MODPROBE_CONTENT}" "${MODPROBE_FILE}"; then
    ok "${MODPROBE_FILE} ya configurado correctamente"
  else
    info "Actualizando ${MODPROBE_FILE}..."
    as_root bash -c "echo '${MODPROBE_CONTENT}' > '${MODPROBE_FILE}'"
    ok "${MODPROBE_FILE} actualizado"
  fi
else
  info "Creando ${MODPROBE_FILE}..."
  as_root bash -c "echo '${MODPROBE_CONTENT}' > '${MODPROBE_FILE}'"
  ok "${MODPROBE_FILE} creado"
fi

# ---------------------------------------------------------------------------
# 4) Regenerar GRUB (solo si se modificó)
# ---------------------------------------------------------------------------

if grep -q "${GRUB_PARAM}" "${GRUB_FILE}"; then
  info "Regenerando configuración de GRUB..."
  as_root grub2-mkconfig -o /boot/grub2/grub.cfg
  ok "GRUB regenerado"
fi

# ---------------------------------------------------------------------------
# 5) Verificación final
# ---------------------------------------------------------------------------

info "Comprobando la GPU detectada..."
lspci | grep -i nvidia || warn "No se encontró ningún dispositivo NVIDIA visible."

ok "Configuración NVIDIA completada"
warn "Reinicia el sistema para aplicar los cambios del kernel (nvidia_drm.modeset=1)."