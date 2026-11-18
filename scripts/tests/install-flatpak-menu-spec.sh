#!/usr/bin/env bash
# Spec de integración del menú Flatpak de install.sh.
#
# Verifica S1, S8 y S9 del instalador Flatpak con selección de apps:
#   S1  la entrada "Instalar aplicaciones Flatpak" del menú ejecuta el paso
#       sin argumentos y vuelve al menú (no aborta la instalación).
#   S8  Flatpak es un componente más (COMPONENTES): en instalación completa
#       corre con --all; elegido a mano, abre la selección interactiva (sin
#       argumentos).
#   S9  la pregunta global del paso 6 desaparece: ninguna confirmación
#       menciona Flatpak y sólo queda un camino para instalarlo.
#
# Ejercita el install.sh real sin root, sin red y sin paquetes reales: stubs
# de logging para cada script invocado y un stub de gum que contesta desde
# answers/N. Uso: ./scripts/tests/install-flatpak-menu-spec.sh
set -uo pipefail

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_RAIZ="$(cd "${SPEC_DIR}/../.." && pwd)"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

CALLS_LOG="${WORK}/calls.log"
GUM_LOG="${WORK}/gum.log"

pasos=0
fallos=0

pasa()  { pasos=$((pasos + 1)); printf 'PASS  %s\n' "$1"; }
falla() { pasos=$((pasos + 1)); fallos=$((fallos + 1)); printf 'FAIL  %s\n' "$1"; }

assert_exit() {
  if [[ "$1" -eq "$2" ]]; then pasa "$3"; else falla "$3 (exit $1, esperaba $2)"; fi
}

assert_llamada() {
  if grep -Fxq "$1" "${CALLS_LOG}"; then pasa "$2"; else falla "$2 (falta '$1' en calls.log)"; fi
}

assert_no_llamada() {
  if grep -Fxq "$1" "${CALLS_LOG}"; then falla "$2 (aparece '$1')"; else pasa "$2"; fi
}

assert_cuenta() {
  local n
  n="$(grep -Fxc "$1" "${CALLS_LOG}" || true)"
  if [[ "${n}" -eq "$2" ]]; then pasa "$3"; else falla "$3 (cuenta ${n}, esperaba $2)"; fi
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
# Fixture: install.sh + common.sh reales y stubs de logging para cada script.
# ---------------------------------------------------------------------------
crear_stub() {
  # $1 = nombre con el que se registra en calls.log; $2 = ruta relativa al repo.
  cat > "${WORK}/repo/$2" <<EOF
#!/usr/bin/env bash
{
  printf '$1'
  for a in "\$@"; do printf ' %q' "\$a"; done
  printf '\n'
} >> "${CALLS_LOG}"
exit 0
EOF
  chmod +x "${WORK}/repo/$2"
}

crear_gum() {
  cat > "${WORK}/bin/gum" <<'EOF'
#!/usr/bin/env bash
# Stub de gum: registra la invocación y contesta desde answers/N en orden.
WORK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
{
  printf 'gum'
  for a in "$@"; do printf ' %q' "$a"; done
  printf '\n'
} >> "${WORK_DIR}/gum.log"

CTR="${WORK_DIR}/answers/.next"
[[ -f "${CTR}" ]] || printf '1\n' > "${CTR}"
N="$(cat "${CTR}")"
printf '%s\n' "$((N + 1))" > "${CTR}"

case "$1" in
  choose)
    cat "${WORK_DIR}/answers/${N}" 2>/dev/null
    ;;
  confirm)
    if [[ "$(cat "${WORK_DIR}/answers/${N}" 2>/dev/null)" == "yes" ]]; then
      exit 0
    else
      exit 1
    fi
    ;;
  *)
    exit 0
    ;;
esac
EOF
  chmod +x "${WORK}/bin/gum"
}

crear_fixture() {
  rm -rf "${WORK:?}/repo" "${WORK:?}/bin" "${WORK:?}/answers" "${WORK:?}/home"
  mkdir -p "${WORK}/repo/scripts/drivers" "${WORK}/bin" "${WORK}/answers" "${WORK}/home"
  : > "${CALLS_LOG}"
  : > "${GUM_LOG}"

  cp "${REPO_RAIZ}/install.sh" "${WORK}/repo/install.sh"
  cp "${REPO_RAIZ}/scripts/common.sh" "${WORK}/repo/scripts/common.sh"
  chmod +x "${WORK}/repo/install.sh"

  crear_stub "00-check-system.sh"     "scripts/00-check-system.sh"
  crear_stub "00-xdg-dirs.sh"         "scripts/00-xdg-dirs.sh"
  crear_stub "01-install-gum.sh"      "scripts/01-install-gum.sh"
  crear_stub "02-install-packages.sh" "scripts/02-install-packages.sh"
  crear_stub "02b-install-flatpak.sh" "scripts/02b-install-flatpak.sh"
  crear_stub "04-setup-dotfiles.sh"   "scripts/04-setup-dotfiles.sh"
  crear_stub "05-install-fonts.sh"    "scripts/05-install-fonts.sh"
  crear_stub "06-network-wifi.sh"     "scripts/06-network-wifi.sh"
  crear_stub "07-network-config.sh"   "scripts/07-network-config.sh"
  crear_stub "08-setup-zsh.sh"        "scripts/08-setup-zsh.sh"
  crear_stub "09-setup-nvim.sh"       "scripts/09-setup-nvim.sh"
  crear_stub "10-setup-mime-apps.sh"  "scripts/10-setup-mime-apps.sh"
  crear_stub "11-setup-droidcam.sh"   "scripts/11-setup-droidcam.sh"
  crear_stub "12-setup-handy.sh"      "scripts/12-setup-handy.sh"
  crear_stub "14-setup-samba.sh"      "scripts/14-setup-samba.sh"
  crear_stub "drivers-menu.sh"        "scripts/drivers/drivers-menu.sh"
  crear_gum
}

