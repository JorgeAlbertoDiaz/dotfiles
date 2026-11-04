#!/usr/bin/env bash
# Spec del instalador de montajes de nube (scripts/13-setup-cloud-mounts.sh).
#
# Verifica con HOME temporal, copia del repo y dobles de rclone/systemctl:
#   S4   copia .credentials.example a ~/.credentials con modo 600, no la
#        sobrescribe en la segunda corrida y aborta en voz alta mientras queden
#        valores CHANGEME (sin habilitar ninguna unidad).
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
trap 'rm -rf "${WORK}"' EXIT

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

  mkdir -p "${HOME_T}" "${BIN_T}" "${WORK}/binsin" "${WORK}/repo/scripts" "${WORK}/repo/config/home"
  crear_doble "${BIN_T}/rclone"
  crear_doble "${BIN_T}/systemctl"
  # PATH sin rclone para el caso "rclone no instalado": sólo las herramientas
  # que el script necesita, con enlaces a los binarios reales.
  local t
  for t in bash grep sed tr stat chmod install mkdir dirname basename cut mountpoint; do
    ln -s "$(command -v "${t}")" "${WORK}/binsin/${t}" 2>/dev/null || true
  done
  crear_doble "${WORK}/binsin/systemctl"

  for f in common.sh 13-setup-cloud-mounts.sh; do
    if [[ -f "${REPO_RAIZ}/scripts/${f}" ]]; then
      cp "${REPO_RAIZ}/scripts/${f}" "${WORK}/repo/scripts/"
    fi
  done
  if [[ -f "${REPO_RAIZ}/config/home/.credentials.example" ]]; then
    cp "${REPO_RAIZ}/config/home/.credentials.example" "${WORK}/repo/config/home/"
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

# Semilla: ~/.credentials ya completada (sin CHANGEME).
sembrar_credenciales() {
  cat > "${HOME_T}/.credentials" <<'CRED'
RCLONE_DRIVE_CLIENT_ID=abc.apps.googleusercontent.com
RCLONE_DRIVE_CLIENT_SECRET=GOCSPX-falso
CRED
  chmod 600 "${HOME_T}/.credentials"
}

# ---------------------------------------------------------------------------
# 1) --help
# ---------------------------------------------------------------------------
nuevo_entorno
corre --help
assert_exit "${RC}" 0 "--help sale 0"
assert_contiene "--provider" "${OUT}" "--help documenta --provider"
assert_contiene "--check" "${OUT}" "--check documentado en --help"

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
# 4) Primera corrida con la plantilla: copia credenciales (600) y aborta en
#    voz alta por los CHANGEME, sin habilitar unidades.
# ---------------------------------------------------------------------------
nuevo_entorno
sembrar_unidad
corre --provider both
assert_exit "${RC}" 1 "con CHANGEME pendientes sale 1"
assert_existe "${HOME_T}/.credentials" "crea ~/.credentials desde la plantilla"
assert_modo "${HOME_T}/.credentials" 600 "deja ~/.credentials en modo 600"
assert_contiene "CHANGEME" "${OUT}" "el mensaje nombra los CHANGEME pendientes"
assert_no_llamada "systemctl --user daemon-reload" "no recarga systemd si faltan secretos"
assert_sin_llamadas '^systemctl --user enable' "no habilita unidades si faltan secretos"
assert_sin_llamadas '^rclone config create' "no lanza el OAuth si faltan secretos"

# ---------------------------------------------------------------------------
# 5) Con credenciales y remotes ya creados: idempotente, no repite el OAuth,
#    recarga systemd y habilita ambas unidades en orden.
# ---------------------------------------------------------------------------
nuevo_entorno
sembrar_unidad
sembrar_credenciales
sembrar_remotes gdrive onedrive
corre --provider both
assert_exit "${RC}" 0 "segunda corrida con todo listo sale 0"
assert_sin_llamadas '^rclone config create' "no repite el OAuth si el remote existe"
assert_llamada "systemctl --user daemon-reload" "recarga systemd"
assert_llamada "systemctl --user enable --now rclone@gdrive.service" "habilita gdrive"
assert_llamada "systemctl --user enable --now rclone@onedrive.service" "habilita onedrive"
assert_antes "systemctl --user daemon-reload" "systemctl --user enable --now rclone@gdrive.service" \
  "recarga systemd antes de habilitar"
assert_existe "${HOME_T}/Cloud/gdrive" "crea el punto de montaje de gdrive"
assert_existe "${HOME_T}/Cloud/onedrive" "crea el punto de montaje de onedrive"
assert_contiene "RCLONE_DRIVE_CLIENT_SECRET=GOCSPX-falso" "$(cat "${HOME_T}/.credentials")" \
  "no sobrescribe ~/.credentials existente"

# Segunda corrida real: idempotente, mismo resultado.
corre --provider both
assert_exit "${RC}" 0 "repetir el script sale 0 (idempotente)"
assert_existe "${HOME_T}/Cloud/gdrive" "el punto de montaje sigue existiendo"
assert_contiene "RCLONE_DRIVE_CLIENT_SECRET=GOCSPX-falso" "$(cat "${HOME_T}/.credentials")" \
  "la segunda corrida tampoco toca ~/.credentials"

# ---------------------------------------------------------------------------
# 6) --check con todo listo: sale 0 y no muta nada
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
# 7) --provider inválido
# ---------------------------------------------------------------------------
nuevo_entorno
corre --provider dropbox
assert_exit_no_cero "${RC}" "--provider inválido sale distinto de 0"
assert_contiene "gdrive|onedrive|both" "${OUT}" "--provider inválido lista los valores válidos"

# ---------------------------------------------------------------------------
# 8) Multi-usuario (S13): dos HOMEs no se pisan entre sí
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
  printf '# marca-de-%s\n' "${h##*/}" >> "${h}/.credentials"
done
antes_a="$(find "${HOME_A}" -printf '%p %m %s\n' | sort)"
HOME_T="${HOME_B}"
corre --provider gdrive
assert_exit "${RC}" 0 "segundo usuario corre el script sin errores"
assert_existe "${HOME_A}/.credentials" "el usuario A conserva su ~/.credentials"
assert_existe "${HOME_B}/.credentials" "el usuario B crea el suyo propio"
assert_existe "${HOME_B}/Cloud/gdrive" "B tiene su propio punto de montaje"
if grep -Fq '# marca-de-home-b' "${HOME_A}/.credentials"; then
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
