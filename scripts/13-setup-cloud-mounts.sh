#!/usr/bin/env bash
# 13-setup-cloud-mounts: deja listos los montajes FUSE de Google Drive y
# OneDrive con rclone, como unidades de usuario rclone@gdrive / rclone@onedrive
# sobre ~/Cloud/<remote>.
#
# Uso: 13-setup-cloud-mounts.sh [--provider gdrive|onedrive|both]
#                               [--google-json RUTA] [--check] [--quiet]
#   --provider     remotes a preparar (sin la opción pregunta con gum si hay TTY)
#   --google-json  siembra gdrive.env desde el JSON de OAuth que descarga
#                  Google Cloud Console (tipo *Desktop app*)
#   --check        sólo lectura: informa el estado y sale 1 si falta algo
#   --quiet        suprime info/ok (warn/error siempre salen)
#
# Qué hace, en orden: verifica dependencias, crea ~/.credentials (directorio
# 700) con un archivo <remote>.env por proveedor (600), aborta si quedan
# valores CHANGEME, crea el punto de montaje, crea el remote con
# `rclone config create` (OAuth en el navegador, una sola vez y sólo si el
# remote no existe) y habilita la unidad con systemd --user.
#
# Qué NO hace: no instala paquetes (los declara packages/cloud.txt y verifica),
# no escribe la plantilla de unidad (la despliega 04-setup-dotfiles.sh) y no
# guarda secretos en el repo.
#
# Ver docs/cloud-mounts.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Directorio 700 con un archivo por proveedor. No es un archivo único porque
# cada proveedor tiene su par de credenciales y systemd lee uno por unidad:
# rclone@<remote>.service usa EnvironmentFile=%h/.credentials/%i.env.
readonly CREDS_DIR="${HOME}/.credentials"
readonly RCLONE_CONF="${HOME}/.config/rclone/rclone.conf"
readonly UNIT_TEMPLATE="${HOME}/.config/systemd/user/rclone@.service"
readonly CLOUD_ROOT="${HOME}/Cloud"

PROVIDER=""
CHECK=0
JSON_FILE=""

usage() {
  local nombre="${BASH_SOURCE[0]##*/}"
  printf '%s\n' \
    "Uso: ${nombre} [--provider gdrive|onedrive|both] [--google-json RUTA]" \
    "                   [--check] [--quiet]" \
    "" \
    "Prepara el montaje de Google Drive y/o OneDrive con rclone (FUSE) y las" \
    "unidades de usuario rclone@<remote>.service que lo automontan en cada inicio." \
    "" \
    "Opciones:" \
    "  --provider gdrive|onedrive|both  remotes a preparar (default: preguntar)" \
    "  --google-json RUTA               siembra gdrive.env desde el JSON de Google" \
    "  --check                          sólo lectura: informa y sale 1 si falta algo" \
    "  --quiet                          suprime info/ok" \
    "  -h, --help                       esta ayuda" \
    "" \
    "Requisitos: rclone y fusermount3 (packages/cloud.txt), la plantilla" \
    "${HOME}/.config/systemd/user/rclone@.service desplegada y el navegador" \
    "a mano para el OAuth (una sola vez por proveedor)." \
    "" \
    "Credenciales: ${CREDS_DIR}/ (directorio 700) con gdrive.env y onedrive.env" \
    "(600). El JSON que descarga Google Cloud Console es el mismo dato en otro" \
    "formato: con --google-json el script lo convierte y lo archiva como" \
    "${CREDS_DIR}/gdrive.json." \
    "" \
    "Cada usuario corre este script en su propia sesión: las credenciales, el" \
    "refresh token de ${RCLONE_CONF} y ${CLOUD_ROOT}/<remote> son por usuario." \
    "No se usa root ni se toca el HOME de otro usuario."
}

# ---------------------------------------------------------------------------
# Metadatos por remote
# ---------------------------------------------------------------------------
backend_de() {
  case "$1" in
    gdrive)   printf 'drive' ;;
    onedrive) printf 'onedrive' ;;
    *)        return 1 ;;
  esac
}

