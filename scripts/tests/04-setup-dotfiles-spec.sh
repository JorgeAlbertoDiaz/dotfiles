#!/usr/bin/env bash
# Spec ejecutable de scripts/04-setup-dotfiles.sh.
#
# Verifica S1-S4 del rediseño de limpieza acotada:
#   S1/S2  la limpieza solo toca archivos que el repo despliega y que dejó de
#          declarar (calculado en cada corrida desde config/, no a mano).
#   S3/S4  aplicar dotfiles no borra binarios de usuario, datos de apps
#          (podman, estado) ni configuraciones que el repo no reconstruye.
#
# Corre el script real sobre un HOME y un repo de prueba, sin TTY, sin root y
# sin tocar el sistema. Uso: ./scripts/tests/04-setup-dotfiles-spec.sh
set -uo pipefail

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_SCRIPTS="$(dirname "${SPEC_DIR}")"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

REPO="${WORK}/repo"
FAKE_HOME="${WORK}/home"
STUBS="${WORK}/stubs"
MANIFEST="${FAKE_HOME}/.local/state/dotfiles/desplegado.tsv"

pasos=0
fallos=0

pasa() { pasos=$((pasos + 1)); printf 'PASS  %s\n' "$1"; }
falla() { pasos=$((pasos + 1)); fallos=$((fallos + 1)); printf 'FAIL  %s\n' "$1"; }

assert_existe() {
  if [[ -e "$1" ]]; then pasa "$2"; else falla "$2 (falta $1)"; fi
}

assert_no_existe() {
  if [[ -e "$1" ]]; then falla "$2 (sigue existiendo $1)"; else pasa "$2"; fi
}

assert_contenido() {
  local real=""
  [[ -f "$1" ]] && real="$(cat "$1")"
  if [[ "${real}" == "$2" ]]; then pasa "$3"; else falla "$3 (contenido: '${real}')"; fi
}

assert_ejecutable() {
  if [[ -x "$1" ]]; then pasa "$2"; else falla "$2 ($1 no es ejecutable)"; fi
}

# ---------------------------------------------------------------------------
# Fixture: repo mínimo + HOME con datos que el repo NO reconstruye.
# ---------------------------------------------------------------------------
crear_fixture() {
  rm -rf "${REPO}" "${FAKE_HOME}" "${STUBS}"
  mkdir -p "${REPO}/scripts" "${STUBS}"
  cp "${SRC_SCRIPTS}/04-setup-dotfiles.sh" "${REPO}/scripts/"
  cp "${SRC_SCRIPTS}/common.sh" "${REPO}/scripts/"
  chmod +x "${REPO}/scripts/04-setup-dotfiles.sh"

  # Stubs: shell real de la cuenta ya es zsh (evita el prompt de chsh) y
  # getent determinista (no depende de la cuenta que corre el spec).
  printf '#!/usr/bin/env bash\nprintf "tester:x:1000:1000::/home/tester:/bin/zsh\\n"\n' \
    > "${STUBS}/getent"
  printf '#!/usr/bin/env bash\nexit 0\n' > "${STUBS}/zsh"
  chmod +x "${STUBS}/getent" "${STUBS}/zsh"

  # config/ del repo de prueba.
  mkdir -p "${REPO}/config/appconf/sub" \
           "${REPO}/config/environment.d" \
           "${REPO}/config/home/.local/bin" \
           "${REPO}/config/home/.local/share/appa"
  printf 'conf v1\n' > "${REPO}/config/appconf/conf.ini"
  printf 'nested\n'  > "${REPO}/config/appconf/sub/nested.conf"
  printf '10-repo\n' > "${REPO}/config/environment.d/10-repo.conf"
  printf 'bashrc\n'  > "${REPO}/config/home/.bashrc"
  printf 'tool\n'    > "${REPO}/config/home/.local/bin/repo-tool"
  chmod 755 "${REPO}/config/home/.local/bin/repo-tool"
  printf 'AJUSTES_POR_DEFECTO\n' > "${REPO}/config/home/.local/share/appa/settings.json"

  # HOME con datos de usuario que nada de esto reconstruye.
  mkdir -p "${FAKE_HOME}/.config/appconf/unmanaged-dir" \
           "${FAKE_HOME}/.config/environment.d" \
           "${FAKE_HOME}/.local/bin" \
           "${FAKE_HOME}/.local/share/containers/storage" \
           "${FAKE_HOME}/.local/share/appa" \
           "${FAKE_HOME}/.local/state/herdr"
  printf 'extra\n'     > "${FAKE_HOME}/.config/appconf/mi-extra.conf"
  printf 'keep\n'      > "${FAKE_HOME}/.config/appconf/unmanaged-dir/keep.txt"
  printf '99-local\n'  > "${FAKE_HOME}/.config/environment.d/99-local.conf"
  printf 'herdr-bin\n' > "${FAKE_HOME}/.local/bin/herdr"
  printf 'db\n'        > "${FAKE_HOME}/.local/share/containers/storage/db.sql"
  printf 'USER_SETTINGS\n' > "${FAKE_HOME}/.local/share/appa/settings.json"
  printf 'state\n'     > "${FAKE_HOME}/.local/state/herdr/session.json"
}

