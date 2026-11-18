#!/usr/bin/env bash
# 14-setup-samba: publica una carpeta (por defecto ~/Projects de tu usuario)
# por SMB/CIFS para un único usuario del sistema.
#
# Uso: 14-setup-samba.sh [--share RUTA] [--name NOMBRE] [--user USUARIO]
#                        [--check] [--force] [--no-firewall] [--quiet]
#   --share        carpeta a compartir (por defecto ~/Projects del usuario)
#   --name         nombre del share en la red (por defecto projects)
#   --user         único usuario autorizado (por defecto, el que corre el script)
#   --check        sólo lectura: informa el estado y sale 1 si falta algo
#   --force        sobrescribe un smb.conf que este script no gestiona; deja
#                  un respaldo smb.conf.bak.<fecha> al lado del original
#   --no-firewall  no abre el servicio samba en firewalld
#   --quiet        suprime info/ok (warn/error siempre salen)
#
# Qué hace, en orden: verifica que samba esté instalado, valida el usuario y la
# carpeta, escribe un smb.conf gestionado (con `valid users` y
# `map to guest = Never`), lo valida con testparm antes de instalarlo,
# habilita/recarga el servicio smb, abre el servicio samba en firewalld y, si
# hay terminal, crea el usuario de Samba con `smbpasswd -a`.
#
# Qué NO hace: no instala paquetes (los declara packages/samba.txt y verifica),
# no guarda la contraseña de Samba en ningún lado (la escribís vos en
# `smbpasswd`) y no toca la carpeta compartida ni sus permisos.
#
# Ver docs/samba.md.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

# Rutas y servicio se pueden redefinir para probar el script aislado
# (scripts/tests/14-setup-samba-spec.sh usa un smb.conf temporal).
readonly SMB_CONF="${SMB_CONF:-/etc/samba/smb.conf}"
readonly SMB_SERVICE="${SMB_SERVICE:-smb}"
readonly MARCA="# gestionado por dotfiles (scripts/14-setup-samba.sh)"
# Los binarios de samba no siempre están en el PATH del usuario: openSUSE deja
# smbd en /usr/sbin, que no está en el PATH de una sesión normal. Se busca con
# command -v y, si no aparece, en estos directorios (redefinible en la spec).
readonly SMB_SBIN_DIRS="${SMB_SBIN_DIRS:-/usr/sbin /sbin /usr/local/sbin /usr/bin /usr/local/bin}"

# Rutas resueltas de los binarios que se invocan (se llenan en
# verificar_dependencias).
SMB_BIN_TESTPARM=""
SMB_BIN_PDBEDIT=""
SMB_BIN_SMBPASSWD=""

SHARE_DIR=""
SHARE_NAME="${SMB_SHARE_NAME:-projects}"
SHARE_USER="${SMB_USER:-${SUDO_USER:-${USER}}}"
CHECK=0
FORCE=0
FIREWALL=1

usage() {
  local nombre="${BASH_SOURCE[0]##*/}"
  printf '%s\n' \
    "Uso: ${nombre} [--share RUTA] [--name NOMBRE] [--user USUARIO]" \
    "                [--check] [--force] [--no-firewall] [--quiet]" \
    "" \
    "  --share RUTA    carpeta a compartir (por defecto ~/Projects del usuario)" \
    "  --name NOMBRE   nombre del share en la red (por defecto projects)" \
    "  --user USUARIO  único usuario autorizado (por defecto, el que corre)" \
    "  --check         sólo lectura: informa el estado y sale 1 si falta algo" \
    "  --force         sobrescribe un smb.conf ajeno, con respaldo previo" \
    "  --no-firewall   no abre el servicio samba en firewalld" \
    "  --quiet         suprime info/ok (warn/error siempre salen)" \
    "" \
    "Publica la carpeta completa con lectura y escritura, sólo para ese" \
    "usuario. Ver docs/samba.md."
}