remotes_seleccionados() {
  case "${PROVIDER}" in
    both)     printf '%s\n' gdrive onedrive ;;
    gdrive)   printf 'gdrive\n' ;;
    onedrive) printf 'onedrive\n' ;;
  esac
}

# Rutas por proveedor dentro de ~/.credentials.
creds_de() { printf '%s/%s.env' "${CREDS_DIR}" "$1"; }
json_de()  { printf '%s/%s.json' "${CREDS_DIR}" "$1"; }

# Variables de ese remote (las de OneDrive son opcionales: rclone trae un
# client_id embebido que funciona).
variables_de() {
  case "$1" in
    gdrive)   printf '%s\n' RCLONE_DRIVE_CLIENT_ID RCLONE_DRIVE_CLIENT_SECRET ;;
    onedrive) printf '%s\n' RCLONE_ONEDRIVE_CLIENT_ID RCLONE_ONEDRIVE_CLIENT_SECRET ;;
  esac
}

# ---------------------------------------------------------------------------
# Plantillas de credenciales (heredoc: el repo no versiona rutas con secretos)
# ---------------------------------------------------------------------------
plantilla_de() {
  case "$1" in
    gdrive)
      cat <<'ENV'
# ~/.credentials/gdrive.env — credenciales de la app OAuth de Google Drive.
#
# Quién lee este archivo: la unidad rclone@gdrive.service, con
# EnvironmentFile=%h/.credentials/%i.env, y una shell con
#   set -a; . ~/.credentials/gdrive.env; set +a
#
# Formato: KEY=VALOR por línea, sin "export" y sin comillas (salvo que el valor
# tenga espacios); "#" comenta. Este archivo va en 600 y su directorio en 700.
#
# Los valores salen de Google Cloud Console → APIs & Services → Credentials →
# OAuth client ID, tipo *Desktop app*.
#   https://rclone.org/drive/#making-your-own-client-id
# El JSON que descarga Google en ese paso es el mismo par de valores en otro
# formato. No hace falta abrirlo: esto lo genera solo
#   ./scripts/13-setup-cloud-mounts.sh --google-json ~/Descargas/<archivo>.json
#
# La app debe quedar publicada en "In production": en "Testing", Google expira
# el refresh token cada 7 días y el montaje falla con invalid_grant.

RCLONE_DRIVE_CLIENT_ID=CHANGEME-000000000000-xxxxxxxxxxxxxxxx.apps.googleusercontent.com
RCLONE_DRIVE_CLIENT_SECRET=CHANGEME-GOCSPX-xxxxxxxxxxxxxxxxxxxx
ENV
      ;;
    onedrive)
      cat <<'ENV'
# ~/.credentials/onedrive.env — credenciales OPCIONALES de OneDrive.
#
# Sin valores, OneDrive usa el client_id embebido de rclone, que funciona.
# Descomentá las dos líneas de abajo sólo si registrás tu propia app en
# Microsoft Entra ID (Azure AD).
#
# Ojo: la unidad rclone@onedrive.service lee este archivo con
# EnvironmentFile=%h/.credentials/%i.env, así que si habilitás esa unidad el
# archivo tiene que existir (aunque sólo tenga comentarios). Si falta, systemd
# falla en voz alta en lugar de arrancar un remote a medias.
#
# Formato: KEY=VALOR por línea, sin "export" y sin comillas (salvo espacios).
# Este archivo va en 600 y su directorio en 700.

