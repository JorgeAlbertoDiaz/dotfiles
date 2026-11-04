#!/usr/bin/env bash
# Spec del instalador de montajes de nube (scripts/13-setup-cloud-mounts.sh).
#
# Verifica con HOME temporal, copia del repo y dobles de rclone/systemctl:
#   S4   ~/.credentials es un directorio 700 con <remote>.env (600), las
#        plantillas se generan solas, nada se sobrescribe, --google-json
#        convierte el JSON de Google y se niega a pisar credenciales cargadas,
#        y con CHANGEME pendientes se aborta sin habilitar unidades.
#   S8   --help sale 0, --check es de sólo lectura y, con el remote ya creado,
#        no repite el OAuth: sólo recarga systemd y habilita las unidades.
#   S9   sin rclone instalado falla con el comando exacto de zypper.
#   S12  aislamiento: todo corre sobre HOME temporal y una copia del repo.
#
# Uso: ./scripts/tests/13-setup-cloud-mounts-spec.sh
set -uo pipefail

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAIZ="$(cd "${SPEC_DIR}/../.." && pwd)"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK:?}"' EXIT

pasos=0
fallos=0

pasa()  { pasos=$((pasos + 1)); printf 'PASS  %s\n' "$1"; }
falla() { pasos=$((pasos + 1)); fallos=$((fallos + 1)); printf 'FAIL  %s\n' "$1"; }

assert_exit() {
  if [[ "$1" -eq "$2" ]]; then pasa "$3"; else falla "$3 (exit $1, esperaba $2)"; fi
}

assert_exit_no_cero() {
  if [[ "$1" -ne 0 ]]; then pasa "$2"; else falla "$2 (exit 0, esperaba distinto de 0)"; fi
}

assert_contiene() {
  # $1 = texto buscado, $2 = texto completo, $3 = etiqueta
  if grep -Fq -- "$1" <<<"$2"; then pasa "$3"; else falla "$3 (salida sin '$1')"; fi
}

assert_no_contiene() {
  if grep -Fq -- "$1" <<<"$2"; then falla "$3 (la salida filtra '$1')"; else pasa "$3"; fi
}

assert_existe() {
  if [[ -e "$1" ]]; then pasa "$2"; else falla "$2 (falta $1)"; fi
}

assert_no_existe() {
  if [[ ! -e "$1" ]]; then pasa "$2"; else falla "$2 (existe $1)"; fi
}

assert_modo() {
  if [[ ! -e "$1" ]]; then
    falla "$3 (falta $1)"
    return
  fi
  local m
  m="$(stat -c '%a' "$1")"
  if [[ "${m}" -eq "$2" ]]; then pasa "$3"; else falla "$3 (modo ${m}, esperaba $2)"; fi
}

assert_llamada() {
  if grep -Fxq "$1" "${CALLS_LOG}"; then pasa "$2"; else falla "$2 (falta '$1' en calls.log)"; fi
}

assert_no_llamada() {
  if grep -Fxq "$1" "${CALLS_LOG}"; then falla "$2 (aparece '$1')"; else pasa "$2"; fi
}

assert_sin_llamadas() {
  if grep -Eq "$1" "${CALLS_LOG}"; then
    falla "$2 (hay llamadas: $(grep -E "$1" "${CALLS_LOG}" | tr '\n' ' '))"
  else
    pasa "$2"
  fi
}

assert_antes() {
  local la ld
  la="$(grep -Fnx "$1" "${CALLS_LOG}" | head -1 | cut -d: -f1)"
  ld="$(grep -Fnx "$2" "${CALLS_LOG}" | head -1 | cut -d: -f1)"
  if [[ -n "${la}" && -n "${ld}" && "${la}" -lt "${ld}" ]]; then
    pasa "$3"
  else
    falla "$3 (línea '$1'=${la}, '$2'=${ld})"
  fi
}

# ---------------------------------------------------------------------------
# Fixture: HOME temporal, copia mínima del repo y dobles de rclone/systemctl.
# ---------------------------------------------------------------------------
HOME_T=""
BIN_T=""
PATH_T=""
CALLS_LOG=""