# ---------------------------------------------------------------------------
# Verificaciones previas
# ---------------------------------------------------------------------------
ruta_bin() {
  local bin="$1" ruta dir
  ruta="$(command -v "${bin}" 2>/dev/null || true)"
  if [[ -n "${ruta}" ]]; then
    printf '%s\n' "${ruta}"
    return 0
  fi
  for dir in ${SMB_SBIN_DIRS}; do
    if [[ -x "${dir}/${bin}" ]]; then
      printf '%s\n' "${dir}/${bin}"
      return 0
    fi
  done
  return 1
}

verificar_dependencias() {
  local faltan=() bin ruta
  for bin in smbd testparm pdbedit smbpasswd; do
    if ! ruta="$(ruta_bin "${bin}")"; then
      faltan+=("${bin}")
      continue
    fi
    case "${bin}" in
      testparm)  SMB_BIN_TESTPARM="${ruta}" ;;
      pdbedit)   SMB_BIN_PDBEDIT="${ruta}" ;;
      smbpasswd) SMB_BIN_SMBPASSWD="${ruta}" ;;
    esac
  done
  if [[ ${#faltan[@]} -gt 0 ]]; then
    error "falta el paquete samba (${faltan[*]})."
    error "Instalalo con: sudo zypper in samba"
    error "o elegí el componente «Samba» de install.sh (packages/samba.txt)."
    return 1
  fi
}

home_del_usuario() {
  local home
  home="$(getent passwd "$1" 2>/dev/null | cut -d: -f6)"
  [[ -n "${home}" ]] || home="${HOME}"
  printf '%s\n' "${home}"
}

resolver_usuario_y_carpeta() {
  if ! id -u "${SHARE_USER}" >/dev/null 2>&1; then
    error "el usuario «${SHARE_USER}» no existe en el sistema."
    return 1
  fi
  if [[ -z "${SHARE_DIR}" ]]; then
    SHARE_DIR="$(home_del_usuario "${SHARE_USER}")/Projects"
  fi
  SHARE_DIR="${SHARE_DIR%/}"
  if [[ ! -d "${SHARE_DIR}" ]]; then
    error "la carpeta a compartir no existe: ${SHARE_DIR}"
    return 1
  fi
}

# ---------------------------------------------------------------------------
# Configuración gestionada
# ---------------------------------------------------------------------------
# El archivo completo lo escribe este script: es más fácil de auditar que un
# fragmento incluido, y la marca del encabezado permite distinguir un smb.conf
# propio (que nunca se pisa sin --force).
generar_config() {
  cat <<EOF
${MARCA}
# No editar a mano: se regenera al correr el script. Si necesitás un smb.conf
# propio, corré el script con --force (deja un respaldo) o no uses este
# componente. La contraseña de Samba no vive acá: la define smbpasswd.
[global]
   workgroup = WORKGROUP
   server string = %h (dotfiles)
   server role = standalone server
   security = user
   passdb backend = tdbsam
   map to guest = Never
   usershare allow guests = no
   load printers = no
   printing = bsd
   printcap name = /dev/null
   disable spoolss = yes
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   server min protocol = SMB2_10

[${SHARE_NAME}]
   comment = ${SHARE_DIR##*/} de ${SHARE_USER}
   path = ${SHARE_DIR}
   browseable = yes
   read only = no
   guest ok = no
   valid users = ${SHARE_USER}
   create mask = 0664
   directory mask = 0775
   follow symlinks = yes
   wide links = no
EOF
}

config_gestionada() {
  # La marca tiene que ser la primera línea: un smb.conf propio que sólo
  # mencione el texto en otra parte sigue siendo ajeno y necesita --force.
  [[ -f "${SMB_CONF}" ]] && [[ "$(head -n 1 "${SMB_CONF}")" == "${MARCA}" ]]
}

config_al_dia() {
  config_gestionada && [[ "$(cat "${SMB_CONF}")" == "$(generar_config)" ]]
}

# El archivo que deja el paquete samba (openSUSE: smb.conf + lmhosts) no es una
# configuración propia: trae [homes], [profiles], [users] y
# `map to guest = Bad User`. Si nadie lo editó, reemplazarlo es seguro y no
# necesita --force; si tiene cambios locales, sí.
config_paquete_intacta() {
  local salida
  command -v rpm >/dev/null 2>&1 || return 1
  rpm -qf "${SMB_CONF}" >/dev/null 2>&1 || return 1
  salida="$(rpm -Vf "${SMB_CONF}" 2>/dev/null || true)"
  [[ "${salida}" != *"${SMB_CONF}"* ]]
}

# escribir_config -> 0 si escribió, 1 si ya estaba al día, 2 si abortó.
escribir_config() {
  local deseado tmp respaldo
  deseado="$(generar_config)"

  if config_al_dia; then
    ok "${SMB_CONF} ya está al día"
    return 1
  fi

  if [[ -f "${SMB_CONF}" ]] && ! config_gestionada; then
    if config_paquete_intacta; then
      warn "${SMB_CONF} es el archivo por defecto del paquete samba, sin cambios."
      warn "Lo reemplazo: el de openSUSE comparte los homes ([homes]) y acepta"
      warn "invitados; el gestionado publica sólo ${SHARE_DIR}."
    elif [[ ${FORCE} -ne 1 ]]; then
      error "${SMB_CONF} existe y no lo gestiona este script: no lo toco."
      error "Revisalo a mano o corré de nuevo con --force (deja un respaldo)."
      return 2
    else
      respaldo="${SMB_CONF}.bak.$(date +%Y%m%d-%H%M%S)"
      como_root "respaldar ${SMB_CONF}" cp -p "${SMB_CONF}" "${respaldo}" || return 2
      warn "respaldo del smb.conf anterior en ${respaldo}"
    fi
  fi

  tmp="$(mktemp "${TMPDIR:-/tmp}/smb.conf.XXXXXX")"
  printf '%s\n' "${deseado}" > "${tmp}"
  if ! "${SMB_BIN_TESTPARM}" -s --suppress-prompt "${tmp}" >/dev/null 2>&1; then
    rm -f "${tmp}"
    error "testparm rechaza la configuración generada: no la instalo."
    return 2
  fi
  local destino_dir
  destino_dir="$(dirname "${SMB_CONF}")"
  if ! como_root "crear ${destino_dir}" mkdir -p "${destino_dir}"; then
    rm -f "${tmp}"
    return 2
  fi
  if ! como_root "escribir ${SMB_CONF}" install -m 0644 "${tmp}" "${SMB_CONF}"; then
    rm -f "${tmp}"
    return 2
  fi
  rm -f "${tmp}"
  ok "${SMB_CONF} escrito: share «${SHARE_NAME}» de ${SHARE_DIR}, sólo ${SHARE_USER}"
  return 0
}

# Ejecuta un paso privilegiado y, si falla, dice qué se intentaba y por qué
# puede haber fallado (sudo sin credenciales es el caso más común cuando el
# script se corre sin terminal).
como_root() {
  local descripcion="$1"
  shift
  if as_root "$@"; then
    return 0
  fi
  error "no pude ${descripcion}."
  error "¿sudo sin credenciales? Corré el script en una terminal donde sudo ande."
  return 1
}

# ---------------------------------------------------------------------------
# Servicio y firewall
# ---------------------------------------------------------------------------
servicio_habilitado() {
  systemctl is-enabled "${SMB_SERVICE}" >/dev/null 2>&1
}

aplicar_servicio() {
  local cambios="$1"
  if ! servicio_habilitado; then
    como_root "habilitar ${SMB_SERVICE}" systemctl enable --now "${SMB_SERVICE}" || return 1
    ok "servicio ${SMB_SERVICE} habilitado y arrancado"
  elif [[ ${cambios} -eq 0 ]]; then
    como_root "reiniciar ${SMB_SERVICE}" systemctl restart "${SMB_SERVICE}" || return 1
    ok "servicio ${SMB_SERVICE} reiniciado para aplicar la configuración"
  else
    ok "servicio ${SMB_SERVICE} ya habilitado"
  fi
}

# permitido | pendiente | detenido | omitido | desconocido
estado_firewall() {
  if [[ ${FIREWALL} -ne 1 ]] || ! command -v firewall-cmd >/dev/null 2>&1; then
    printf 'omitido\n'
    return 0
  fi
  local estado
  estado="$(as_root firewall-cmd --state 2>/dev/null || true)"
  if [[ -z "${estado}" ]]; then
    # Sin credenciales de sudo la consulta no responde: no es lo mismo que
    # "firewalld no corre", y confundirlos esconde un share sin abrir.
    printf 'desconocido\n'
    return 0
  fi
  if [[ "${estado}" != "running" ]]; then
    printf 'detenido\n'
    return 0
  fi
  if as_root firewall-cmd --permanent --query-service=samba >/dev/null 2>&1; then
    printf 'permitido\n'
  else
    printf 'pendiente\n'
  fi
}

aplicar_firewall() {
  case "$(estado_firewall)" in
    permitido)
      ok "el firewall ya permite el servicio samba"
      ;;
    omitido)
      info "firewall: omitido (--no-firewall o sin firewall-cmd)"
      ;;
    detenido)
      warn "firewalld no está corriendo: no toco el firewall"
      ;;
    desconocido)
      warn "no pude consultar el firewall (¿sudo sin credenciales?): no lo toco"
      warn "Repetí el script en una terminal donde sudo no pida contraseña."
      ;;
    *)
      como_root "abrir el servicio samba en el firewall" \
        firewall-cmd --permanent --add-service=samba || return 1
      como_root "recargar el firewall" firewall-cmd --reload || return 1
      ok "firewall: servicio samba habilitado (puertos 139/445)"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Usuario de Samba