#RCLONE_ONEDRIVE_CLIENT_ID=CHANGEME-00000000-0000-0000-0000-000000000000
#RCLONE_ONEDRIVE_CLIENT_SECRET=CHANGEME-xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
ENV
      ;;
    *)
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Verificaciones (compartidas por la corrida real y por --check)
# ---------------------------------------------------------------------------
verificar_dependencias() {
  local faltan=0
  if ! command -v rclone >/dev/null 2>&1; then
    error "rclone no está instalado. Instalalo con:"
    error "  sudo zypper install rclone rclone-bash-completion rclone-zsh-completion"
    faltan=1
  fi
  if ! command -v fusermount3 >/dev/null 2>&1; then
    error "fusermount3 no está disponible (paquete fuse3):"
    error "  sudo zypper install fuse3"
    faltan=1
  fi
  if [[ ! -f "${UNIT_TEMPLATE}" ]]; then
    error "Falta la plantilla de unidad ${UNIT_TEMPLATE}."
    error "  Desplegala con: ./scripts/04-setup-dotfiles.sh"
    faltan=1
  fi
  if [[ -f "${CREDS_DIR}" ]]; then
    error "${CREDS_DIR} es un archivo y ahora el layout es un directorio 700"
    error "  con un <remote>.env adentro. Migralo a mano antes de seguir."
    faltan=1
  fi
  return "${faltan}"
}

# Lista las variables del remote que siguen con CHANGEME (sólo líneas activas).
changeme_pendientes() {
  local remote="$1" archivo patrones="" var
  archivo="$(creds_de "${remote}")"
  for var in $(variables_de "${remote}"); do
    patrones+="${patrones:+|}${var}"
  done
  [[ -f "${archivo}" ]] || return 0
  grep -E "^[[:space:]]*(${patrones})=.*CHANGEME" "${archivo}" 2>/dev/null || true
}

# ¿El remote ya está en rclone.conf? Evita repetir el OAuth en cada corrida.
remote_configurado() {
  local remote="$1"
  [[ -f "${RCLONE_CONF}" ]] || return 1
  rclone listremotes --config "${RCLONE_CONF}" 2>/dev/null | grep -Fxq "${remote}:"
}

# Linger es estado del usuario, no de la máquina: sin él, el user manager no
# arranca los montajes hasta que el usuario inicia sesión (y el automonte en el
# boot no existe). Cada usuario lo activa para sí mismo.
usuario_actual() { printf '%s' "${USER:-$(id -un)}"; }

linger_activo() {
  command -v loginctl >/dev/null 2>&1 || return 0
  loginctl show-user "$(usuario_actual)" -p Linger 2>/dev/null | grep -Fxq 'Linger=yes'
}

avisar_linger() {
  if linger_activo; then
    ok "Linger activo para $(usuario_actual): los montajes arrancan en el boot."
    return 0
  fi
  warn "Sin linger, los montajes de $(usuario_actual) arrancan al iniciar sesión, no en el boot."
  warn "  Activalo una vez para este usuario: loginctl enable-linger $(usuario_actual)"
  return 1
}

# ---------------------------------------------------------------------------
# Pasos que mutan
# ---------------------------------------------------------------------------
# Crea el directorio 700 y el <remote>.env 600 si faltan. No sobrescribe nada
# que ya exista: los secretos son del usuario, no del instalador.
asegurar_credenciales() {
  local remote="$1" destino
  destino="$(creds_de "${remote}")"
  (umask 077; mkdir -p "${CREDS_DIR}")
  if [[ "$(stat -c '%a' "${CREDS_DIR}")" != "700" ]]; then
    chmod 700 "${CREDS_DIR}"
    warn "Ajustado el modo de ${CREDS_DIR} a 700 (sólo tu usuario entra)."
  fi
  if [[ -f "${destino}" ]]; then
    ok "${destino} ya existe: no se sobrescribe."
    if [[ "$(stat -c '%a' "${destino}")" != "600" ]]; then
      chmod 600 "${destino}"
      warn "Ajustado el modo de ${destino} a 600."
    fi
    return 0
  fi
  info "Creando ${destino} desde la plantilla."
  (umask 077; plantilla_de "${remote}" > "${destino}")
  chmod 600 "${destino}"
  case "${remote}" in
    gdrive)
      warn "Completá ${destino} con tu client_id y client_secret, o generá el archivo"
      warn "  desde el JSON de Google: $(basename "${BASH_SOURCE[0]}") --google-json ~/Descargas/<archivo>.json"
      ;;
    onedrive)
      info "${destino} quedó sin valores: OneDrive usa el client_id embebido de rclone."
      ;;
  esac
}

