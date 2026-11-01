#!/usr/bin/env bash
# Spec ejecutable de scripts/02b-install-flatpak.sh.
#
# Verifica S2-S7, S10 y S12 del instalador Flatpak con selección:
#   S2/S6  la selección interactiva exige gum + TTY, muestra "appid (instalada)"
#          y mapea las etiquetas de vuelta al appid (nunca instala una etiqueta).
#   S3/S5  --list es de sólo lectura; --all instala todo el catálogo; --apps
#          valida contra el catálogo y falla sin instalar nada si un appid no
#          existe; flags desconocidas o selectores en conflicto muestran uso.
#   S4     --list no requiere flatpak ni toca flathub.
#   S6/S7  flatpak ausente avisa y sale 0; las ya instaladas no se reinstalan y
#          flathub se registra una sola vez y sólo si hay algo por instalar.
#   S12    corre sin root, sin red y sin flatpak real, con stubs que registran.
#
# Uso: ./scripts/tests/02b-install-flatpak-spec.sh
set -uo pipefail

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPTS="$(dirname "${SPEC_DIR}")"
SRC_REPO="$(dirname "${SRC_SCRIPTS}")"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

REPO="${WORK}/repo"
STUBS="${WORK}/stubs"
MIN_BIN="${WORK}/min-bin"
MIN_BIN_NO_GUM="${WORK}/min-bin-no-gum"

OUT="${WORK}/salida.txt"
ERR="${WORK}/errores.txt"
LOG="${WORK}/flatpak.log"
INSTALADAS="${WORK}/instaladas.txt"
SELECCION="${WORK}/seleccion.txt"
PTY_OUT="${WORK}/pty.txt"

RUN_PATH="${STUBS}:${PATH}"

pasos=0
fallos=0

pasa()  { pasos=$((pasos + 1)); printf 'PASS  %s\n' "$1"; }
falla() { pasos=$((pasos + 1)); fallos=$((fallos + 1)); printf 'FAIL  %s\n' "$1"; }

assert_contenido() {
  local real=""
  [[ -f "$1" ]] && real="$(cat "$1")"
  if [[ "${real}" == "$2" ]]; then pasa "$3"; else falla "$3 (contenido: '${real}')"; fi
}

assert_contiene() {
  # $1=archivo  $2=subcadena  $3=descripción
  if [[ -f "$1" ]] && grep -qF -- "$2" "$1"; then
    pasa "$3"
  else
    falla "$3 (no contiene '$2' en $1: '$(cat "$1" 2>/dev/null)')"
  fi
}

# Log compartido de stubs: sólo las líneas de flatpak (las de gum se ignoran).
log_flatpak() {
  [[ -f "${LOG}" ]] || return 0
  grep '^flatpak ' "${LOG}" || true
}

assert_log() {
  local esperado="$1" desc="$2" real
  real="$(log_flatpak)"
  if [[ "${real}" == "${esperado}" ]]; then
    pasa "${desc}"
  else
    falla "${desc} (log flatpak: '${real}' esperado: '${esperado}')"
  fi
}

assert_sin_log() {
  if [[ -z "$(log_flatpak)" ]]; then pasa "$1"; else falla "$1 (log: '$(log_flatpak)')"; fi
}

REMOTE='flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo'

instalacion() { printf 'flatpak install -y --noninteractive --user flathub %s' "$1"; }

# Log esperado: registro del remote + una línea install por appid (en orden).
log_esperado() {
  printf '%s\n' "${REMOTE}"
  local app
  for app in "$@"; do
    printf '%s\n' "$(instalacion "${app}")"
  done
}

CATALOGO_SALIDA=$'io.dbeaver.DBeaverCommunity\ncom.getpostman.Postman\norg.mozilla.Thunderbird\norg.onlyoffice.desktopeditors'