# ---------------------------------------------------------------------------
# 0 = existe, 1 = no existe, 2 = no se pudo consultar.
# La base de passdb (/var/lib/samba/private/passdb.tdb) sólo la abre root: sin
# sudo, `pdbedit -L` sale 0 con la lista vacía y daría un falso negativo.
estado_usuario_samba() {
  local salida rc
  salida="$(as_root "${SMB_BIN_PDBEDIT}" -L 2>&1)"
  rc=$?
  [[ ${rc} -eq 0 ]] || return 2
  case "${salida}" in
    *[Ff]ailed*) return 2 ;;
  esac
  printf '%s\n' "${salida}" \
    | awk -F: -v u="${SHARE_USER}" '$1 == u { encontrado = 1 } END { exit encontrado ? 0 : 1 }'
}

asegurar_usuario_samba() {
  local estado
  if estado_usuario_samba; then estado=0; else estado=$?; fi
  case "${estado}" in
    0)
      ok "usuario de Samba «${SHARE_USER}» ya existe"
      return 0
      ;;
    2)
      warn "no pude verificar el usuario de Samba (¿sudo sin credenciales?)"
      warn "Comprobalo con: sudo pdbedit -L"
      return 0
      ;;
  esac
  if [[ ! -t 0 || ! -t 1 ]]; then
    warn "falta el usuario de Samba «${SHARE_USER}»."
    warn "Creálo una sola vez con: sudo smbpasswd -a ${SHARE_USER}"
    return 0
  fi
  info "creando el usuario de Samba «${SHARE_USER}» (te pide la contraseña)"
  if como_root "crear el usuario de Samba «${SHARE_USER}»" \
      "${SMB_BIN_SMBPASSWD}" -a "${SHARE_USER}"; then
    ok "usuario de Samba «${SHARE_USER}» creado"
  else
    warn "Repetilo a mano: sudo smbpasswd -a ${SHARE_USER}"
  fi
}