# Convierte el JSON de OAuth que descarga Google Cloud Console en gdrive.env.
# El JSON no lo lee nadie en tiempo de ejecución: sólo se archiva al lado, con
# nombre corto, por si hay que volver a mirarlo.
sembrar_desde_json() {
  local json="$1" destino client_id client_secret
  destino="$(creds_de gdrive)"
  if [[ ! -f "${json}" ]]; then
    error "No existe el JSON indicado: ${json}"
    return 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    error "Falta jq para leer el JSON (paquete jq, está en packages/base.txt)."
    return 1
  fi
  if jq -e '.web' "${json}" >/dev/null 2>&1; then
    error "${json} es un cliente *Web application*: rclone necesita *Desktop app*."
    error "  Creá otra credencial en Google Cloud Console con ese tipo."
    return 1
  fi
  if ! jq -e '.installed | .client_id and .client_secret' "${json}" >/dev/null 2>&1; then
    error "${json} no parece un JSON de cliente OAuth de Google (installed.client_id)."
    return 1
  fi
  if [[ -f "${destino}" ]] && [[ -z "$(changeme_pendientes gdrive)" ]]; then
    error "${destino} ya tiene credenciales cargadas: no las piso."
    error "  Si querés rotarlas: borrá el archivo, volvé a correr con --google-json"
    error "  y después reautorizá con: rclone config reconnect gdrive:"
    return 1
  fi
  client_id="$(jq -r '.installed.client_id' "${json}")"
  client_secret="$(jq -r '.installed.client_secret' "${json}")"
  (umask 077; mkdir -p "${CREDS_DIR}")
  [[ "$(stat -c '%a' "${CREDS_DIR}")" == "700" ]] || chmod 700 "${CREDS_DIR}"
  (
    umask 077
    printf '%s\n' \
      "# ~/.credentials/gdrive.env — generado desde el JSON de Google Cloud Console." \
      "# Editá a mano sólo si sabés que el client_id y el refresh token tienen que" \
      "# seguir siendo del mismo cliente OAuth (si cambia uno, reautorizá)." \
      "RCLONE_DRIVE_CLIENT_ID=${client_id}" \
      "RCLONE_DRIVE_CLIENT_SECRET=${client_secret}" > "${destino}"
  )
  chmod 600 "${destino}"
  install -m 600 "${json}" "$(json_de gdrive)"
  ok "Credenciales de gdrive cargadas en ${destino}"
  ok "JSON archivado como $(json_de gdrive) (600; no lo lee nadie en ejecución)"
}

verificar_sin_changeme() {
  local remote="$1" pendientes
  pendientes="$(changeme_pendientes "${remote}")"
  [[ -n "${pendientes}" ]] || return 0
  error "Quedan valores CHANGEME en $(creds_de "${remote}"):"
  while IFS= read -r linea; do
    [[ -n "${linea}" ]] && error "  ${linea}"
  done <<<"${pendientes}"
  error "Completalos antes de habilitar rclone@${remote}.service."
  return 1
}

asegurar_montaje() {
  local remote="$1"
  mkdir -p "${CLOUD_ROOT}/${remote}"
  ok "Punto de montaje listo: ${CLOUD_ROOT}/${remote}"
}

