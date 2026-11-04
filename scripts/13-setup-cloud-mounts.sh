#!/usr/bin/env bash
# 13-setup-cloud-mounts: deja listos los montajes FUSE de Google Drive y
# OneDrive con rclone, como unidades de usuario rclone@gdrive / rclone@onedrive
# sobre ~/Cloud/<remote>.
#
# Uso: 13-setup-cloud-mounts.sh [--provider gdrive|onedrive|both] [--check] [--quiet]
#   --provider  remotes a preparar (sin la opción pregunta con gum si hay TTY)
#   --check     sólo lectura: informa el estado y sale 1 si falta algo
#   --quiet     suprime info/ok (warn/error siempre salen)
#
# Qué hace, en orden: verifica dependencias, crea ~/.credentials desde la
# plantilla con modo 600 si falta, aborta si quedan valores CHANGEME, crea el
# punto de montaje, crea el remote con `rclone config create` (OAuth en el
# navegador, una sola vez y sólo si el remote no existe) y habilita la unidad
# con systemd --user.
#
# Qué NO hace: no instala paquetes (los declara packages/cloud.txt y verifica),
# no escribe la plantilla de unidad (la despliega 04-setup-dotfiles.sh) y no
# guarda secretos en el repo.
#
# Ver docs/cloud-mounts.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

REPO_DIR="$(dirname "${SCRIPT_DIR}")"
readonly CREDS_EXAMPLE="${REPO_DIR}/config/home/.credentials.example"
readonly CREDS="${HOME}/.credentials"
readonly RCLONE_CONF="${HOME}/.config/rclone/rclone.conf"
readonly UNIT_TEMPLATE="${HOME}/.config/systemd/user/rclone@.service"
readonly CLOUD_ROOT="${HOME}/Cloud"

PROVIDER=""
CHECK=0

usage() {
  local nombre="${BASH_SOURCE[0]##*/}"
  printf '%s\n' \
    "Uso: ${nombre} [--provider gdrive|onedrive|both] [--check] [--quiet]" \
    "" \
    "Prepara el montaje de Google Drive y/o OneDrive con rclone (FUSE) y las" \
    "unidades de usuario rclone@<remote>.service que lo automontan en cada inicio." \
    "" \
    "Opciones:" \
    "  --provider gdrive|onedrive|both  remotes a preparar (default: preguntar)" \
    "  --check                          sólo lectura: informa y sale 1 si falta algo" \
    "  --quiet                          suprime info/ok" \
    "  -h, --help                       esta ayuda" \
    "" \
    "Requisitos: rclone y fusermount3 (packages/cloud.txt), la plantilla" \
    "${HOME}/.config/systemd/user/rclone@.service desplegada y el navegador" \
    "a mano para el OAuth (una sola vez por proveedor)." \
    "" \
    "Cada usuario corre este script en su propia sesión: ~/.credentials, el" \
    "refresh token de ~/.config/rclone/rclone.conf y ~/Cloud/<remote> son por" \
    "usuario. No se usa root ni se toca el HOME de otro usuario."
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

# Variables de ~/.credentials que ese remote necesita (las de OneDrive son
# opcionales: rclone trae un client_id embebido que funciona).
variables_de() {
  case "$1" in
    gdrive)   printf '%s\n' RCLONE_DRIVE_CLIENT_ID RCLONE_DRIVE_CLIENT_SECRET ;;
    onedrive) printf '%s\n' RCLONE_ONEDRIVE_CLIENT_ID RCLONE_ONEDRIVE_CLIENT_SECRET ;;
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
  if [[ ! -f "${CREDS_EXAMPLE}" ]]; then
    error "Falta la plantilla del repo ${CREDS_EXAMPLE}."
    faltan=1
  fi
  return "${faltan}"
}

# Lista las variables del remote que siguen con CHANGEME (sólo líneas activas).
changeme_pendientes() {
  local remote="$1" patrones="" var
  for var in $(variables_de "${remote}"); do
    patrones+="${patrones:+|}${var}"
  done
  [[ -f "${CREDS}" ]] || return 0
  grep -E "^[[:space:]]*(${patrones})=.*CHANGEME" "${CREDS}" 2>/dev/null || true
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
asegurar_credenciales() {
  if [[ -f "${CREDS}" ]]; then
    ok "${CREDS} ya existe: no se sobrescribe."
    if [[ "$(stat -c '%a' "${CREDS}")" != "600" ]]; then
      chmod 600 "${CREDS}"
      warn "Ajustado el modo de ${CREDS} a 600 (sólo vos podés leerlo)."
    fi
    return 0
  fi
  info "Creando ${CREDS} desde la plantilla del repo."
  install -m 600 "${CREDS_EXAMPLE}" "${CREDS}"
  warn "Completá ${CREDS} con tu client_id y client_secret y volvé a correr el script."
  warn "Para Google Drive: https://rclone.org/drive/#making-your-own-client-id"
}

verificar_sin_changeme() {
  local remote="$1" pendientes
  pendientes="$(changeme_pendientes "${remote}")"
  [[ -n "${pendientes}" ]] || return 0
  error "Quedan valores CHANGEME en ${CREDS} para ${remote}:"
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
  . "${CREDS}"
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
  local fallos=0 remote
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
  if [[ ! -f "${CREDS}" ]]; then
    warn "PENDIENTE falta ${CREDS} (se crea desde la plantilla en la corrida real)"
    fallos=$((fallos + 1))
  else
    if [[ "$(stat -c '%a' "${CREDS}")" != "600" ]]; then
      warn "PENDIENTE ${CREDS} no está en modo 600"
      fallos=$((fallos + 1))
    else
      ok "${CREDS} presente y en modo 600"
    fi
  fi
  if ! linger_activo; then
    warn "PENDIENTE sin linger para $(usuario_actual): loginctl enable-linger $(usuario_actual)"
    fallos=$((fallos + 1))
  fi

  for remote in $(remotes_seleccionados); do
    if [[ -f "${CREDS}" ]] && [[ -n "$(changeme_pendientes "${remote}")" ]]; then
      warn "PENDIENTE ${remote}: quedan valores CHANGEME en ${CREDS}"
      fallos=$((fallos + 1))
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
      PROVIDER="${2:-}"
      shift 2 || { error "--provider necesita un valor"; exit 1; }
      ;;
    --provider=*)
      PROVIDER="${1#*=}"
      shift
      ;;
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

if [[ ${CHECK} -eq 1 ]]; then
  revisar
  exit $?
fi

# ---------------------------------------------------------------------------
# Corrida real
# ---------------------------------------------------------------------------
verificar_dependencias
asegurar_credenciales
# Aviso, no error: un usuario puede preferir que el montaje arranque al iniciar
# sesión en lugar de en el boot.
avisar_linger || true

# Se valida todo antes de mutar: con CHANGEME pendientes no se crea ni un
# directorio, no se lanza el OAuth y no se habilita ninguna unidad.
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
info "Verificá con: ./scripts/13-setup-cloud-mounts.sh --check --provider ${PROVIDER}"