# ---------------------------------------------------------------------------
# Fixture: repo aislado + stubs de flatpak y gum que registran sus llamadas.
# ---------------------------------------------------------------------------
crear_stubs() {
  cat > "${STUBS}/flatpak" <<EOF
#!/usr/bin/env bash
set -uo pipefail
# list --app --columns=application es la consulta de "ya instaladas": se
# responde sin registrarse en el log (las demás invocaciones sí se registran).
if [[ \$# -ge 3 && "\$1" == "list" && "\$2" == "--app" && "\$3" == "--columns=application" ]]; then
  [[ -f "${INSTALADAS}" ]] && cat "${INSTALADAS}"
  exit 0
fi
printf '%s' "\${0##*/}" >> "${LOG}"
for a in "\$@"; do printf ' %s' "\${a}" >> "${LOG}"; done
printf '\n' >> "${LOG}"
exit 0
EOF

  cat > "${STUBS}/gum" <<EOF
#!/usr/bin/env bash
set -uo pipefail
printf '%s' "\${0##*/}" >> "${LOG}"
for a in "\$@"; do printf ' %s' "\${a}" >> "${LOG}"; done
printf '\n' >> "${LOG}"
if [[ "\$1" == "choose" ]]; then
  [[ -f "${SELECCION}" ]] && cat "${SELECCION}"
fi
exit 0
EOF
  chmod +x "${STUBS}/flatpak" "${STUBS}/gum"

  # Para "sin gum pero con flatpak": binarios mínimos + el stub flatpak.
  cp "${STUBS}/flatpak" "${MIN_BIN_NO_GUM}/flatpak"
}

crear_fixture() {
  rm -rf "${REPO}" "${STUBS}" "${MIN_BIN}" "${MIN_BIN_NO_GUM}"
  mkdir -p "${REPO}/scripts" "${REPO}/packages" "${STUBS}" "${MIN_BIN}" "${MIN_BIN_NO_GUM}"
  cp "${SRC_SCRIPTS}/02b-install-flatpak.sh" "${REPO}/scripts/"
  cp "${SRC_SCRIPTS}/common.sh" "${REPO}/scripts/"
  chmod +x "${REPO}/scripts/02b-install-flatpak.sh"

  # Binarios mínimos (bash, dirname, cat, timeout) SIN flatpak ni gum: para el
  # caso "flatpak no instalado" de forma determinista aunque el sistema lo tenga.
  local tool t
  for tool in bash dirname cat timeout; do
    t="$(command -v "${tool}")"
    ln -s "${t}" "${MIN_BIN}/${tool}"
    ln -s "${t}" "${MIN_BIN_NO_GUM}/${tool}"
  done

  crear_stubs
}

nueva_corrida() {
  rm -f "${OUT}" "${ERR}" "${LOG}" "${INSTALADAS}" "${SELECCION}" "${PTY_OUT}"
  RUN_PATH="${STUBS}:${PATH}"
  mkdir -p "${REPO}/packages"
  cp "${SRC_REPO}/packages/flatpak-apps.txt" "${REPO}/packages/flatpak-apps.txt"
  # Línea en blanco y comentario extra: --list debe ignorarlos.
  printf '\n# comentario extra que se ignora\n\n' >> "${REPO}/packages/flatpak-apps.txt"
}

if ! command -v timeout >/dev/null 2>&1; then
  echo "ERROR: se necesita 'timeout' para que un prompt accidental no cuelgue el spec." >&2
  exit 2
fi
if ! command -v script >/dev/null 2>&1; then
  echo "ERROR: se necesita 'script' (util-linux) para simular una TTY." >&2
  exit 2
fi

# Corre el script sin TTY (stdin desde /dev/null); deja OUT/ERR y devuelve rc.
run_flatpak() {
  (
    cd "${WORK}" || exit 99
    PATH="${RUN_PATH}" timeout 60 bash "${REPO}/scripts/02b-install-flatpak.sh" "$@" </dev/null >"${OUT}" 2>"${ERR}"
  )
}

# Corre el script bajo un PTY (para que [[ -t 0 && -t 1 ]] sea verdadero).
# run_flatpak_pty permite elegir el PATH (con o sin gum) y alimentar respuestas
# por stdin, que es como el fallback de `confirm` lee las preguntas.
run_flatpak_pty() {
  local path_env="$1" respuestas="${2:-}" cmd
  cmd="cd '${WORK}' && PATH='${path_env}' timeout 60 bash '${REPO}/scripts/02b-install-flatpak.sh'"
  printf '%s' "${respuestas}" | script -qec "${cmd}" "${PTY_OUT}" >/dev/null 2>&1
}

run_flatpak_interactivo() {
  run_flatpak_pty "${STUBS}:${PATH}"
}

crear_fixture

# ---------------------------------------------------------------------------
# Caso 1 — --list es de sólo lectura (S3/S4).
# ---------------------------------------------------------------------------
nueva_corrida
run_flatpak --list
rc=$?
[[ ${rc} -eq 0 ]] && pasa "--list sale 0" || falla "--list sale 0 (exit ${rc})"
assert_contenido "${OUT}" "${CATALOGO_SALIDA}" \
  "--list imprime los cuatro appids e ignora comentarios/líneas en blanco"
assert_sin_log "--list no invoca flatpak"

# ---------------------------------------------------------------------------
# Caso 2 — --all instala el catálogo entero, en orden (S3/S7).
# ---------------------------------------------------------------------------
nueva_corrida
run_flatpak --all
rc=$?
[[ ${rc} -eq 0 ]] && pasa "--all sale 0" || falla "--all sale 0 (exit ${rc})"
assert_log "$(log_esperado io.dbeaver.DBeaverCommunity com.getpostman.Postman org.mozilla.Thunderbird org.onlyoffice.desktopeditors)" \
  "--all registra flathub una vez e instala las cuatro en orden del catálogo"

# ---------------------------------------------------------------------------
# Caso 3 — --apps instala sólo el appid pedido (S3).
# ---------------------------------------------------------------------------
nueva_corrida
run_flatpak --apps org.mozilla.Thunderbird
rc=$?
[[ ${rc} -eq 0 ]] && pasa "--apps Thunderbird sale 0" || falla "--apps Thunderbird sale 0 (exit ${rc})"
assert_log "$(log_esperado org.mozilla.Thunderbird)" \
  "--apps instala sólo ese appid (flathub registrado una vez)"

# ---------------------------------------------------------------------------
# Caso 4 — --apps con un appid fuera del catálogo falla sin instalar (S5).
# ---------------------------------------------------------------------------
nueva_corrida
run_flatpak --apps com.invalida.NoExiste
rc=$?
[[ ${rc} -eq 1 ]] && pasa "--apps inválido sale 1" || falla "--apps inválido sale 1 (exit ${rc})"
assert_contiene "${ERR}" "com.invalida.NoExiste" "--apps inválido nombra el appid en stderr"
assert_sin_log "--apps inválido no instala ni registra nada"

# ---------------------------------------------------------------------------
# Caso 5 — ya instaladas + --all: no se reinstalan (S7).
# ---------------------------------------------------------------------------
nueva_corrida
printf 'io.dbeaver.DBeaverCommunity\norg.mozilla.Thunderbird\n' > "${INSTALADAS}"
run_flatpak --all
rc=$?
[[ ${rc} -eq 0 ]] && pasa "--all con dos instaladas sale 0" || falla "--all con dos instaladas sale 0 (exit ${rc})"
assert_log "$(log_esperado com.getpostman.Postman org.onlyoffice.desktopeditors)" \
  "--all con dos instaladas instala sólo las otras dos, sin reinstalar"

# ---------------------------------------------------------------------------
# Caso 6 — todo instalado + --all: no registra flathub ni instala (S7).
# ---------------------------------------------------------------------------
nueva_corrida
printf 'io.dbeaver.DBeaverCommunity\ncom.getpostman.Postman\norg.mozilla.Thunderbird\norg.onlyoffice.desktopeditors\n' > "${INSTALADAS}"
run_flatpak --all
rc=$?
[[ ${rc} -eq 0 ]] && pasa "--all con todo instalado sale 0" || falla "--all con todo instalado sale 0 (exit ${rc})"
assert_sin_log "--all con todo instalado no registra flathub ni instala"

# ---------------------------------------------------------------------------
# Caso 7 — flatpak no instalado (S6).
# ---------------------------------------------------------------------------
nueva_corrida
RUN_PATH="${MIN_BIN}"
run_flatpak --all
rc=$?
[[ ${rc} -eq 0 ]] && pasa "sin flatpak sale 0" || falla "sin flatpak sale 0 (exit ${rc})"
assert_contiene "${ERR}" "flatpak no instalado — instalalo vía packages/base.txt primero" \
  "sin flatpak avisa con el mensaje exacto en stderr"
assert_sin_log "sin flatpak no registra flathub"

# ---------------------------------------------------------------------------
# Caso 8 — catálogo ausente (S5).
# ---------------------------------------------------------------------------
nueva_corrida
rm -f "${REPO}/packages/flatpak-apps.txt"
run_flatpak --all
rc=$?
[[ ${rc} -eq 1 ]] && pasa "catálogo ausente sale 1" || falla "catálogo ausente sale 1 (exit ${rc})"
assert_contiene "${ERR}" "${REPO}/packages/flatpak-apps.txt" "catálogo ausente nombra la ruta en stderr"
assert_sin_log "catálogo ausente no invoca flatpak"

# ---------------------------------------------------------------------------
# Caso 9 — sin selector y sin gum/TTY (S5).
# ---------------------------------------------------------------------------
nueva_corrida
RUN_PATH="${MIN_BIN_NO_GUM}"
run_flatpak
rc=$?
[[ ${rc} -eq 2 ]] && pasa "sin selector y sin gum/TTY sale 2" || falla "sin selector y sin gum/TTY sale 2 (exit ${rc})"
assert_contiene "${ERR}" "Uso:" "sin selector y sin gum/TTY muestra el uso en stderr"
assert_sin_log "sin selector y sin gum/TTY no invoca flatpak"

# ---------------------------------------------------------------------------
# Caso 10 — interactivo: gum selecciona dos, se instalan en orden (S2/S3).
# ---------------------------------------------------------------------------
nueva_corrida
printf 'com.getpostman.Postman\norg.mozilla.Thunderbird\n' > "${SELECCION}"
run_flatpak_interactivo
rc=$?
[[ ${rc} -eq 0 ]] && pasa "interactivo con dos seleccionadas sale 0" || falla "interactivo con dos seleccionadas sale 0 (exit ${rc})"
assert_log "$(log_esperado com.getpostman.Postman org.mozilla.Thunderbird)" \
  "interactivo instala las dos elegidas en orden del catálogo"

# ---------------------------------------------------------------------------
# Caso 11 — flag desconocida (S3/S5).
# ---------------------------------------------------------------------------
nueva_corrida
run_flatpak --bogus
rc=$?
[[ ${rc} -eq 2 ]] && pasa "flag desconocida sale 2" || falla "flag desconocida sale 2 (exit ${rc})"
assert_contiene "${ERR}" "Uso:" "flag desconocida muestra el uso en stderr"
assert_sin_log "flag desconocida no invoca flatpak"

# ---------------------------------------------------------------------------
# Caso 12 — etiqueta "(instalada)" mapeada de vuelta al appid (S10).
# ---------------------------------------------------------------------------
nueva_corrida
printf 'com.getpostman.Postman\n' > "${INSTALADAS}"
printf 'com.getpostman.Postman (instalada)\norg.mozilla.Thunderbird\n' > "${SELECCION}"
run_flatpak_interactivo
rc=$?
[[ ${rc} -eq 0 ]] && pasa "interactivo con etiqueta (instalada) sale 0" || falla "interactivo con etiqueta (instalada) sale 0 (exit ${rc})"
assert_log "$(log_esperado org.mozilla.Thunderbird)" \
  "la etiqueta (instalada) se mapea al appid y la ya instalada no se reinstala"

# ---------------------------------------------------------------------------
# Caso 13 — selección vacía (S2/S7): avisa y no toca flathub.
# ---------------------------------------------------------------------------
nueva_corrida
: > "${SELECCION}"
run_flatpak_interactivo
rc=$?
[[ ${rc} -eq 0 ]] && pasa "interactivo sin selección sale 0" || falla "interactivo sin selección sale 0 (exit ${rc})"
assert_sin_log "interactivo sin selección no registra flathub ni instala"
assert_contiene "${PTY_OUT}" "No se seleccionó" "interactivo sin selección avisa"

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Caso 13 — sin gum pero CON TTY: se pregunta app por app (S2).
#
# Sin gum no hay menú, pero negarse a hacer nada rompería el instalador: su
# selección de componentes sin gum usa confirmaciones, y abortar acá con exit 2
# terminaría la instalación entera. Se pregunta una por una; las ya instaladas
# ni se preguntan.
# ---------------------------------------------------------------------------
nueva_corrida
# Catálogo: DBeaver, Postman, Thunderbird, OnlyOffice. Se acepta sólo Postman.
run_flatpak_pty "${MIN_BIN_NO_GUM}" $'n\ns\nn\nn\n'
rc=$?
[[ ${rc} -eq 0 ]] && pasa "sin gum con TTY pregunta app por app y sale 0" || falla "sin gum con TTY sale 0 (exit ${rc})"
assert_log "$(log_esperado com.getpostman.Postman)" \
  "sin gum instala sólo las confirmadas, en orden del catálogo"

# Sin gum, una ya instalada no se pregunta ni se reinstala.
nueva_corrida
printf 'com.getpostman.Postman\n' > "${INSTALADAS}"
run_flatpak_pty "${MIN_BIN_NO_GUM}" $'s\nn\nn\n'
rc=$?
[[ ${rc} -eq 0 ]] && pasa "sin gum con una ya instalada sale 0" || falla "sin gum con una ya instalada sale 0 (exit ${rc})"
assert_log "$(log_esperado io.dbeaver.DBeaverCommunity)" \
  "sin gum no reinstala la ya instalada"

printf '\n%d pasos, %d fallos\n' "${pasos}" "${fallos}"
[[ ${fallos} -eq 0 ]]
