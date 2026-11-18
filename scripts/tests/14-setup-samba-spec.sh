#!/usr/bin/env bash
# Spec del componente Samba (scripts/14-setup-samba.sh).
#
# Corre sobre HOME temporal, una copia del repo y dobles en PATH
# (sudo, smbd, testparm, pdbedit, smbpasswd, systemctl, firewall-cmd), así que
# no toca /etc/samba, ni el servicio smb, ni el firewall reales.
#
#   S1   publica la carpeta completa con lectura y escritura, navegable, y el
#        share se llama como se pide (--name/--share).
#   S2   sólo el usuario pedido: valid users, map to guest = Never, guest ok,
#        y se niega con un usuario que no existe en el sistema.
#   S3   idempotencia, marca de archivo gestionado, respaldo con --force,
#        testparm antes de instalar, --check de sólo lectura, --no-firewall.
#
# Uso: ./scripts/tests/14-setup-samba-spec.sh
set -uo pipefail

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAIZ="$(cd "${SPEC_DIR}/../.." && pwd)"

USUARIO_REAL="$(id -un)"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK:?}"' EXIT

pasos=0
fallos=0

pasa()  { pasos=$((pasos + 1)); printf 'PASS  %s\n' "$1"; }
falla() { pasos=$((pasos + 1)); fallos=$((fallos + 1)); printf 'FAIL  %s\n' "$1"; }

assert_exit() {
  if [[ "$1" -eq "$2" ]]; then pasa "$3"; else falla "$3 (exit $1, esperaba $2)"; fi
}

assert_contiene() {
  if grep -qF -- "$2" "$1" 2>/dev/null; then pasa "$3"; else falla "$3 (falta «$2» en $1)"; fi
}

assert_no_contiene() {
  if grep -qF -- "$2" "$1" 2>/dev/null; then falla "$3 (sobra «$2» en $1)"; else pasa "$3"; fi
}

assert_existe() {
  if [[ -e "$1" ]]; then pasa "$2"; else falla "$2 (no existe $1)"; fi
}

assert_no_existe() {
  if [[ -e "$1" ]]; then falla "$2 (existe $1)"; else pasa "$2"; fi
}

assert_modo() {
  local modo
  modo="$(stat -c '%a' "$1" 2>/dev/null)"
  if [[ "${modo}" == "$2" ]]; then pasa "$3"; else falla "$3 (modo ${modo:-?}, esperaba $2)"; fi
}

assert_llamada() {
  if grep -qF -- "$2" "${CALLS_LOG}" 2>/dev/null; then pasa "$1"; else falla "$1 (sin llamada «$2»)"; fi
}

assert_no_llamada() {
  if grep -qF -- "$2" "${CALLS_LOG}" 2>/dev/null; then falla "$1 (llamada inesperada «$2»)"; else pasa "$1"; fi
}

assert_sin_llamadas() {
  if [[ ! -s "${CALLS_LOG}" ]]; then pasa "$1"; else falla "$1 (llamadas: $(tr '\n' ' ' < "${CALLS_LOG}"))"; fi
}

