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

# Clave con la que NVIDIA firma los metadatos de ese repositorio. Sin ella en el
# keyring de rpm, zypper la pide por pantalla a mitad de una instalación (y en
# una ejecución sin TTY directamente invalida el repo).
# La huella es la que publica NVIDIA en la propia URL de la clave;
# NVIDIA_KEY_RPM es el nombre del paquete de clave que crea rpm al importarla.
NVIDIA_KEY_URL="${NVIDIA_REPO_URL}/repodata/repomd.xml.key"
NVIDIA_KEY_FPR="2FB0 3195 DECD 4949 2BD1 C17A B1D0 D788 DB27 FD5A"
NVIDIA_KEY_RPM="gpg-pubkey-db27fd5a-62589a51"

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

# Deja la clave de firma del repo NVIDIA en el keyring de rpm, verificando la
# huella ANTES de confiar en ella. Es lo que evita el prompt interactivo de
# zypper: si el usuario contesta "r" (o no hay TTY), el repo queda inválido y la
# instalación entera se cae por un repositorio de terceros.
# Si la huella no coincide NO se importa nada: si NVIDIA rota la clave, hay que
# actualizar NVIDIA_KEY_FPR a mano, a propósito.
asegurar_clave_nvidia() {
  local tmpdir gnupg keyfile fpr

  if rpm -q "${NVIDIA_KEY_RPM}" &>/dev/null; then
    ok "Clave de firma de NVIDIA ya importada"
    return 0
  fi

  if ! command -v gpg &>/dev/null; then
    warn "gpg no está instalado; no se puede verificar la huella de la clave."
    return 1
  fi

  tmpdir="$(mktemp -d)"
  gnupg="${tmpdir}/gnupg"
  keyfile="${tmpdir}/nvidia.key"
  mkdir -p "${gnupg}"        # gpg exige que GNUPGHOME ya exista

  info "Descargando la clave de firma de NVIDIA"
  if ! curl -fsSL --output "${keyfile}" "${NVIDIA_KEY_URL}"; then
    warn "No se pudo descargar ${NVIDIA_KEY_URL}"
    rm -rf "${tmpdir}"
    return 1
  fi

  # --show-keys es de sólo lectura (no importa) y con un GNUPGHOME temporal no
  # toca el keyring del usuario antes de haber verificado la huella.
  fpr="$(GNUPGHOME="${gnupg}" gpg --show-keys --with-colons --with-fingerprint "${keyfile}" 2>/dev/null \
        | awk -F: '$1 == "fpr" { print $10; exit }' \
        | sed -E 's/(.{4})/\1 /g; s/ $//')"

  if [[ "${fpr}" != "${NVIDIA_KEY_FPR}" ]]; then
    warn "La huella de la clave de NVIDIA no coincide: NO se importa."
    warn "  esperada: ${NVIDIA_KEY_FPR}"
    warn "  obtenida: ${fpr:-desconocida}"
    rm -rf "${tmpdir}"
    return 1
  fi
  ok "Huella de la clave de NVIDIA verificada"

  as_root rpm --import "${keyfile}"
  rm -rf "${tmpdir}"
  ok "Clave de firma de NVIDIA importada"
  return 0
}

if zypper repos | grep -qiE 'nvidia'; then
  ok "Repositorio nvidia ya configurado"
else
  info "Añadiendo repositorio NVIDIA: ${NVIDIA_REPO_URL}"
  as_root zypper addrepo --refresh "${NVIDIA_REPO_URL}" nvidia
fi

asegurar_clave_nvidia \
  || warn "La clave no quedó verificada; zypper podría pedirla o rechazar el repo."

info "Actualizando la cache de repositorios..."
# Tolerante a propósito: que un repo de terceros no refresque no debe tumbar la
# instalación completa (antes este refresh sin control cortaba todo el install.sh).
if as_root zypper refresh; then
  ok "Repositorios actualizados"
else
  warn "Algún repositorio no se pudo actualizar; se continúa con el resto."
  warn "Si es el de NVIDIA: sudo zypper modifyrepo --disable nvidia"
fi

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