escribir_respuestas() {
  local i=1 r
  for r in "$@"; do
    printf '%s\n' "${r}" > "${WORK}/answers/${i}"
    i=$((i + 1))
  done
}

ejecutar() {
  (
    cd "${WORK}" || exit 2
    HOME="${WORK}/home" \
    CALLS_LOG="${CALLS_LOG}" \
    PATH="${WORK}/bin:${PATH}" \
      timeout 60 bash "${WORK}/repo/install.sh" </dev/null
  )
}

if ! command -v timeout >/dev/null 2>&1; then
  echo "ERROR: se necesita 'timeout' para que un prompt accidental no cuelgue el spec." >&2
  exit 2
fi

: > "${WORK}/gum-todas.log"

# ---------------------------------------------------------------------------
# Caso 1 — entrada del menú: ejecuta sin argumentos y vuelve al menú (S1).
# ---------------------------------------------------------------------------
crear_fixture
escribir_respuestas "Instalar aplicaciones Flatpak" "Salir"
rc=0
ejecutar
rc=$?
cat "${GUM_LOG}" >> "${WORK}/gum-todas.log"

assert_exit "${rc}" 0 "elegir la entrada del menú sale 0 (vuelve al menú y sale por Salir)"
assert_llamada "02b-install-flatpak.sh" "la entrada del menú invoca 02b sin argumentos"
assert_cuenta "02b-install-flatpak.sh" 1 "la entrada del menú invoca 02b una sola vez"
assert_no_llamada "02b-install-flatpak.sh --all" "la entrada del menú no instala todo el catálogo"

# ---------------------------------------------------------------------------
# Caso 2 — componente elegido a mano: base/shell antes, y sin --all (S8).
# ---------------------------------------------------------------------------
crear_fixture
escribir_respuestas "Seleccionar componentes" "Aplicaciones Flatpak" "yes"
rc=0
ejecutar
rc=$?
cat "${GUM_LOG}" >> "${WORK}/gum-todas.log"
cp "${CALLS_LOG}" "${WORK}/calls-caso2.log"

assert_exit "${rc}" 0 "seleccionar solo 'Aplicaciones Flatpak' sale 0"
assert_llamada "02b-install-flatpak.sh" "elegido a mano invoca 02b sin argumentos (selección interactiva)"
assert_cuenta "02b-install-flatpak.sh" 1 "elegido a mano invoca 02b una sola vez"
assert_no_llamada "02b-install-flatpak.sh --all" "elegido a mano no pasa --all"
assert_antes "02-install-packages.sh base.txt" "02b-install-flatpak.sh" "base se instala antes que Flatpak"
assert_antes "02-install-packages.sh shell.txt" "02b-install-flatpak.sh" "shell se instala antes que Flatpak"

# ---------------------------------------------------------------------------
# Caso 3 — instalación completa: todo el catálogo con --all (S8).
# ---------------------------------------------------------------------------
crear_fixture
escribir_respuestas "Instalación completa (todo)"
rc=0
ejecutar
rc=$?
cat "${GUM_LOG}" >> "${WORK}/gum-todas.log"

assert_exit "${rc}" 0 "instalación completa sale 0"
assert_cuenta "02b-install-flatpak.sh --all" 1 "instalación completa invoca 02b --all exactamente una vez"
assert_no_llamada "02b-install-flatpak.sh" "instalación completa no abre la selección interactiva"

# ---------------------------------------------------------------------------
# Caso 4 — Nunca: --all solo en completa, y ninguna confirmación global (S9).
# ---------------------------------------------------------------------------
n_all_caso2="$(grep -Fxc '02b-install-flatpak.sh --all' "${WORK}/calls-caso2.log" || true)"
if [[ "${n_all_caso2}" -eq 0 ]]; then
  pasa "el caso 2 (selección a mano) nunca invoca 02b --all"
else
  falla "el caso 2 (selección a mano) nunca invoca 02b --all (cuenta ${n_all_caso2})"
fi

if grep 'confirm' "${WORK}/gum-todas.log" | grep -q 'Flatpak'; then
  falla "ninguna confirmación menciona Flatpak (la pregunta global sigue viva)"
else
  pasa "ninguna confirmación menciona Flatpak (S9: la pregunta global desapareció)"
fi

# ---------------------------------------------------------------------------
printf '\n%d pasos, %d fallos\n' "${pasos}" "${fallos}"
[[ ${fallos} -eq 0 ]]