# ---------------------------------------------------------------------------
# Modo --check (sólo lectura)
# ---------------------------------------------------------------------------
revisar() {
  local pendientes=0

  if config_al_dia; then
    ok "smb.conf: gestionado y al día"
  elif config_gestionada; then
    warn "smb.conf: existe pero no coincide con la configuración esperada"
    pendientes=$((pendientes + 1))
  else
    warn "smb.conf: falta la configuración gestionada (${SMB_CONF})"
    pendientes=$((pendientes + 1))
  fi

  if servicio_habilitado; then
    ok "servicio ${SMB_SERVICE}: habilitado"
  else
    warn "servicio ${SMB_SERVICE}: no habilitado"
    pendientes=$((pendientes + 1))
  fi

  case "$(estado_firewall)" in
    permitido) ok "firewall: el servicio samba está permitido" ;;
    omitido)   info "firewall: no aplica (--no-firewall o sin firewall-cmd)" ;;
    detenido)  info "firewall: firewalld no corre, no aplica" ;;
    desconocido)
      warn "firewall: no pude consultar el estado (¿sudo sin credenciales?)"
      pendientes=$((pendientes + 1))
      ;;
    *)
      warn "firewall: el servicio samba no está permitido"
      pendientes=$((pendientes + 1))
      ;;
  esac

  local estado_usuario
  if estado_usuario_samba; then estado_usuario=0; else estado_usuario=$?; fi
  case "${estado_usuario}" in
    0) ok "usuario de Samba: «${SHARE_USER}» existe" ;;
    2)
      warn "usuario de Samba: no pude consultarlo (¿sudo sin credenciales?)"
      pendientes=$((pendientes + 1))
      ;;
    *)
      warn "usuario de Samba: falta «${SHARE_USER}» (sudo smbpasswd -a ${SHARE_USER})"
      pendientes=$((pendientes + 1))
      ;;
  esac

  if [[ ${pendientes} -eq 0 ]]; then
    ok "Todo listo."
    return 0
  fi
  warn "${pendientes} punto(s) pendiente(s)."
  return 1
}