crear_doble() {
  # $1 = ruta del doble
  cat > "$1" <<'DOBLE'
#!/usr/bin/env bash
printf '%s' "$(basename "${0}")" >> "${CALLS_LOG}"
for a in "$@"; do printf ' %s' "${a}" >> "${CALLS_LOG}"; done
printf '\n' >> "${CALLS_LOG}"

case "$(basename "${0}")" in
  rclone)
    # listremotes lee el rclone.conf real del HOME temporal, igual que rclone.
    if [[ "${1:-}" == "listremotes" ]]; then
      conf="${HOME}/.config/rclone/rclone.conf"
      [[ -f "${conf}" ]] || exit 0
      grep -oE '^\[[^]]+\]' "${conf}" | tr -d '[]' | sed 's/$/:/' || true
      exit 0
    fi
    ;;
  systemctl)
    case "${1:-} ${2:-}" in
      "--user is-enabled" | "--user is-active") exit 1 ;;
    esac
    ;;
esac
exit 0
DOBLE
  chmod +x "$1"
}

nuevo_entorno() {
  rm -rf "${WORK:?}/home" "${WORK:?}/bin" "${WORK:?}/binsin" "${WORK:?}/repo"
  HOME_T="${WORK}/home"
  BIN_T="${WORK}/bin"
  PATH_T="${BIN_T}:/usr/bin:/bin"
  CALLS_LOG="${WORK}/calls.log"
  : > "${CALLS_LOG}"
  export CALLS_LOG

  mkdir -p "${HOME_T}" "${BIN_T}" "${WORK}/binsin" "${WORK}/repo/scripts"
  crear_doble "${BIN_T}/rclone"
  crear_doble "${BIN_T}/systemctl"
  # PATH sin rclone para el caso "rclone no instalado": sólo las herramientas
  # que el script necesita, con enlaces a los binarios reales.
  local t
  for t in bash grep sed tr stat chmod install mkdir dirname basename cut mountpoint; do
    ln -s "$(command -v "${t}")" "${WORK}/binsin/${t}" 2>/dev/null || true
  done
  crear_doble "${WORK}/binsin/systemctl"

  if [[ -f "${REPO_RAIZ}/scripts/13-setup-cloud-mounts.sh" ]]; then
    cp "${REPO_RAIZ}/scripts/common.sh" "${WORK}/repo/scripts/"
    cp "${REPO_RAIZ}/scripts/13-setup-cloud-mounts.sh" "${WORK}/repo/scripts/"
  fi
}

# corre [args...] -> deja salida en OUT y código en RC
OUT=""
RC=0
corre() {
  OUT="$(HOME="${HOME_T}" PATH="${PATH1:-${PATH_T}}" "${WORK}/repo/scripts/13-setup-cloud-mounts.sh" "$@" 2>&1)"
  RC=$?
}

# Semilla: plantilla de unidad ya desplegada por 04-setup-dotfiles.sh.
sembrar_unidad() {
  mkdir -p "${HOME_T}/.config/systemd/user"
  : > "${HOME_T}/.config/systemd/user/rclone@.service"
}

# Semilla: rclone.conf con los remotes dados (simula OAuth ya hecho).
sembrar_remotes() {
  mkdir -p "${HOME_T}/.config/rclone"
  : > "${HOME_T}/.config/rclone/rclone.conf"
  local r
  for r in "$@"; do
    printf '[%s]\ntype = %s\n' "${r}" "${r%drive}" >> "${HOME_T}/.config/rclone/rclone.conf"
  done
}

# Semilla: ~/.credentials ya completo (directorio 700 + un env por proveedor).
sembrar_credenciales() {
  mkdir -p "${HOME_T}/.credentials"
  chmod 700 "${HOME_T}/.credentials"
  cat > "${HOME_T}/.credentials/gdrive.env" <<'CRED'
# credenciales de prueba
RCLONE_DRIVE_CLIENT_ID=abc.apps.googleusercontent.com
RCLONE_DRIVE_CLIENT_SECRET=GOCSPX-falso
CRED
  chmod 600 "${HOME_T}/.credentials/gdrive.env"
  printf '# OneDrive usa el client_id embebido de rclone.\n' > "${HOME_T}/.credentials/onedrive.env"
  chmod 600 "${HOME_T}/.credentials/onedrive.env"
}

# Semilla: JSON tal como lo descarga Google Cloud Console.
sembrar_json() {
  # $1 = tipo de cliente ("installed" = Desktop app, "web" = Web application)
  # $2 = ruta de salida
  printf '{"%s": {"client_id": "1234567890-abc.apps.googleusercontent.com", "client_secret": "GOCSPX-desdejson", "redirect_uris": ["http://localhost"]}}\n' \
    "$1" > "$2"
}

