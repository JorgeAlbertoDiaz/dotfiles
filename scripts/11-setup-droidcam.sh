#!/usr/bin/env bash
# 11-setup-droidcam: instala y configura DroidCam para usar el celular como webcam.
#
# Qué hace:
#   - Instala los paquetes listados en packages/droidcam.txt.
#   - Carga el módulo v4l2loopback (si no está cargado).
#   - Activa la carga automática del módulo.
#   - Verifica/agrega al usuario al grupo video para acceso a /dev/video*.
#   - Muestra instrucciones de uso y advertencias si hace falta logout.
#
# Uso: 11-setup-droidcam.sh [--quiet]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

REPO_DIR="$(dirname "${SCRIPT_DIR}")"

# --- 1) Instalar paquetes ---------------------------------------------------
info "Instalando paquetes de DroidCam..."
"${SCRIPT_DIR}/02-install-packages.sh" droidcam.txt

# --- 2) Configurar y cargar módulo v4l2loopback -----------------------------
# El flag exclusive_caps=1 es OBLIGATORIO para que apps como guvcview reconozcan
# el dispositivo loopback como una cámara de captura V4L2 real.
# devices=2 crea DOS dispositivos: uno para OBS Virtual Camera y otro para DroidCam.
V4L2_CONF="/etc/modprobe.d/v4l2loopback.conf"
V4L2_WANT='options v4l2loopback devices=2 exclusive_caps=1 card_label="DroidCam"'
if [[ -f "${V4L2_CONF}" ]] && grep -qF 'devices=2' "${V4L2_CONF}" && grep -qF 'exclusive_caps=1' "${V4L2_CONF}"; then
  ok "El módulo v4l2loopback ya está configurado con devices=2 y exclusive_caps=1."
else
  info "Configurando v4l2loopback con devices=2 y exclusive_caps=1 (requiere root)..."
  printf '%s\n' "${V4L2_WANT}" | as_root tee "${V4L2_CONF}" >/dev/null
  ok "Configurado en ${V4L2_CONF}"
fi

if lsmod | grep -q '^v4l2loopback'; then
  warn "El módulo v4l2loopback ya está cargado. Para aplicar devices=2 y"
  warn "es necesario recargarlo (desconectará cámaras virtuales)."
  if confirm_yes "¿Recargar el módulo ahora?"; then
    info "Recargando v4l2loopback..."
    as_root modprobe -r v4l2loopback || true
    as_root modprobe v4l2loopback
    ok "Módulo recargado con devices=2 y exclusive_caps=1."
  else
    warn "Saltando recarga. Puede NO funcionar hasta el próximo reinicio."
  fi
else
  info "Cargando módulo v4l2loopback (requiere root)..."
  as_root modprobe v4l2loopback
  ok "Módulo v4l2loopback cargado."
fi

# --- 3) Activar carga automática -------------------------------------------
if [[ -f /etc/modules-load.d/v4l2loopback.conf ]]; then
  ok "La carga automática de v4l2loopback ya está configurada."
else
  info "Configurando carga automática de v4l2loopback..."
  echo "v4l2loopback" | as_root tee /etc/modules-load.d/v4l2loopback.conf >/dev/null
  ok "Carga automática configurada en /etc/modules-load.d/v4l2loopback.conf"
fi

# --- 4) Grupo video ---------------------------------------------------------
USER_NAME="${SUDO_USER:-${USER}}"
if groups "${USER_NAME}" | grep -qw video; then
  ok "El usuario '${USER_NAME}' ya pertenece al grupo video."
else
  info "Agregando '${USER_NAME}' al grupo video (requiere root)..."
  as_root usermod -aG video "${USER_NAME}"
  warn "El usuario fue agregado al grupo video. Cerrá la sesión y volvé a entrar para que surta efecto."
fi

# --- 5) Verificar dispositivo video ----------------------------------------
if [[ -c /dev/video0 ]]; then
  ok "Dispositivo de video detectado: /dev/video0"
else
  warn "No se detectó /dev/video0. Si el módulo acaba de cargarse, puede aparecer en unos segundos."
fi

# --- 6) Instrucciones de uso ------------------------------------------------
cat <<'EOF'

╔══════════════════════════════════════════════════════════════════════════════╗
║                         DROIDCAM — INDICACIONES DE USO                       ║
╠══════════════════════════════════════════════════════════════════════════════╣
║ 1) Instalá la app DroidCam en tu celular (Android/iOS):                      ║
║    - Android: Play Store → "DroidCam" (por Dev47Apps)                        ║
║    - iOS: App Store → "DroidCam"                                             ║
║                                                                              ║
║ 2) Conexión por WiFi (más simple):                                           ║
║    - Asegurate de que la PC y el celular estén en la misma red.              ║
║    - Abrí la app y anotá la IP y el puerto que muestra (ej: 192.168.1.XX).   ║
║    - En la PC ejecutá:                                                       ║
║        droidcam-cli <IP> <puerto>                                            ║
║    - O usá la interfaz gráfica:                                              ║
║        droidcam                                                              ║
║                                                                              ║
║ 3) Conexión por USB (menos latencia, más estable):                           ║
║    - Activá la Depuración USB en el celular (Opciones de desarrollador).     ║
║    - Conectá el celular por USB a la PC.                                     ║
║    - Verificá que adb lo vea:  adb devices                                   ║
║    - Ejecutá:  droidcam-cli adb                                              ║
║                                                                              ║
║ 4) Ver el feed LOCALMENTE (sin navegador, sin límite de tiempo):             ║
║    - Conectá DroidCam primero (paso 2 o 3).                                  ║
║    - Verificá qué dispositivo usa DroidCam:  v4l2-ctl --list-devices         ║
║      (Si OBS Virtual Camera usa /dev/video0, DroidCam estará en /dev/video1) ║
║    - Opción A — mpv (más confiable, por terminal):                           ║
║        mpv av://v4l2:/dev/video1 --profile=low-latency                       ║
║      (cambiá /dev/video1 por el dispositivo correcto de DroidCam)            ║
║    - Opción B — guvcview (interfaz gráfica):                                 ║
║        guvcview -d /dev/video1                                               ║
║    - Ambas se conectan directamente al feed V4L2 — no usan red ni web.       ║
║                                                                              ║
║ 5) Usá la cámara en cualquier app:                                           ║
║    - DroidCam aparece como dispositivo V4L2 con el nombre "DroidCam".        ║
║    - Firefox, Chrome, Zoom, OBS, etc. la detectarán automáticamente.         ║
║    - Si tenés OBS Virtual Camera activa, DroidCam usará /dev/video1.         ║
║                                                                              ║
║ 6) Atajos útiles:                                                            ║
║    - droidcam-cli --list-devices    # lista resoluciones soportadas          ║
║    - droidcam-cli --help            # opciones avanzadas                     ║
║                                                                              ║
║ 7) Si no te funciona:                                                        ║
║    - Verificá que el módulo esté cargado:  lsmod | grep v4l2loopback         ║
║    - Verificá los dispositivos:  v4l2-ctl --list-devices                     ║
║    - Revisá permisos:  groups   (tenés que estar en 'video')                 ║
║    - Si cambiaste de grupo, CERRÁ SESIÓN y volvé a entrir.                   ║
║    - Si solo hay /dev/video0 y es OBS: cerrá OBS o recargá el módulo:        ║
║        sudo modprobe -r v4l2loopback && sudo modprobe v4l2loopback           ║
╚══════════════════════════════════════════════════════════════════════════════╝

EOF

ok "Setup de DroidCam completado."