# ---------------------------------------------------------------------------
# Argumentos
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --share)
      [[ $# -ge 2 ]] || { error "--share necesita una ruta"; exit 1; }
      SHARE_DIR="$2"
      shift 2
      ;;
    --share=*) SHARE_DIR="${1#*=}"; shift ;;
    --name)
      [[ $# -ge 2 ]] || { error "--name necesita un valor"; exit 1; }
      SHARE_NAME="$2"
      shift 2
      ;;
    --name=*) SHARE_NAME="${1#*=}"; shift ;;
    --user)
      [[ $# -ge 2 ]] || { error "--user necesita un usuario"; exit 1; }
      SHARE_USER="$2"
      shift 2
      ;;
    --user=*) SHARE_USER="${1#*=}"; shift ;;
    --check) CHECK=1; shift ;;
    --force) FORCE=1; shift ;;
    --no-firewall) FIREWALL=0; shift ;;
    --quiet) export QUIET=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *)
      error "opción desconocida: $1"
      usage >&2
      exit 1
      ;;
  esac
done

# ---------------------------------------------------------------------------
# Principal
# ---------------------------------------------------------------------------
verificar_dependencias
resolver_usuario_y_carpeta

if [[ ${CHECK} -eq 1 ]]; then
  if revisar; then exit 0; else exit 1; fi
fi

cambios=1
if escribir_config; then
  cambios=0
else
  rc=$?
  if [[ ${rc} -ne 1 ]]; then
    exit 1
  fi
fi

aplicar_servicio "${cambios}"
aplicar_firewall
asegurar_usuario_samba

info "Compartido: smb://$(hostname)/${SHARE_NAME}/ (${SHARE_DIR})"
info "Montaje desde otra máquina: smb://$(hostname)/${SHARE_NAME}"
ok "Samba listo."