# ---------------------------------------------------------------------------
# 1) --help
# ---------------------------------------------------------------------------
nuevo_entorno
corre --help
assert_exit "${RC}" 0 "--help sale 0"
assert_contiene "--provider" "${OUT}" "--help documenta --provider"
assert_contiene "--check" "${OUT}" "--check documentado en --help"
assert_contiene "--google-json" "${OUT}" "--help documenta --google-json"

# ---------------------------------------------------------------------------
# 2) --check es de sólo lectura y reporta lo que falta
# ---------------------------------------------------------------------------
nuevo_entorno
corre --check --provider both
assert_exit_no_cero "${RC}" "--check con HOME vacío sale distinto de 0"
assert_no_existe "${HOME_T}/.credentials" "--check no crea ~/.credentials"
assert_no_existe "${HOME_T}/Cloud" "--check no crea ~/Cloud"
assert_sin_llamadas '^systemctl --user (daemon-reload|enable)' "--check no toca systemd"

# ---------------------------------------------------------------------------
# 3) Sin rclone instalado: falla con el comando exacto
# ---------------------------------------------------------------------------
nuevo_entorno
PATH1="${WORK}/binsin"
corre --provider gdrive
unset PATH1
assert_exit "${RC}" 1 "sin rclone sale 1"
assert_contiene "zypper install" "${OUT}" "sin rclone indica el comando de zypper"
assert_contiene "rclone-bash-completion" "${OUT}" "sin rclone menciona las completions"

# ---------------------------------------------------------------------------
# 4) Primera corrida: genera ~/.credentials/ (700) con un env por proveedor
#    (600), aborta en voz alta por los CHANGEME y no habilita unidades.
# ---------------------------------------------------------------------------
nuevo_entorno
sembrar_unidad
corre --provider both
assert_exit "${RC}" 1 "con CHANGEME pendientes sale 1"
assert_existe "${HOME_T}/.credentials" "crea el directorio ~/.credentials"
assert_modo "${HOME_T}/.credentials" 700 "deja ~/.credentials en modo 700"
assert_existe "${HOME_T}/.credentials/gdrive.env" "crea gdrive.env"
assert_modo "${HOME_T}/.credentials/gdrive.env" 600 "deja gdrive.env en modo 600"
assert_existe "${HOME_T}/.credentials/onedrive.env" "crea onedrive.env"
assert_modo "${HOME_T}/.credentials/onedrive.env" 600 "deja onedrive.env en modo 600"
assert_contiene "CHANGEME" "${OUT}" "el mensaje nombra los CHANGEME pendientes"
assert_no_llamada "systemctl --user daemon-reload" "no recarga systemd si faltan secretos"
assert_sin_llamadas '^systemctl --user enable' "no habilita unidades si faltan secretos"
assert_sin_llamadas '^rclone config create' "no lanza el OAuth si faltan secretos"
assert_no_existe "${HOME_T}/Cloud" "no crea puntos de montaje si faltan secretos"

# Segunda corrida: no sobrescribe el env recién creado (idempotente).
printf '# marca-propia\n' >> "${HOME_T}/.credentials/gdrive.env"
corre --provider both
assert_contiene "# marca-propia" "$(cat "${HOME_T}/.credentials/gdrive.env")" \
  "no sobrescribe un gdrive.env existente"

# 4b) Sólo falta un env: se crea el que falta y el existente queda intacto.
nuevo_entorno
sembrar_unidad
sembrar_remotes gdrive onedrive
mkdir -p "${HOME_T}/.credentials"
chmod 700 "${HOME_T}/.credentials"
printf 'RCLONE_DRIVE_CLIENT_ID=abc\nRCLONE_DRIVE_CLIENT_SECRET=def\n# marca-propia\n' \
  > "${HOME_T}/.credentials/gdrive.env"
chmod 600 "${HOME_T}/.credentials/gdrive.env"
corre --provider both
assert_exit "${RC}" 0 "con un env ya cargado y el otro faltante sale 0"
assert_existe "${HOME_T}/.credentials/onedrive.env" "crea el env que faltaba"
assert_modo "${HOME_T}/.credentials/onedrive.env" 600 "el env nuevo queda en modo 600"
assert_contiene "# marca-propia" "$(cat "${HOME_T}/.credentials/gdrive.env")" \
  "deja intacto el env que ya existía"