# Aplica el script bajo prueba. Sin TTY: cualquier confirmación cae a stdin,
# que está cerrado (EOF), así que el flujo no interactivo debe terminar.
aplicar() {
  (
    cd "${WORK}" || exit 2
    HOME="${FAKE_HOME}" \
    PATH="${STUBS}:${PATH}" \
    XDG_CONFIG_HOME="${FAKE_HOME}/.config" \
    XDG_DATA_HOME="${FAKE_HOME}/.local/share" \
    XDG_STATE_HOME="${FAKE_HOME}/.local/state" \
      timeout 60 bash "${REPO}/scripts/04-setup-dotfiles.sh" "$@" </dev/null
  )
}

if ! command -v timeout >/dev/null 2>&1; then
  echo "ERROR: se necesita 'timeout' para que un prompt accidental no cuelgue el spec." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Caso 1 — aplicar todo despliega lo gestionado y conserva lo ajeno (S3/S4).
# ---------------------------------------------------------------------------
crear_fixture

if aplicar todos; then
  pasa "aplicar todos sale 0 sin TTY"
else
  falla "aplicar todos sale 0 sin TTY (el reset interactivo o un prompt colgaron o fallaron)"
fi

assert_contenido "${FAKE_HOME}/.config/appconf/conf.ini" "conf v1" \
  "despliega config gestionada (appconf/conf.ini)"
assert_existe "${FAKE_HOME}/.config/appconf/sub/nested.conf" \
  "despliega subdirectorios gestionados"
assert_existe "${FAKE_HOME}/.config/environment.d/10-repo.conf" \
  "despliega variables de entorno del repo"
assert_contenido "${FAKE_HOME}/.bashrc" "bashrc" \
  "despliega dotfiles de home"
assert_ejecutable "${FAKE_HOME}/.local/bin/repo-tool" \
  "despliega binarios gestionados conservando el modo"

assert_contenido "${FAKE_HOME}/.local/bin/herdr" "herdr-bin" \
  "conserva binarios de usuario (~/.local/bin/herdr)"
assert_contenido "${FAKE_HOME}/.config/appconf/mi-extra.conf" "extra" \
  "conserva archivos propios dentro de ~/.config/<app>"
assert_existe "${FAKE_HOME}/.config/appconf/unmanaged-dir/keep.txt" \
  "conserva directorios propios dentro de ~/.config/<app>"
assert_contenido "${FAKE_HOME}/.config/environment.d/99-local.conf" "99-local" \
  "conserva variables de entorno que no son del repo"
assert_existe "${FAKE_HOME}/.local/share/containers/storage/db.sql" \
  "conserva datos de podman (~/.local/share/containers)"
assert_existe "${FAKE_HOME}/.local/state/herdr/session.json" \
  "conserva estado de apps (~/.local/state)"

# ---------------------------------------------------------------------------
# Caso 2 — dato mutable de app: se siembra si falta, nunca se pisa (S4).
# ---------------------------------------------------------------------------
assert_contenido "${FAKE_HOME}/.local/share/appa/settings.json" "USER_SETTINGS" \
  "no pisa ajustes existentes en ~/.local/share/<app>"
rm -f "${FAKE_HOME}/.local/share/appa/settings.json"
aplicar todos >/dev/null
assert_contenido "${FAKE_HOME}/.local/share/appa/settings.json" "AJUSTES_POR_DEFECTO" \
  "siembra ajustes por defecto cuando faltan"

