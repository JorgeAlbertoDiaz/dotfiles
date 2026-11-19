#!/usr/bin/env bash
# Spec ejecutable del greeter de LightDM (scripts/15-setup-lightdm.sh).
#
# Corre sobre un árbol temporal y dobles en PATH (sudo, date, fc-cache), así que
# no toca /etc/lightdm, /usr/share/themes ni el greeter real.
#
#   S1  se instalan las dos variantes del tema con la paleta rust y el conf del
#       greeter apunta a rust-login (el login deja de usar el branding de openSUSE).
#   S2  la variante se elige por hora local: oscuro 20:00-07:59, claro 08:00-19:59.
#   S3  el fondo sale de scripts/lightdm/background.png; si falta o no es una
#       imagen, el instalador falla antes de escribir nada.
#   S4  idempotencia y reversibilidad: respalda una sola vez, no duplica la clave
#       del hook, conserva user-session=sway y --check no escribe.
#
# Uso: ./scripts/tests/15-setup-lightdm-spec.sh
set -uo pipefail

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SPEC_DIR}/../.." && pwd)"
SCRIPT="${REPO_DIR}/scripts/15-setup-lightdm.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

ETC="${WORK}/etc/lightdm"
THEMES="${WORK}/themes"
FONTS="${WORK}/fonts"
SBIN="${WORK}/sbin"
BIN_T="${WORK}/bin"
HOME_T="${WORK}/home"
CALLS="${WORK}/calls.log"
CONF_GREETER="${ETC}/lightdm-gtk-greeter.conf"
CONF_LIGHTDM="${ETC}/lightdm.conf"
TEMA_DIR="${THEMES}/rust-login/gtk-3.0"

pasos=0
fallos=0

pasa() { pasos=$((pasos + 1)); printf 'PASS  %s\n' "$1"; }
falla() { pasos=$((pasos + 1)); fallos=$((fallos + 1)); printf 'FAIL  %s\n' "$1"; }

assert_exit() {
  if [[ "$1" -eq "$2" ]]; then pasa "$3"; else falla "$3 (exit $1, esperaba $2)"; fi
}

assert_existe() {
  if [[ -e "$1" ]]; then pasa "$2"; else falla "$2 (no existe $1)"; fi
}

assert_no_existe() {
  if [[ -e "$1" ]]; then falla "$2 (existe $1)"; else pasa "$2"; fi
}

assert_contiene() {
  if grep -qF -- "$2" "$1" 2>/dev/null; then pasa "$3"; else falla "$3 (falta «$2» en $1)"; fi
}

assert_no_contiene() {
  if grep -qF -- "$2" "$1" 2>/dev/null; then falla "$3 (sobra «$2» en $1)"; else pasa "$3"; fi
}

assert_igual() {
  if [[ "$1" == "$2" ]]; then pasa "$3"; else falla "$3 (real: '$1', esperado: '$2')"; fi
}

assert_enlace_a() {
  local real=""
  [[ -L "$1" ]] && real="$(readlink "$1")"
  assert_igual "${real}" "$2" "$3"
}

# ¿el archivo tiene una sola línea con esa clave/serie? (evita duplicados)
assert_una_vez() {
  local n
  n="$(grep -cF -- "$2" "$1" 2>/dev/null || true)"
  assert_igual "${n}" "1" "$3"
}