# 4c) --provider gdrive sólo crea gdrive.env: no inventa archivos del otro.
nuevo_entorno
sembrar_unidad
sembrar_remotes gdrive
corre --provider gdrive --quiet
assert_existe "${HOME_T}/.credentials/gdrive.env" "con --provider gdrive crea gdrive.env"
assert_no_existe "${HOME_T}/.credentials/onedrive.env" "con --provider gdrive no crea onedrive.env"

# ---------------------------------------------------------------------------
# 5) ~/.credentials como archivo (layout viejo): error de migración
# ---------------------------------------------------------------------------
nuevo_entorno
sembrar_unidad
printf 'RCLONE_DRIVE_CLIENT_ID=x\n' > "${HOME_T}/.credentials"
corre --provider gdrive
assert_exit "${RC}" 1 "con ~/.credentials como archivo sale 1"
assert_contiene "directorio" "${OUT}" "explica que ahora es un directorio"

# ---------------------------------------------------------------------------
# 6) --google-json: convierte el JSON, archiva el original y no filtra el
#    secreto por la salida
# ---------------------------------------------------------------------------
nuevo_entorno
sembrar_unidad
sembrar_remotes gdrive onedrive
sembrar_json installed "${WORK}/client_secret_largo.apps.googleusercontent.com.json"
corre --provider both --google-json "${WORK}/client_secret_largo.apps.googleusercontent.com.json"
assert_exit "${RC}" 0 "con --google-json completo sale 0"
assert_contiene "RCLONE_DRIVE_CLIENT_SECRET=GOCSPX-desdejson" "$(cat "${HOME_T}/.credentials/gdrive.env")" \
  "escribe el client_secret del JSON en gdrive.env"
assert_modo "${HOME_T}/.credentials/gdrive.env" 600 "deja gdrive.env en modo 600"
assert_existe "${HOME_T}/.credentials/gdrive.json" "archiva el JSON con nombre corto"
assert_modo "${HOME_T}/.credentials/gdrive.json" 600 "deja el JSON archivado en modo 600"
assert_no_contiene "GOCSPX-desdejson" "${OUT}" "no imprime el client_secret en la salida"
assert_llamada "systemctl --user enable --now rclone@gdrive.service" "habilita gdrive tras cargar el JSON"

# ---------------------------------------------------------------------------
# 7) --google-json se niega a pisar credenciales ya cargadas y rechaza un
#    cliente *Web application*
# ---------------------------------------------------------------------------
nuevo_entorno
sembrar_unidad
sembrar_credenciales
sembrar_json installed "${WORK}/installed.json"
corre --provider gdrive --google-json "${WORK}/installed.json"
assert_exit "${RC}" 1 "no pisa credenciales ya cargadas"
assert_contiene "no las piso" "${OUT}" "explica que no sobrescribe"
assert_contiene "GOCSPX-falso" "$(cat "${HOME_T}/.credentials/gdrive.env")" \
  "conserva el secreto anterior"

nuevo_entorno
sembrar_unidad
sembrar_json web "${WORK}/web.json"
corre --provider gdrive --google-json "${WORK}/web.json"
assert_exit "${RC}" 1 "rechaza un cliente Web application"
assert_contiene "Desktop app" "${OUT}" "explica que hace falta Desktop app"

# ---------------------------------------------------------------------------
# 8) --check no se combina con --google-json
# ---------------------------------------------------------------------------
nuevo_entorno
corre --check --provider gdrive --google-json "${WORK}/installed.json"
assert_exit_no_cero "${RC}" "--check con --google-json sale distinto de 0"

# ---------------------------------------------------------------------------
# 9) Con credenciales y remotes ya creados: idempotente, no repite el OAuth,
#    recarga systemd y habilita ambas unidades en orden.
# ---------------------------------------------------------------------------
nuevo_entorno
sembrar_unidad
sembrar_credenciales
sembrar_remotes gdrive onedrive
corre --provider both
assert_exit "${RC}" 0 "corrida con todo listo sale 0"
assert_sin_llamadas '^rclone config create' "no repite el OAuth si el remote existe"
assert_llamada "systemctl --user daemon-reload" "recarga systemd"
assert_llamada "systemctl --user enable --now rclone@gdrive.service" "habilita gdrive"
assert_llamada "systemctl --user enable --now rclone@onedrive.service" "habilita onedrive"
assert_antes "systemctl --user daemon-reload" "systemctl --user enable --now rclone@gdrive.service" \
  "recarga systemd antes de habilitar"