# ---------------------------------------------------------------------------
# Caso 3 — poda solo lo que el repo dejó de declarar, y nada más (S1/S2).
# ---------------------------------------------------------------------------
rm -f "${REPO}/config/appconf/sub/nested.conf"
rm -f "${REPO}/config/home/.local/bin/repo-tool"
printf 'nuevo\n' > "${REPO}/config/appconf/nuevo.conf"

if aplicar todos; then
  pasa "segunda aplicación (con archivos retirados del repo) sale 0"
else
  falla "segunda aplicación (con archivos retirados del repo) sale 0"
fi

assert_no_existe "${FAKE_HOME}/.config/appconf/sub/nested.conf" \
  "poda archivo gestionado que el repo ya no declara"
assert_no_existe "${FAKE_HOME}/.config/appconf/sub" \
  "elimina el directorio que quedó vacío"
assert_no_existe "${FAKE_HOME}/.local/bin/repo-tool" \
  "poda binario gestionado que el repo ya no declara"
assert_contenido "${FAKE_HOME}/.config/appconf/nuevo.conf" "nuevo" \
  "despliega el archivo nuevo"
assert_contenido "${FAKE_HOME}/.local/bin/herdr" "herdr-bin" \
  "la poda no toca binarios de usuario del mismo directorio"
assert_contenido "${FAKE_HOME}/.config/appconf/mi-extra.conf" "extra" \
  "la poda no toca archivos propios de la misma app"
assert_existe "${FAKE_HOME}/.local/share/containers/storage/db.sql" \
  "la poda no toca datos de apps"
assert_contenido "${FAKE_HOME}/.local/share/appa/settings.json" "AJUSTES_POR_DEFECTO" \
  "la poda no toca datos sembrados de apps"

# ---------------------------------------------------------------------------
# Caso 4 — un dato de app que el repo deja de sembrar tampoco se poda (S4).
# ---------------------------------------------------------------------------
rm -f "${REPO}/config/home/.local/share/appa/settings.json"
aplicar todos >/dev/null
assert_contenido "${FAKE_HOME}/.local/share/appa/settings.json" "AJUSTES_POR_DEFECTO" \
  "la poda tampoco borra datos de apps que el repo dejó de sembrar"

# ---------------------------------------------------------------------------
# Caso 5 — una app completa que sale del repo se limpia solo en 'todos' (S1/S2).
# ---------------------------------------------------------------------------
rm -rf "${REPO}/config/environment.d"
if aplicar todos >/dev/null; then
  pasa "aplicar todos con una app retirada del repo sale 0"
else
  falla "aplicar todos con una app retirada del repo sale 0"
fi
assert_no_existe "${FAKE_HOME}/.config/environment.d/10-repo.conf" \
  "poda los archivos de una app que ya no está en config/"
assert_contenido "${FAKE_HOME}/.config/environment.d/99-local.conf" "99-local" \
  "la app retirada deja intacto lo que el repo no desplegó"

# ---------------------------------------------------------------------------
# Caso 6 — idempotencia: repetir no cambia el resultado ni falla.
# ---------------------------------------------------------------------------
if aplicar todos >/dev/null; then
  pasa "tercera aplicación sale 0 (idempotente)"
else
  falla "tercera aplicación sale 0 (idempotente)"
fi
assert_contenido "${FAKE_HOME}/.config/appconf/nuevo.conf" "nuevo" \
  "idempotente: conserva lo desplegado"

# ---------------------------------------------------------------------------
# Caso 7 — inventario manipulado: nunca borra fuera de $HOME ni por '..'.
# ---------------------------------------------------------------------------
printf 'fuera\n' > "${WORK}/fuera.txt"
printf 'absoluto\n' > "${WORK}/absoluto.txt"
mkdir -p "$(dirname "${MANIFEST}")"
printf 'home\t%s\n' "../fuera.txt" "${WORK}/absoluto.txt" >> "${MANIFEST}"

if aplicar todos >/dev/null; then
  pasa "aplicar con inventario manipulado sale 0"
else
  falla "aplicar con inventario manipulado sale 0"
fi
assert_contenido "${WORK}/fuera.txt" "fuera" \
  "ignora una ruta con '..' en el inventario"
assert_contenido "${WORK}/absoluto.txt" "absoluto" \
  "ignora una ruta absoluta en el inventario"

# ---------------------------------------------------------------------------
printf '\n%d pasos, %d fallos\n' "${pasos}" "${fallos}"
[[ ${fallos} -eq 0 ]]
