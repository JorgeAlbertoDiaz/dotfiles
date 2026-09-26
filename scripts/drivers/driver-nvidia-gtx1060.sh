#!/usr/bin/env bash
# driver-nvidia-gtx1060 — controlador para una placa concreta.
#
# Este archivo es un "entry-point por hardware": resuelve TODO lo necesario
# para una NVIDIA GeForce GTX 1060 3 GB (arquitectura GP106, drivers de la
# rama G06) en openSUSE Tumbleweed.
#
# Es autocontenido a propósito: la lista de paquetes vive acá y no en
# packages/*.txt, porque los paquetes que hacen falta dependen de LA PLACA,
# no del sistema. Si mañana se agrega otra GPU, se copia este archivo, se
# cambia el nombre a driver-<vendor>-<modelo>.sh y se ajustan los paquetes.
# El submenú scripts/drivers/drivers-menu.sh la descubre sola, sin editarlo.
#
# Idempotente: se puede ejecutar varias veces seguidas sin duplicar nada.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# Repositorio oficial de NVIDIA para Tumbleweed. Los paquetes "G06" son los
# que esa rama publica para la generación GP106.
NVIDIA_REPO_URL="https://download.nvidia.com/opensuse/tumbleweed"

# Paquetes para la GeForce GTX 1060 3 GB (GP106).
#   nvidia-driver-G06-kmp-default → módulo de kernel propietario (rama G06)
#   nvidia-gl-G06                → userspace OpenGL/GLX de NVIDIA
#   nvidia-vulkan-G06            → ICD de Vulkan (lo necesita Wayland)
NVIDIA_PKGS=(
  "nvidia-driver-G06-kmp-default"
  "nvidia-gl-G06"
  "nvidia-vulkan-G06"
)

# ---------------------------------------------------------------------------
# 1) Repositorio NVIDIA
#     Idempotente: si el repo ya está configurado no se vuelve a añadir, así
#     que reejecutar el script no duplica entradas en zypper.
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
#     La EULA de NVIDIA no se acepta automáticamente: zypper se corre en modo
#     interactivo (sin -n ni --auto-agree-with-licenses) para que el usuario
#     acepte la licencia en pantalla. Antes se separa lo ya instalado de lo
#     pendiente con "rpm -q", así nunca se intenta reinstalar nada.
# ---------------------------------------------------------------------------

missing_pkgs=()

for pkg in "${NVIDIA_PKGS[@]}"; do
  if rpm -q "${pkg}" &>/dev/null; then
    ok "${pkg} ya instalado"
  else
    missing_pkgs+=("${pkg}")
  fi
done

if [[ ${#missing_pkgs[@]} -eq 0 ]]; then
  ok "Controladores NVIDIA ya instalados; omitiendo instalación"
else
  info "Instalando controladores NVIDIA pendientes: ${missing_pkgs[*]}"
  info "La licencia de NVIDIA requiere aceptación interactiva (EULA) en pantalla."
  # "warn y seguir" a propósito: si falla (EULA no aceptada o paquetes no
  # disponibles en el repo) NO se aborta el script. Un problema de GPU no
  # debe tumbar una instalación completa de dotfiles; solo se avisa.
  if as_root zypper in "${missing_pkgs[@]}" 2>/dev/null; then
    ok "Controladores NVIDIA instalados"
  else
    warn "No se pudieron instalar los controladores NVIDIA."
    warn "Esto puede deberse a que es necesario aceptar la licencia EULA en pantalla"
    warn "o a que los paquetes no estén disponibles en el repositorio configurado."
    warn "Se omitirá la configuración NVIDIA y continuará la instalación."
  fi
fi

# ---------------------------------------------------------------------------
# 3) Parámetro de kernel nvidia_drm.modeset=1
#     Sin esto el driver propietario no enciende KMS/DRM y no hay salida por
#     Wayland: la sesión arranca y se ve negro. Se escribe en los dos lados
#     que importan: la cmdline de GRUB (arranque) y modprobe (carga del
#     módulo), para que funcione también sin reiniciar de inmediato.
#     GRUB_MODIFICADO recuerda si hubo que tocar el archivo, para no
#     regenerar grub.cfg (operación lenta y con root) en cada ejecución.
# ---------------------------------------------------------------------------

GRUB_FILE="/etc/default/grub"
MODPROBE_FILE="/etc/modprobe.d/50-nvidia.conf"
MODPROBE_CONTENT="options nvidia_drm modeset=1"
GRUB_PARAM="nvidia_drm.modeset=1"
GRUB_MODIFICADO=0

if [[ -f "${GRUB_FILE}" ]]; then
  if grep -q "${GRUB_PARAM}" "${GRUB_FILE}"; then
    ok "Parámetro ${GRUB_PARAM} ya presente en ${GRUB_FILE}"
  else
    info "Añadiendo ${GRUB_PARAM} a GRUB_CMDLINE_LINUX_DEFAULT..."
    as_root sed -i "s/\(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*\)\"/\1 ${GRUB_PARAM}\"/" "${GRUB_FILE}"
    ok "Parámetro añadido a GRUB"
    GRUB_MODIFICADO=1
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
# 4) Regenerar GRUB (solo si el archivo se modificó en este paso)
# ---------------------------------------------------------------------------

if [[ ${GRUB_MODIFICADO} -eq 1 ]]; then
  info "Regenerando configuración de GRUB..."
  as_root grub2-mkconfig -o /boot/grub2/grub.cfg
  ok "GRUB regenerado"
elif [[ -f "${GRUB_FILE}" ]]; then
  # Solo se regenera si este script acaba de tocar el archivo: si el parámetro
  # ya estaba de antes, grub.cfg ya lo tiene y no hay nada que rehacer.
  info "GRUB ya tenía ${GRUB_PARAM}; no hace falta regenerar la configuración."
fi

# ---------------------------------------------------------------------------
# 5) Verificación final
#     Comprobar con lspci que la GPU realmente aparece: es la única señal de
#     que el módulo se cargó de verdad y no solo se instaló.
# ---------------------------------------------------------------------------

info "Comprobando la GPU detectada..."
lspci | grep -i nvidia || warn "No se encontró ningún dispositivo NVIDIA visible."

ok "Configuración NVIDIA completada"
warn "Reinicia el sistema para aplicar los cambios del kernel (nvidia_drm.modeset=1)."