assert_existe "${HOME_T}/Cloud/gdrive" "crea el punto de montaje de gdrive"
assert_existe "${HOME_T}/Cloud/onedrive" "crea el punto de montaje de onedrive"
assert_contiene "RCLONE_DRIVE_CLIENT_SECRET=GOCSPX-falso" "$(cat "${HOME_T}/.credentials/gdrive.env")" \
  "no sobrescribe gdrive.env existente"

# Segunda corrida real: idempotente, mismo resultado.
corre --provider both
assert_exit "${RC}" 0 "repetir el script sale 0 (idempotente)"
assert_existe "${HOME_T}/Cloud/gdrive" "el punto de montaje sigue existiendo"
assert_contiene "RCLONE_DRIVE_CLIENT_SECRET=GOCSPX-falso" "$(cat "${HOME_T}/.credentials/gdrive.env")" \
  "la segunda corrida tampoco toca gdrive.env"

# ---------------------------------------------------------------------------
# 10) --check con todo listo: sale 0 y no muta nada
# ---------------------------------------------------------------------------
nuevo_entorno
sembrar_unidad
sembrar_credenciales
sembrar_remotes gdrive onedrive
mkdir -p "${HOME_T}/Cloud/gdrive" "${HOME_T}/Cloud/onedrive"
antes="$(find "${HOME_T}" -printf '%p %m %s\n' | sort)"
corre --check --provider both
despues="$(find "${HOME_T}" -printf '%p %m %s\n' | sort)"
if [[ "${antes}" == "${despues}" ]]; then
  pasa "--check con todo listo no muta el HOME"
else
  falla "--check con todo listo mutó el HOME"
fi
assert_sin_llamadas '^systemctl --user (daemon-reload|enable)' "--check no habilita nada"

# ---------------------------------------------------------------------------
# 11) --provider inválido
# ---------------------------------------------------------------------------
nuevo_entorno
corre --provider dropbox
assert_exit_no_cero "${RC}" "--provider inválido sale distinto de 0"
assert_contiene "gdrive|onedrive|both" "${OUT}" "--provider inválido lista los valores válidos"

# ---------------------------------------------------------------------------
# 12) Multi-usuario (S13): dos HOMEs no se pisan entre sí
# ---------------------------------------------------------------------------
nuevo_entorno
HOME_A="${HOME_T}"
HOME_B="${WORK}/home-b"
mkdir -p "${HOME_B}"
for h in "${HOME_A}" "${HOME_B}"; do
  HOME_T="${h}"
  sembrar_unidad
  sembrar_credenciales
  sembrar_remotes gdrive onedrive
  HOME="${h}" CALLS_LOG="${CALLS_LOG}" PATH="${PATH_T}" \
    "${WORK}/repo/scripts/13-setup-cloud-mounts.sh" --provider gdrive --quiet >/dev/null 2>&1
  printf '# marca-de-%s\n' "${h##*/}" >> "${h}/.credentials/gdrive.env"
done
antes_a="$(find "${HOME_A}" -printf '%p %m %s\n' | sort)"
HOME_T="${HOME_B}"
corre --provider gdrive
assert_exit "${RC}" 0 "segundo usuario corre el script sin errores"
assert_existe "${HOME_A}/.credentials/gdrive.env" "el usuario A conserva su gdrive.env"
assert_existe "${HOME_B}/.credentials/gdrive.env" "el usuario B crea el suyo propio"
assert_existe "${HOME_B}/Cloud/gdrive" "B tiene su propio punto de montaje"
if grep -Fq '# marca-de-home-b' "${HOME_A}/.credentials/gdrive.env"; then
  falla "B no escribe en las credenciales de A"
else
  pasa "B no escribe en las credenciales de A"
fi
if [[ "${antes_a}" == "$(find "${HOME_A}" -printf '%p %m %s\n' | sort)" ]]; then
  pasa "la corrida de B no toca el HOME de A"
else
  falla "la corrida de B tocó el HOME de A"
fi
if grep -Fxq "systemctl --user enable --now rclone@gdrive.service" "${CALLS_LOG}"; then
  pasa "cada usuario habilita su propia unidad rclone@gdrive.service"
else
  falla "cada usuario habilita su propia unidad rclone@gdrive.service"
fi

printf '\n%s pasos, %s fallos\n' "${pasos}" "${fallos}"
[[ ${fallos} -eq 0 ]]