asegurar_remote() {
  local remote="$1" backend
  backend="$(backend_de "${remote}")"
  if remote_configurado "${remote}"; then
    ok "El remote ${remote} ya existe en ${RCLONE_CONF}: no se repite el OAuth."
    return 0
  fi
  if [[ ! -t 0 ]]; then
    error "Falta el remote ${remote} y no hay terminal interactiva para el OAuth."
    error "  Corré a mano: rclone config create ${remote} ${backend}"
    return 1
  fi
  info "Autorizando ${remote} en el navegador (una sola vez)..."
  # set -a exporta las RCLONE_* para que rclone tome el client_id propio sin
  # pasarlo por la línea de comandos (donde sería visible en ps).
  set -a
  # shellcheck disable=SC1090
  . "$(creds_de "${remote}")"
  set +a
  case "${remote}" in
    gdrive)
      rclone config create "${remote}" "${backend}" scope=drive \
        --config "${RCLONE_CONF}"
      ;;
    onedrive)
      rclone config create "${remote}" "${backend}" --config "${RCLONE_CONF}"
      ;;
  esac
  ok "Remote ${remote} creado."
}

habilitar_unidades() {
  local remote="$1"
  systemctl --user daemon-reload
  systemctl --user enable --now "rclone@${remote}.service"
  ok "Unidad habilitada: rclone@${remote}.service"
}

# ---------------------------------------------------------------------------
# --check: sólo lectura, sin crear nada
# ---------------------------------------------------------------------------
revisar() {
  local fallos=0 remote archivo
  if command -v rclone >/dev/null 2>&1; then
    ok "rclone: $(rclone version 2>/dev/null | head -1 | cut -d' ' -f2)"
  else
    warn "PENDIENTE rclone no instalado: sudo zypper install rclone rclone-bash-completion rclone-zsh-completion"
    fallos=$((fallos + 1))
  fi
  command -v fusermount3 >/dev/null 2>&1 \
    || { warn "PENDIENTE fusermount3 ausente: sudo zypper install fuse3"; fallos=$((fallos + 1)); }
  if [[ -f "${UNIT_TEMPLATE}" ]]; then
    ok "Plantilla de unidad presente: ${UNIT_TEMPLATE}"
  else
    warn "PENDIENTE falta la plantilla ${UNIT_TEMPLATE}: ./scripts/04-setup-dotfiles.sh"
    fallos=$((fallos + 1))
  fi
  if [[ -f "${CREDS_DIR}" ]]; then
    warn "PENDIENTE ${CREDS_DIR} es un archivo; el layout nuevo es un directorio 700"
    fallos=$((fallos + 1))
  elif [[ -d "${CREDS_DIR}" ]]; then
    if [[ "$(stat -c '%a' "${CREDS_DIR}")" != "700" ]]; then
      warn "PENDIENTE ${CREDS_DIR} no está en modo 700"
      fallos=$((fallos + 1))
    else
      ok "${CREDS_DIR} presente y en modo 700"
    fi
  else
    warn "PENDIENTE falta ${CREDS_DIR} (se crea en la corrida real)"
    fallos=$((fallos + 1))
  fi
  if ! linger_activo; then
    warn "PENDIENTE sin linger para $(usuario_actual): loginctl enable-linger $(usuario_actual)"
    fallos=$((fallos + 1))
  fi

  for remote in $(remotes_seleccionados); do
    archivo="$(creds_de "${remote}")"
    if [[ ! -f "${archivo}" ]]; then
      warn "PENDIENTE ${remote}: falta ${archivo}"
      fallos=$((fallos + 1))
    elif [[ "$(stat -c '%a' "${archivo}")" != "600" ]]; then
      warn "PENDIENTE ${remote}: ${archivo} no está en modo 600"
      fallos=$((fallos + 1))
    elif [[ -n "$(changeme_pendientes "${remote}")" ]]; then
      warn "PENDIENTE ${remote}: quedan valores CHANGEME en ${archivo}"
      fallos=$((fallos + 1))
    else
      ok "${remote}: credenciales en ${archivo} (600)"
    fi
    if remote_configurado "${remote}"; then
      ok "${remote}: remote configurado"
    else
      warn "PENDIENTE ${remote}: falta el remote (rclone config create ${remote} $(backend_de "${remote}"))"
      fallos=$((fallos + 1))
    fi
    if [[ -d "${CLOUD_ROOT}/${remote}" ]]; then
      ok "${remote}: punto de montaje ${CLOUD_ROOT}/${remote}"
    else
      warn "PENDIENTE ${remote}: falta el directorio ${CLOUD_ROOT}/${remote}"
      fallos=$((fallos + 1))
    fi
    if systemctl --user is-enabled "rclone@${remote}.service" >/dev/null 2>&1; then
      ok "${remote}: unidad habilitada"
    else
      warn "PENDIENTE ${remote}: unidad rclone@${remote}.service no habilitada"
      fallos=$((fallos + 1))
    fi
    if command -v mountpoint >/dev/null 2>&1 && mountpoint -q "${CLOUD_ROOT}/${remote}" 2>/dev/null; then
      ok "${remote}: montado"
    else
      warn "PENDIENTE ${remote}: ${CLOUD_ROOT}/${remote} no está montado"
      fallos=$((fallos + 1))
    fi
  done

  if [[ ${fallos} -eq 0 ]]; then
    ok "Todo listo."
    return 0
  fi
  warn "${fallos} punto(s) pendiente(s)."
  return 1
}