# ---------------------------------------------------------------------------
# Fixture: árbol temporal + dobles en PATH.
# ---------------------------------------------------------------------------
crear_stubs() {
  mkdir -p "${BIN_T}" "${HOME_T}/.local/share/fonts/JetBrainsMono"
  : >"${HOME_T}/.local/share/fonts/JetBrainsMono/JetBrainsMonoNerdFont-Regular.ttf"

  cat >"${BIN_T}/sudo" <<'DOBLE'
#!/usr/bin/env bash
printf 'sudo %s\n' "$*" >>"${CALLS_LOG}"
if [[ "${SUDO_FALLA:-0}" == "1" ]]; then
  echo "sudo: a password is required" >&2
  exit 1
fi
exec "$@"
DOBLE

  # date: la hora del caso de prueba, con ceros a la izquierda incluidos.
  cat >"${BIN_T}/date" <<'DOBLE'
#!/bin/sh
printf '%s\n' "${FECHA_HORA:-00}"
DOBLE

  cat >"${BIN_T}/fc-cache" <<'DOBLE'
#!/bin/sh
printf 'fc-cache %s\n' "$*" >>"${CALLS_LOG}"
exit 0
DOBLE

  chmod +x "${BIN_T}"/*
  : >"${WORK}/dm-lightdm"
  : >"${WORK}/dm-greeter"
  chmod +x "${WORK}/dm-lightdm" "${WORK}/dm-greeter"
  BIN_DM="${WORK}/dm-lightdm"
  BIN_GREETER="${WORK}/dm-greeter"
}

# Conf del sistema como lo deja openSUSE + el ajuste de sesión que ya existía.
crear_fixture() {
  rm -rf "${ETC}" "${THEMES}" "${FONTS}" "${SBIN}"
  mkdir -p "${ETC}"
  cat >"${CONF_LIGHTDM}" <<'ARCHIVO'
[Seat:*]
greeter-setup-script=/usr/bin/numlockx default
user-session=sway
ARCHIVO
  cat >"${CONF_GREETER}" <<'ARCHIVO'
[greeter]
background=/usr/share/wallpapers/openSUSEdefault/contents/images/default.png
theme-name=Greybird-geeko
ARCHIVO
  : >"${CALLS}"
  crear_stubs
}

# SALIDA / ERROR / CODIGO de la última corrida del instalador.
SALIDA=""
ERROR=""
CODIGO=0

correr() {
  local script="${1:-${SCRIPT}}"
  shift || true
  local err="${WORK}/stderr"
  SALIDA="$(PATH="${BIN_T}:${PATH}" HOME="${HOME_T}" \
    CALLS_LOG="${CALLS}" FECHA_HORA="${FECHA_HORA:-21}" \
    LIGHTDM_ETC="${ETC}" LIGHTDM_THEMES="${THEMES}" \
    LIGHTDM_FONTS="${FONTS}" LIGHTDM_SBIN="${SBIN}" \
    LIGHTDM_BIN="${BIN_DM}" LIGHTDM_GREETER_BIN="${BIN_GREETER}" \
    bash "${script}" "$@" 2>"${err}")"
  CODIGO=$?
  ERROR="$(cat "${err}")"
}

huella() {
  find "${ETC}" "${THEMES}" "${FONTS}" "${SBIN}" -type f -o -type l 2>/dev/null |
    sort | xargs -r md5sum 2>/dev/null | md5sum | cut -d' ' -f1
}

# ===========================================================================
# S1 — el payload trae las dos variantes con la paleta rust
# ===========================================================================
PAYLOAD="${REPO_DIR}/scripts/lightdm"
assert_existe "${PAYLOAD}/greeter/dark.css" "S1: el repo trae la variante oscura"
assert_existe "${PAYLOAD}/greeter/light.css" "S1: el repo trae la variante clara"
assert_contiene "${PAYLOAD}/greeter/dark.css" "@define-color rust_bg #2b2b27;" \
  "S1: la variante oscura usa el fondo del tema rust (#2b2b27)"
assert_contiene "${PAYLOAD}/greeter/dark.css" "@define-color rust_accent #e69f67;" \
  "S1: la variante oscura usa el acento del escritorio (#e69f67)"
assert_contiene "${PAYLOAD}/greeter/light.css" "@define-color rust_doc #E1E1DB;" \
  "S1: la variante clara usa el documento del tema claro (#E1E1DB)"
assert_contiene "${PAYLOAD}/greeter/light.css" "@define-color rust_chrome #3B2E2A;" \
  "S1: la variante clara usa el chrome del tema claro (#3B2E2A)"
assert_no_contiene "${PAYLOAD}/greeter/dark.css" "Greybird" \
  "S1: el tema no depende del branding de openSUSE"

# Los CSS se apoyan en Adwaita: si el resource no existe, el tema queda a medias.
if command -v gresource >/dev/null 2>&1; then
  recursos="$(gresource list /usr/lib64/libgtk-3.so.0 2>/dev/null || true)"
  for css in "gtk-contained-dark.css" "gtk-contained.css"; do
    if grep -q "theme/Adwaita/${css}" <<<"${recursos}"; then
      pasa "S1: GTK3 provee el resource Adwaita/${css}"
    else
      falla "S1: GTK3 no provee Adwaita/${css} (el @import del tema fallaría)"
    fi
  done
fi

crear_fixture
correr
assert_exit "${CODIGO}" 0 "S1: el instalador termina bien en un sistema con lightdm"
assert_existe "${TEMA_DIR}/dark.css" "S1: instala dark.css en el tema rust-login"
assert_existe "${TEMA_DIR}/light.css" "S1: instala light.css en el tema rust-login"
assert_contiene "${CONF_GREETER}" "theme-name=rust-login" \
  "S1: el greeter deja de usar Greybird-geeko y usa rust-login"
assert_no_contiene "${CONF_GREETER}" "Greybird-geeko" "S1: no queda el tema de openSUSE"
assert_contiene "${CONF_GREETER}" "font-name=JetBrainsMono Nerd Font 11" \
  "S1: el login usa la mono del escritorio"
assert_existe "${FONTS}/JetBrainsMonoNerdFont-Regular.ttf" \
  "S1: la fuente del escritorio queda disponible para el usuario lightdm"
assert_existe "${SBIN}/lightdm-greeter-setup" "S1: instala el helper del hook"

# ===========================================================================
# S2 — variante por hora
# ===========================================================================
probar_hora() {
  local hora="$1" esperado="$2"
  FECHA_HORA="${hora}" correr
  if [[ -L "${TEMA_DIR}/gtk.css" ]]; then
    assert_enlace_a "${TEMA_DIR}/gtk.css" "${esperado}.css" "S2: a las ${hora}:00 el login es ${esperado}"
  else
    falla "S2: a las ${hora}:00 no quedó gtk.css enlazado"
  fi
}

probar_hora 00 dark
probar_hora 07 dark
probar_hora 08 light
probar_hora 12 light
probar_hora 19 light
probar_hora 20 dark
probar_hora 23 dark

# El helper no puede tumbar el login: sin tema, avisa y sale 0.
mkdir -p "${WORK}/tema-vacio"
SALIDA="$(PATH="${BIN_T}:${PATH}" FECHA_HORA=21 \
  LIGHTDM_GREETER_THEME_DIR="${WORK}/tema-vacio" \
  "${SBIN}/lightdm-greeter-setup" 2>"${WORK}/err-helper")"
CODIGO=$?
ERROR="$(cat "${WORK}/err-helper")"
assert_exit "${CODIGO}" 0 "S2: el helper sale 0 aunque falte el tema (el login aparece igual)"
if [[ "${ERROR}" == *"falta"* ]]; then
  pasa "S2: el helper avisa por stderr cuando falta el CSS de la hora"
else
  falla "S2: el helper no avisa cuando falta el CSS (stderr: '${ERROR}')"
fi

# ===========================================================================
# S3 — el fondo sale del repo
# ===========================================================================
assert_existe "${PAYLOAD}/background.png" "S3: el repo trae la imagen del login"
if command -v file >/dev/null 2>&1; then
  mime="$(file -b --mime-type "${PAYLOAD}/background.png")"
  if [[ "${mime}" == image/* ]]; then
    pasa "S3: scripts/lightdm/background.png es una imagen (${mime})"
  else
    falla "S3: scripts/lightdm/background.png no es una imagen (${mime})"
  fi
fi

crear_fixture
correr
assert_existe "${ETC}/background.png" "S3: el fondo se instala en /etc/lightdm/background.png"
assert_contiene "${CONF_GREETER}" "background=${ETC}/background.png" \
  "S3: el conf del greeter apunta al fondo instalado"

# Sin la imagen, el instalador falla y no escribe nada (una copia del repo sin fondo).
ROTO="${WORK}/repo-sin-fondo"
mkdir -p "${ROTO}"
cp -r "${REPO_DIR}/scripts" "${ROTO}/scripts"
rm -f "${ROTO}/scripts/lightdm/background.png"
crear_fixture
huella_antes="$(huella)"
correr "${ROTO}/scripts/15-setup-lightdm.sh"
assert_exit "${CODIGO}" 1 "S3: sin scripts/lightdm/background.png el instalador falla"
if [[ "${SALIDA}${ERROR}" == *"background.png"* ]]; then
  pasa "S3: el error nombra el archivo que falta"
else
  falla "S3: el error no nombra background.png (salida: '${SALIDA}${ERROR}')"
fi
assert_no_contiene "${CONF_GREETER}" "# gestionado por dotfiles" \
  "S3: no reemplaza el conf del greeter si falta el fondo"
assert_igual "$(huella)" "${huella_antes}" "S3: no escribe nada si el payload está incompleto"

# Un archivo que no es imagen tampoco pasa.
printf 'esto no es un png\n' >"${ROTO}/scripts/lightdm/background.png"
correr "${ROTO}/scripts/15-setup-lightdm.sh"
assert_exit "${CODIGO}" 1 "S3: un background.png que no es imagen también falla"

# ===========================================================================
# S4 — idempotencia, respaldos y hook
# ===========================================================================
crear_fixture
correr
assert_exit "${CODIGO}" 0 "S4: primera instalación sobre un sistema intacto"
assert_contiene "${CONF_LIGHTDM}" "greeter-setup-script=${SBIN}/lightdm-greeter-setup" \
  "S4: el hook apunta al helper (que además mantiene el numlock)"
assert_no_contiene "${CONF_LIGHTDM}" "greeter-setup-script=/usr/bin/numlockx default" \
  "S4: el hook viejo de numlockx ya no queda duplicado"
assert_contiene "${CONF_LIGHTDM}" "user-session=sway" "S4: conserva la sesión sway"
assert_contiene "${CONF_LIGHTDM}" "[Seat:*]" "S4: conserva la sección [Seat:*]"
assert_existe "${CONF_LIGHTDM}.pre-rust-login.bak" "S4: respalda lightdm.conf antes de tocarlo"
assert_contiene "${CONF_LIGHTDM}.pre-rust-login.bak" "/usr/bin/numlockx default" \
  "S4: el respaldo tiene el contenido original"
assert_contiene "${CONF_GREETER}" "# gestionado por dotfiles" \
  "S4: el conf del greeter queda marcado como gestionado"
respaldos_greeter="$(find "${ETC}" -maxdepth 1 -name 'lightdm-gtk-greeter.conf.bak.*' | wc -l)"
assert_igual "${respaldos_greeter}" "1" "S4: respalda el conf del greeter una sola vez"

# Segunda corrida: nada nuevo, nada duplicado.
correr
assert_exit "${CODIGO}" 0 "S4: segunda corrida idempotente"
assert_una_vez "${CONF_LIGHTDM}" "greeter-setup-script=" "S4: sigue habiendo un solo hook"
respaldos_greeter="$(find "${ETC}" -maxdepth 1 -name 'lightdm-gtk-greeter.conf.bak.*' | wc -l)"
assert_igual "${respaldos_greeter}" "1" "S4: la segunda corrida no crea otro respaldo"

# --check informa sin escribir.
huella_antes="$(huella)"
correr "" --check
assert_exit "${CODIGO}" 0 "S4: --check sale 0 cuando todo está instalado"
assert_igual "$(huella)" "${huella_antes}" "S4: --check no escribe nada"
correr "" --check
if [[ "${SALIDA}" == *"variante activa"* ]]; then
  pasa "S4: --check informa la variante activa"
else
  falla "S4: --check no informa la variante activa"
fi

# --check detecta lo que falta.
crear_fixture
correr "" --check
assert_exit "${CODIGO}" 1 "S4: --check sale 1 cuando no hay nada instalado"

# Sin lightdm (otro display manager) no rompe la instalación: avisa y sale 0.
crear_fixture
BIN_DM="${WORK}/no-existe-lightdm"
correr
assert_exit "${CODIGO}" 0 "S4: sin lightdm avisa y sale 0 (no rompe el instalador)"
if [[ "${SALIDA}${ERROR}" == *"lightdm"* ]]; then
  pasa "S4: el aviso nombra lightdm"
else
  falla "S4: el aviso no nombra lightdm (salida: '${SALIDA}${ERROR}')"
fi
assert_no_contiene "${CONF_GREETER}" "# gestionado por dotfiles" \
  "S4: sin lightdm no reemplaza el conf del greeter"

# Opción desconocida: uso y exit 2, sin tocar nada.
crear_fixture
correr "" --loquesea
assert_exit "${CODIGO}" 2 "S4: una opción desconocida sale 2"
assert_no_contiene "${CONF_GREETER}" "# gestionado por dotfiles" \
  "S4: una opción desconocida no instala nada"

# ---------------------------------------------------------------------------
printf '\n%d pasos, %d fallos\n' "${pasos}" "${fallos}"
((fallos == 0))