# ---------------------------------------------------------------------------
# Entorno aislado: HOME, PATH con dobles y copia del repo bajo prueba.
# ---------------------------------------------------------------------------
crear_dobles() {
  mkdir -p "${BIN_T}"
  cat > "${BIN_T}/sudo" <<'DOBLE'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >> "${CALLS_LOG}"
if [[ "${SUDO_FALLA:-0}" == "1" ]]; then
  echo "sudo: a password is required" >&2
  exit 1
fi
exec "$@"
DOBLE
  cat > "${BIN_T}/smbd" <<'DOBLE'
#!/usr/bin/env bash
printf 'smbd %s\n' "$*" >> "${CALLS_LOG}"
exit 0
DOBLE
  cat > "${BIN_T}/testparm" <<'DOBLE'
#!/usr/bin/env bash
printf 'testparm %s\n' "$*" >> "${CALLS_LOG}"
if [[ "${TESTPARM_FALLA:-0}" == "1" ]]; then
  echo "Load smb config files from $*" >&2
  echo "Error loading services." >&2
  exit 1
fi
echo "Loaded services file OK."
exit 0
DOBLE
  cat > "${BIN_T}/rpm" <<'DOBLE'
#!/usr/bin/env bash
printf 'rpm %s\n' "$*" >> "${CALLS_LOG}"
case "${1:-}" in
  -qf) [[ "${RPM_SIN_DUENO:-0}" == "1" ]] && exit 1
       echo "samba-client-4.25.1.x86_64"; exit 0 ;;
  -Vf) if [[ "${RPM_INTACTO:-0}" == "1" ]]; then
         # el rpm real también reporta otros paths del paquete, no el smb.conf
         echo ".M.......  g /var/samba"
         exit 1
       fi
       echo "S.5....T.  c ${2:-/etc/samba/smb.conf}"
       exit 1 ;;
esac
exit 0
DOBLE
  cat > "${BIN_T}/pdbedit" <<'DOBLE'
#!/usr/bin/env bash
printf 'pdbedit %s\n' "$*" >> "${CALLS_LOG}"
case "${1:-}" in
  -L) [[ -n "${PDB_FILE:-}" && -f "${PDB_FILE}" ]] && cat "${PDB_FILE}"; exit 0 ;;
esac
exit 0
DOBLE
  cat > "${BIN_T}/smbpasswd" <<'DOBLE'
#!/usr/bin/env bash
printf 'smbpasswd %s\n' "$*" >> "${CALLS_LOG}"
if [[ "${1:-}" == "-a" && -n "${PDB_FILE:-}" && -n "${2:-}" ]]; then
  printf '%s:1000:XXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXX:[U          ]:LCT-00000000:%s\n' \
    "$2" "$2" >> "${PDB_FILE}"
fi
exit 0
DOBLE
  cat > "${BIN_T}/systemctl" <<'DOBLE'
#!/usr/bin/env bash
printf 'systemctl %s\n' "$*" >> "${CALLS_LOG}"
case "${1:-}" in
  is-enabled) if [[ -f "${SVC_FILE:-}" ]]; then cat "${SVC_FILE}"; exit 0; else echo disabled; exit 1; fi ;;
  is-active)  if [[ -f "${SVC_FILE:-}" ]]; then echo active; exit 0; else echo inactive; exit 3; fi ;;
  enable|start|restart|reload) echo enabled > "${SVC_FILE:-/dev/null}"; exit 0 ;;
esac
exit 0
DOBLE
  cat > "${BIN_T}/firewall-cmd" <<'DOBLE'
#!/usr/bin/env bash
printf 'firewall-cmd %s\n' "$*" >> "${CALLS_LOG}"
case "${1:-}" in
  --state) echo running; exit 0 ;;
esac
case "$*" in
  *--query-service=samba*) [[ -f "${FW_FILE:-}" ]] && exit 0; exit 1 ;;
  *--add-service=samba*)   touch "${FW_FILE:-/dev/null}"; exit 0 ;;
  *--reload*)              exit 0 ;;