# ---------------------------------------------------------------------------
# Argumentos
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --provider)
      [[ $# -ge 2 ]] || { error "--provider necesita un valor"; exit 1; }
      PROVIDER="$2"
      shift 2
      ;;
    --provider=*) PROVIDER="${1#*=}"; shift ;;
    --google-json)
      [[ $# -ge 2 ]] || { error "--google-json necesita una ruta"; exit 1; }
      JSON_FILE="$2"
      shift 2
      ;;
    --google-json=*) JSON_FILE="${1#*=}"; shift ;;
    --check) CHECK=1; shift ;;
    --quiet) export QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      error "Argumento desconocido: $1"
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -n "${PROVIDER}" ]]; then
  case "${PROVIDER}" in
    gdrive|onedrive|both) ;;
    *)
      error "Valor inválido para --provider: ${PROVIDER} (válidos: gdrive|onedrive|both)"
      exit 1
      ;;
  esac
elif has_gum; then
  PROVIDER="$(gum choose --header "¿Qué remotes preparo?" gdrive onedrive both)"
  [[ -n "${PROVIDER}" ]] || { warn "No se eligió nada."; exit 1; }
else
  error "Sin --provider y sin TTY para preguntar (válidos: gdrive|onedrive|both)."
  exit 1
fi

# --google-json sólo tiene sentido si gdrive está en la selección.
if [[ -n "${JSON_FILE}" && "${PROVIDER}" == "onedrive" ]]; then
  error "--google-json es para Google Drive; con --provider onedrive no aplica."
  exit 1
fi
if [[ ${CHECK} -eq 1 && -n "${JSON_FILE}" ]]; then
  error "--check es de sólo lectura: no se puede combinar con --google-json."
  exit 1
fi

if [[ ${CHECK} -eq 1 ]]; then
  revisar
  exit $?
fi

# ---------------------------------------------------------------------------
# Corrida real
# ---------------------------------------------------------------------------
verificar_dependencias
# Aviso, no error: un usuario puede preferir que el montaje arranque al iniciar
# sesión en lugar de en el boot.
avisar_linger || true

if [[ -n "${JSON_FILE}" ]]; then
  sembrar_desde_json "${JSON_FILE}" || exit 1
fi

for remote in $(remotes_seleccionados); do
  asegurar_credenciales "${remote}"
done

# Se valida todo antes de mutar el resto: con CHANGEME pendientes no se crea el
# punto de montaje, no se lanza el OAuth y no se habilita ninguna unidad.
for remote in $(remotes_seleccionados); do
  verificar_sin_changeme "${remote}" || exit 1
done

for remote in $(remotes_seleccionados); do
  asegurar_montaje "${remote}"
  asegurar_remote "${remote}" || exit 1
done

for remote in $(remotes_seleccionados); do
  habilitar_unidades "${remote}"
done

ok "Montajes preparados: $(remotes_seleccionados | tr '\n' ' ')"
info "Verificá con: $(basename "${BASH_SOURCE[0]}") --check --provider ${PROVIDER}"