esac
exit 0
DOBLE
  chmod +x "${BIN_T}"/*
}

sembrar_usuario_samba() {
  printf '%s:1000:XXXXXXXXXXXXXXXX:XXXXXXXXXXXXXXXX:[U          ]:LCT-00000000:\n' \
    "${USUARIO_REAL}" > "${PDB_FILE}"
}

nuevo_entorno() {
  HOME_T="${WORK}/home-$1"
  BIN_T="${WORK}/bin-$1"
  SBIN_T="${WORK}/sbin-$1"
  OUT_T="${WORK}/out-$1.txt"
  CALLS_LOG="${WORK}/calls-$1.log"
  PDB_FILE="${WORK}/pdb-$1.txt"
  SVC_FILE="${WORK}/svc-$1.txt"
  FW_FILE="${WORK}/fw-$1.txt"
  SMB_CONF="${WORK}/smbconf-$1/smb.conf"
  SHARE_DIR="${WORK}/home-$1/Projects"

  mkdir -p "${HOME_T}" "${WORK}/repo-$1/scripts" "$(dirname "${SMB_CONF}")" "${SHARE_DIR}/sub"
  printf 'hola\n' > "${SHARE_DIR}/sub/archivo.txt"
  : > "${CALLS_LOG}"

  cp "${REPO_RAIZ}/scripts/common.sh" "${WORK}/repo-$1/scripts/"
  cp "${REPO_RAIZ}/scripts/14-setup-samba.sh" "${WORK}/repo-$1/scripts/" 2>/dev/null || true

  crear_dobles
}

corre() {
  env HOME="${HOME_T}" \
      PATH="${BIN_T}:${PATH}" \
      SMB_CONF="${SMB_CONF}" \
      SMB_SBIN_DIRS="${SBIN_T}" \
      CALLS_LOG="${CALLS_LOG}" \
      PDB_FILE="${PDB_FILE}" \
      SVC_FILE="${SVC_FILE}" \
      FW_FILE="${FW_FILE}" \
      TESTPARM_FALLA="${TESTPARM_FALLA:-0}" \
      SUDO_FALLA="${SUDO_FALLA:-0}" \
      RPM_INTACTO="${RPM_INTACTO:-0}" \
      RPM_SIN_DUENO="${RPM_SIN_DUENO:-0}" \
      "${WORK}/repo-${CASO}/scripts/14-setup-samba.sh" "$@" > "${OUT_T}" 2>&1
}

# ---------------------------------------------------------------------------
# S1/S2: configuración desde cero
# ---------------------------------------------------------------------------
CASO=desde-cero
nuevo_entorno "${CASO}"
corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}" --name proyectos
assert_exit "$?" 0 "S1: configuración desde cero termina en 0"
assert_existe "${SMB_CONF}" "S1: escribe smb.conf"
assert_modo "${SMB_CONF}" 644 "S1: smb.conf queda 0644 (lo lee smbd sin sudo)"
assert_contiene "${SMB_CONF}" "[proyectos]" "S1: declara la sección del share"
assert_contiene "${SMB_CONF}" "path = ${SHARE_DIR}" "S1: publica la carpeta completa"
assert_contiene "${SMB_CONF}" "read only = no" "S1: lectura y escritura"
assert_contiene "${SMB_CONF}" "browseable = yes" "S1: el share se ve al navegar"
assert_contiene "${SMB_CONF}" "valid users = ${USUARIO_REAL}" "S2: sólo el usuario pedido"
assert_contiene "${SMB_CONF}" "map to guest = Never" "S2: ninguna sesión anónima"
assert_contiene "${SMB_CONF}" "guest ok = no" "S2: invitados rechazados explícitamente"
assert_contiene "${SMB_CONF}" "security = user" "S2: autenticación por usuario de Samba"
assert_llamada "S1: valida la configuración con testparm" "testparm"
assert_llamada "S1: habilita el servicio smb" "systemctl enable"
assert_llamada "S2: agrega el servicio samba al firewall" "--add-service=samba"
assert_llamada "S2: recarga el firewall" "firewall-cmd --reload"
assert_contiene "${OUT_T}" "sudo smbpasswd -a ${USUARIO_REAL}" \
  "S2: sin terminal indica el comando exacto para el usuario de Samba"
assert_no_llamada "S2: sin terminal no intenta pedir la contraseña" "smbpasswd -a"

# ---------------------------------------------------------------------------
# S3: idempotencia (segunda corrida no reescribe ni recrea al usuario)
# ---------------------------------------------------------------------------
cp "${SMB_CONF}" "${WORK}/smbconf-primera.txt"
: > "${CALLS_LOG}"
corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}" --name proyectos
assert_exit "$?" 0 "S3: la segunda corrida termina en 0"
if diff -q "${WORK}/smbconf-primera.txt" "${SMB_CONF}" >/dev/null; then
  pasa "S3: la segunda corrida no cambia smb.conf"
else
  falla "S3: la segunda corrida reescribió smb.conf"
fi
assert_no_llamada "S3: no recrea el usuario de Samba existente" "smbpasswd -a"

# ---------------------------------------------------------------------------
# S2: con el usuario de Samba ya creado no se repite nada
# ---------------------------------------------------------------------------
CASO=usuario-existente
nuevo_entorno "${CASO}"
sembrar_usuario_samba
corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}"
assert_exit "$?" 0 "S2: con el usuario ya creado termina en 0"
assert_no_contiene "${OUT_T}" "smbpasswd -a" \
  "S2: no vuelve a pedir la contraseña del usuario existente"
assert_no_llamada "S2: no recrea un usuario de Samba que ya existe" "smbpasswd -a"
assert_contiene "${OUT_T}" "ya existe" "S2: informa que el usuario ya estaba creado"

# ---------------------------------------------------------------------------
# S3: un smb.conf ajeno no se pisa sin --force
# ---------------------------------------------------------------------------
CASO=ajeno
nuevo_entorno "${CASO}"
printf '[global]\n   workgroup = AJENO\n' > "${SMB_CONF}"
corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}"
assert_exit "$?" 1 "S3: smb.conf ajeno sin marca falla con 1"
assert_contiene "${SMB_CONF}" "workgroup = AJENO" "S3: no pisa un smb.conf ajeno"
assert_no_contiene "${SMB_CONF}" "[projects]" "S3: no agrega su share al archivo ajeno"

corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}" --force
assert_exit "$?" 0 "S3: --force acepta sobrescribir"
assert_contiene "${SMB_CONF}" "[projects]" "S3: --force escribe la configuración gestionada"
respaldo="$(find "$(dirname "${SMB_CONF}")" -maxdepth 1 -name 'smb.conf.bak.*' | head -1)"
if [[ -n "${respaldo}" ]]; then
  pasa "S3: --force respalda el smb.conf anterior"
  assert_contiene "${respaldo}" "workgroup = AJENO" "S3: el respaldo conserva el original"
else
  falla "S3: --force no dejó respaldo del smb.conf anterior"
fi

# ---------------------------------------------------------------------------
# S3: la marca sólo vale en la primera línea (un smb.conf propio que la mencione
#     en otro lado sigue siendo ajeno)
# ---------------------------------------------------------------------------
CASO=marca-tardia
nuevo_entorno "${CASO}"
{
  printf '[global]\n   workgroup = AJENO\n'
  printf '# gestionado por dotfiles (scripts/14-setup-samba.sh)\n'
} > "${SMB_CONF}"
corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}"
assert_exit "$?" 1 "S3: la marca fuera de la primera línea no autoriza pisar el archivo"
assert_no_contiene "${SMB_CONF}" "[projects]" "S3: el smb.conf con la marca tardía queda intacto"

# ---------------------------------------------------------------------------
# S1/S2: --name y --user se reflejan en la configuración
# ---------------------------------------------------------------------------
CASO=otro-usuario
nuevo_entorno "${CASO}"
corre --user root --share "${SHARE_DIR}" --name compartido
assert_exit "$?" 0 "S3: --user root y --name compartido terminan en 0"
assert_contiene "${SMB_CONF}" "[compartido]" "S1: --name define la sección del share"
assert_contiene "${SMB_CONF}" "valid users = root" "S2: --user define el único usuario autorizado"
assert_no_contiene "${SMB_CONF}" "valid users = ${USUARIO_REAL}" \
  "S2: --user no deja además al usuario que corre el script"

# ---------------------------------------------------------------------------
# S3: el smb.conf por defecto del paquete no es del usuario: se reemplaza
#     sin --force, y un archivo ajeno o sin dueño sí exige --force
# ---------------------------------------------------------------------------
CASO=paquete-intacto
nuevo_entorno "${CASO}"
printf '# smb.conf is the main Samba configuration file.\n[global]\n   workgroup = WORKGROUP\n' > "${SMB_CONF}"
RPM_INTACTO=1 corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}"
assert_exit "$?" 0 "S3: el smb.conf por defecto del paquete se reemplaza sin --force"
assert_contiene "${SMB_CONF}" "[projects]" "S3: el reemplazo deja la configuración gestionada"
if find "$(dirname "${SMB_CONF}")" -maxdepth 1 -name 'smb.conf.bak.*' | grep -q .; then
  falla "S3: el archivo por defecto del paquete no necesita respaldo"
else
  pasa "S3: el archivo por defecto del paquete no necesita respaldo"
fi

CASO=paquete-sin-dueno
nuevo_entorno "${CASO}"
printf '[global]\n   workgroup = AJENO\n' > "${SMB_CONF}"
RPM_SIN_DUENO=1 RPM_INTACTO=1 corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}"
assert_exit "$?" 1 "S3: un smb.conf sin dueño de paquete exige --force"
assert_contiene "${SMB_CONF}" "workgroup = AJENO" "S3: no pisa un archivo sin dueño de paquete"

# ---------------------------------------------------------------------------
# S3: testparm inválido aborta antes de instalar
# ---------------------------------------------------------------------------
CASO=testparm-falla
nuevo_entorno "${CASO}"
TESTPARM_FALLA=1 corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}"
assert_exit "$?" 1 "S3: con testparm inválido sale 1"
assert_no_existe "${SMB_CONF}" "S3: no instala un smb.conf que testparm rechaza"
assert_no_llamada "S3: no habilita el servicio si la configuración es inválida" "systemctl enable"

# ---------------------------------------------------------------------------
# S2: usuario inexistente y carpeta inexistente se rechazan
# ---------------------------------------------------------------------------
CASO=usuario-inexistente
nuevo_entorno "${CASO}"
corre --user usuario-que-no-existe --share "${SHARE_DIR}"
assert_exit "$?" 1 "S2: usuario del sistema inexistente sale 1"
assert_no_existe "${SMB_CONF}" "S2: no escribe nada con usuario inválido"

CASO=carpeta-inexistente
nuevo_entorno "${CASO}"
corre --user "${USUARIO_REAL}" --share "${WORK}/no-existe"
assert_exit "$?" 1 "S1: carpeta a compartir inexistente sale 1"
assert_no_existe "${SMB_CONF}" "S1: no escribe nada si falta la carpeta"

# ---------------------------------------------------------------------------
# S3: --check es de sólo lectura y reporta lo que falta
# ---------------------------------------------------------------------------
CASO=check-antes
nuevo_entorno "${CASO}"
corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}" --check
assert_exit "$?" 1 "--check con todo pendiente sale 1"
assert_no_llamada "--check no habilita el servicio" "systemctl enable"
assert_no_llamada "--check no reinicia el servicio" "systemctl restart"
assert_no_llamada "--check no escribe la configuración" "install -m 0644"
assert_no_llamada "--check no abre el firewall" "--add-service=samba"
assert_no_llamada "--check no recarga el firewall" "--reload"
assert_no_llamada "--check no crea el usuario de Samba" "smbpasswd -a"
assert_no_existe "${SMB_CONF}" "--check no escribe smb.conf"

corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}"
sembrar_usuario_samba
: > "${CALLS_LOG}"
corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}" --check
assert_exit "$?" 0 "--check con todo configurado sale 0"
assert_no_llamada "--check no reescribe la configuración" "install -m 0644"
assert_no_llamada "--check no habilita el servicio" "systemctl enable"

# ---------------------------------------------------------------------------
# S3: --no-firewall y ausencia de samba
# ---------------------------------------------------------------------------
CASO=sin-forward
nuevo_entorno "${CASO}"
corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}" --no-firewall
assert_exit "$?" 0 "S3: --no-firewall termina en 0"
assert_no_llamada "S3: --no-firewall no toca el firewall" "firewall-cmd"

CASO=sin-samba
nuevo_entorno "${CASO}"
rm -f "${BIN_T}/smbd" "${BIN_T}/testparm" "${BIN_T}/pdbedit" "${BIN_T}/smbpasswd"
corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}"
assert_exit "$?" 1 "S3: sin paquete samba sale 1"
assert_contiene "${OUT_T}" "zypper in samba" "S3: indica el comando exacto de instalación"
assert_contiene "${OUT_T}" "packages/samba.txt" "S3: nombra el paquete declarado en el repo"
assert_no_existe "${SMB_CONF}" "S3: sin samba no escribe configuración"

# ---------------------------------------------------------------------------
# S3: smbd vive fuera del PATH (openSUSE lo deja en /usr/sbin): el script lo
#     resuelve ahí en vez de decir que samba no está instalado
# ---------------------------------------------------------------------------
CASO=smbd-fuera-del-path
nuevo_entorno "${CASO}"
mkdir -p "${SBIN_T}"
mv "${BIN_T}/smbd" "${SBIN_T}/smbd"
corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}"
assert_exit "$?" 0 "S3: con smbd fuera del PATH no dice que falta samba"
assert_no_contiene "${OUT_T}" "falta el paquete samba" \
  "S3: no reporta el paquete samba como ausente"
assert_existe "${SMB_CONF}" "S3: configura igual con smbd fuera del PATH"

# ---------------------------------------------------------------------------
# S3: sin credenciales de sudo el firewall no se toca y --check no miente
# ---------------------------------------------------------------------------
CASO=sudo-sin-credenciales
nuevo_entorno "${CASO}"
SUDO_FALLA=1 corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}" --check
assert_exit "$?" 1 "S3: --check sin credenciales de sudo sale 1"
assert_contiene "${OUT_T}" "no pude consultar el estado" \
  "S3: --check distingue «no pude consultar» de «no corre»"
assert_no_llamada "S3: --check no abre el firewall sin poder consultarlo" "--add-service=samba"
assert_contiene "${OUT_T}" "no pude consultarlo" \
  "S3: no inventa que falta el usuario de Samba si no pudo consultarlo"

: > "${CALLS_LOG}"
SUDO_FALLA=1 corre --user "${USUARIO_REAL}" --share "${SHARE_DIR}"
assert_exit "$?" 1 "S3: sin sudo la corrida falla con 1 en vez de fingir éxito"
assert_contiene "${OUT_T}" "no pude crear" \
  "S3: dice qué paso privilegiado falló"
assert_contiene "${OUT_T}" "¿sudo sin credenciales?" \
  "S3: explica la causa probable (sudo sin credenciales)"
assert_no_contiene "${OUT_T}" "escrito:" \
  "S3: no anuncia un smb.conf que no pudo escribir"
assert_no_existe "${SMB_CONF}" "S3: sin sudo no queda un smb.conf a medias"
assert_no_llamada "S3: sin sudo no intenta abrir el firewall" "--add-service=samba"

# ---------------------------------------------------------------------------
# S3: --help
# ---------------------------------------------------------------------------
CASO=ayuda
nuevo_entorno "${CASO}"
corre --help
assert_exit "$?" 0 "S3: --help sale 0"
assert_contiene "${OUT_T}" "--share" "S3: --help documenta --share"
assert_contiene "${OUT_T}" "--check" "S3: --help documenta --check"
assert_sin_llamadas "S3: --help no ejecuta nada"

# ---------------------------------------------------------------------------
printf '\n%s pasos, %s fallo(s)\n' "${pasos}" "${fallos}"
[[ ${fallos} -eq 0 ]] || exit 1
