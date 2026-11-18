#!/usr/bin/env bash
# Spec ejecutable de config/sway/scripts/sway-theme.sh.
#
# Verifica S5-S11 y S13 del tema claro/oscuro:
#   S5   un único toggle cambia claro<->oscuro (el panel de swaync y $mod+Shift+t
#        invocan este mismo script).
#   S6   el estado persiste en $XDG_STATE_HOME/dotfiles/tema y se re-aplica.
#   S7   foot cambia initial-color-theme y las terminales abiertas reciben
#        SIGUSR1 (oscuro) / SIGUSR2 (claro).
#   S8   waybar/swaync/wofi toman el tema por enlaces a themes/ y swaync recarga.
#   S9   las instancias de nvim abiertas cambian en vivo por su socket.
#   S10  swaylock y wob apuntan al tema activo para la próxima ejecución.
#   S11  un único estado de texto + enlaces simbólicos a archivos nativos.
#   S13  los CSS no dependen de colores hardcodeados fuera de themes/.
#
# Extensión rust-light (odd/tasks/rust-light.md): S6, S7 y S10 piden que herdr y
# tmux entren en el mismo toggle, con las mismas garantías (enlace al tema
# activo, aviso si falta el payload, recarga de las apps vivas).
#
# Corre el script REAL sobre un árbol aislado (config/ copiado, HOME/XDG/estado
# y sockets falsos, stubs en PATH) sin tocar el sistema.
set -uo pipefail

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "${SPEC_DIR}")")"
SCRIPT="${REPO_ROOT}/config/sway/scripts/sway-theme.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT

CONFIG="${WORK}/config"
FAKE_HOME="${WORK}/home"
STATE_HOME="${WORK}/state"
RUN="${WORK}/run"
STUBS="${WORK}/stubs"
RELOAD_LOG="${WORK}/reload.log"
GSETTINGS_LOG="${WORK}/gsettings.log"

pasos=0
fallos=0

pasa() { pasos=$((pasos + 1)); printf 'PASS  %s\n' "$1"; }
falla() { pasos=$((pasos + 1)); fallos=$((fallos + 1)); printf 'FAIL  %s\n' "$1"; }

assert_igual() {
  if [[ "$1" == "$2" ]]; then pasa "$3"; else falla "$3 (real: '$1', esperado: '$2')"; fi
}

assert_enlace() {
  local real=""
  [[ -L "$1" ]] && real="$(readlink "$1")"
  assert_igual "${real}" "$2" "$3"
}

assert_resuelve() {
  if [[ -e "$1" ]]; then pasa "$2"; else falla "$2 (no resuelve $1)"; fi
}

assert_linea() {
  if grep -Fxq "$2" "$1" 2>/dev/null; then pasa "$3"; else falla "$3 (falta '$2' en $1)"; fi
}

assert_contiene() {
  if grep -Fq -- "$2" "$1" 2>/dev/null; then pasa "$3"; else falla "$3 (falta '$2' en $1)"; fi
}

assert_stderr_contiene() {
  if [[ "${ERROR}" == *"$1"* ]]; then pasa "$2"; else falla "$2 (stderr: '${ERROR}')"; fi
}

# SALIDA = stdout, ERROR = stderr, CODIGO = exit code de la última corrida.
SALIDA=""
ERROR=""
CODIGO=0

# ---------------------------------------------------------------------------
# Fixture: config/ del repo copiado + HOME/estado/sockets falsos + stubs.
# ---------------------------------------------------------------------------
crear_fixture() {
  rm -rf "${CONFIG}" "${FAKE_HOME}" "${STATE_HOME}" "${RUN}" "${STUBS}"
  rm -f "${RELOAD_LOG}" "${GSETTINGS_LOG}"
  mkdir -p "${FAKE_HOME}" "${STATE_HOME}" "${RUN}" "${STUBS}"
  # -P conserva los enlaces simbólicos del repo (style.css, current.conf, ...).
  cp -rP "${REPO_ROOT}/config" "${CONFIG}"

  # Stubs: registran su invocación (nombre + argumentos) y salen 0. Los de
  # recarga van a reload.log; gsettings a su propio log para poder afirmar
  # "log de recarga vacío" y "gsettings exacto" por separado.
  for cmd in swaymsg swaync-client pkill pgrep notify-send nvim herdr tmux; do
    cat > "${STUBS}/${cmd}" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "\$(basename "\$0")" "\$*" >> "${RELOAD_LOG}"
exit 0
EOF
    chmod +x "${STUBS}/${cmd}"
  done
  cat > "${STUBS}/gsettings" <<EOF
#!/usr/bin/env bash
printf '%s %s\n' "\$(basename "\$0")" "\$*" >> "${GSETTINGS_LOG}"
exit 0
EOF
  chmod +x "${STUBS}/gsettings"

  # SWAYSOCK como archivo regular: fixture de "hay una sesión de sway" para
  # disparar swaymsg reload sin depender del entorno anfitrión.
  : > "${WORK}/sway.sock"
}

# Ejecuta el script real con el entorno aislado. Devuelve su código de salida.
ejecutar() {
  (
    cd "${WORK}" || exit 2
    unset WAYLAND_DISPLAY
    HOME="${FAKE_HOME}" \
    PATH="${STUBS}:${PATH}" \
    XDG_CONFIG_HOME="${CONFIG}" \
    XDG_STATE_HOME="${STATE_HOME}" \
    XDG_RUNTIME_DIR="${RUN}" \
    SWAYSOCK="${WORK}/sway.sock" \
      bash "${SCRIPT}" "$@" </dev/null
  )
}

correr() {
  local err_file="${WORK}/stderr.tmp"
  SALIDA="$(ejecutar "$@" 2>"${err_file}")"
  CODIGO=$?
  ERROR="$(cat "${err_file}" 2>/dev/null || true)"
  rm -f "${err_file}"
}

if [[ ! -f "${SCRIPT}" ]]; then
  echo "ERROR: no existe ${SCRIPT} (se espera el script bajo prueba)." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# Caso 1 — status sin estado: imprime dark, sale 0, no escribe nada.
# ---------------------------------------------------------------------------
crear_fixture
correr status
assert_igual "${CODIGO}" "0" "status sin archivo de estado sale 0"
assert_igual "${SALIDA}" "dark" "status sin archivo de estado imprime dark"
assert_igual "${ERROR}" "" "status no escribe a stderr"
if [[ ! -e "${STATE_HOME}/dotfiles/tema" ]]; then
  pasa "status no crea el archivo de estado"
else
  falla "status no crea el archivo de estado (lo creó)"
fi

# ---------------------------------------------------------------------------
# Caso 2 — light --no-reload: estado, enlaces, foot.ini y gsettings.
# ---------------------------------------------------------------------------
crear_fixture
correr light --no-reload
assert_igual "${CODIGO}" "0" "light --no-reload sale 0"
assert_igual "${SALIDA}" "" "light --no-reload no escribe a stdout"
assert_stderr_contiene "Tema light aplicado" "light --no-reload informa por stderr"
assert_igual "$(cat "${STATE_HOME}/dotfiles/tema" 2>/dev/null || true)" "light" \
  "light --no-reload escribe estado light"
assert_enlace "${CONFIG}/waybar/style.css" "themes/light.css" \
  "waybar apunta a themes/light.css"
assert_resuelve "${CONFIG}/waybar/style.css" "el enlace de waybar resuelve"
assert_enlace "${CONFIG}/swaync/style.css" "themes/light.css" \
  "swaync apunta a themes/light.css"
assert_resuelve "${CONFIG}/swaync/style.css" "el enlace de swaync resuelve"
assert_enlace "${CONFIG}/wofi/style.css" "themes/light.css" \
  "wofi apunta a themes/light.css"
assert_resuelve "${CONFIG}/wofi/style.css" "el enlace de wofi resuelve"
assert_enlace "${CONFIG}/sway/themes/current.conf" "light.conf" \
  "sway current.conf apunta a light.conf"
assert_resuelve "${CONFIG}/sway/themes/current.conf" "el enlace de sway resuelve"
assert_enlace "${CONFIG}/swaylock/config" "themes/light.conf" \
  "swaylock apunta a themes/light.conf"
assert_resuelve "${CONFIG}/swaylock/config" "el enlace de swaylock resuelve"
assert_enlace "${CONFIG}/wob/wob.ini" "themes/light.ini" \
  "wob apunta a themes/light.ini"
assert_resuelve "${CONFIG}/wob/wob.ini" "el enlace de wob resuelve"
assert_enlace "${CONFIG}/herdr/config.toml" "themes/light.toml" \
  "herdr apunta a themes/light.toml"
assert_resuelve "${CONFIG}/herdr/config.toml" "el enlace de herdr resuelve"
assert_enlace "${CONFIG}/tmux/tmux.conf" "themes/light.conf" \
  "tmux apunta a themes/light.conf"
assert_resuelve "${CONFIG}/tmux/tmux.conf" "el enlace de tmux resuelve"
assert_linea "${CONFIG}/foot/foot.ini" "initial-color-theme=light" \
  "foot.ini lleva initial-color-theme=light"
assert_linea "${CONFIG}/foot/foot.ini" "font=JetBrainsMono Nerd Font:size=12" \
  "foot.ini conserva la línea font= intacta"
assert_linea "${GSETTINGS_LOG}" "gsettings set org.gnome.desktop.interface gtk-theme Adwaita" \
  "gsettings aplica gtk-theme Adwaita en claro"
assert_linea "${GSETTINGS_LOG}" "gsettings set org.gnome.desktop.interface color-scheme prefer-light" \
  "gsettings aplica color-scheme prefer-light en claro"
assert_igual "$(grep -c '^gsettings ' "${GSETTINGS_LOG}" 2>/dev/null || true)" "2" \
  "gsettings registra exactamente las dos claves claras"
if [[ ! -s "${RELOAD_LOG}" ]]; then
  pasa "reload log vacío con --no-reload"
else
  falla "reload log vacío con --no-reload (tiene: $(cat "${RELOAD_LOG}"))"
fi

# ---------------------------------------------------------------------------
# Caso 3 — dark --no-reload: espejo del caso claro.
# ---------------------------------------------------------------------------
crear_fixture
correr dark --no-reload
assert_igual "${CODIGO}" "0" "dark --no-reload sale 0"
assert_igual "$(cat "${STATE_HOME}/dotfiles/tema" 2>/dev/null || true)" "dark" \
  "dark --no-reload escribe estado dark"
assert_enlace "${CONFIG}/waybar/style.css" "themes/dark.css" \
  "waybar apunta a themes/dark.css"
assert_enlace "${CONFIG}/swaync/style.css" "themes/dark.css" \
  "swaync apunta a themes/dark.css"
assert_enlace "${CONFIG}/wofi/style.css" "themes/dark.css" \
  "wofi apunta a themes/dark.css"
assert_enlace "${CONFIG}/sway/themes/current.conf" "dark.conf" \
  "sway current.conf apunta a dark.conf"
assert_enlace "${CONFIG}/swaylock/config" "themes/dark.conf" \
  "swaylock apunta a themes/dark.conf"
assert_enlace "${CONFIG}/wob/wob.ini" "themes/dark.ini" \
  "wob apunta a themes/dark.ini"
assert_enlace "${CONFIG}/herdr/config.toml" "themes/dark.toml" \
  "herdr apunta a themes/dark.toml"
assert_enlace "${CONFIG}/tmux/tmux.conf" "themes/dark.conf" \
  "tmux apunta a themes/dark.conf"
assert_linea "${CONFIG}/foot/foot.ini" "initial-color-theme=dark" \
  "foot.ini lleva initial-color-theme=dark"
assert_linea "${GSETTINGS_LOG}" "gsettings set org.gnome.desktop.interface gtk-theme Adwaita-dark" \
  "gsettings aplica gtk-theme Adwaita-dark en oscuro"
assert_linea "${GSETTINGS_LOG}" "gsettings set org.gnome.desktop.interface color-scheme prefer-dark" \
  "gsettings aplica color-scheme prefer-dark en oscuro"

# ---------------------------------------------------------------------------
# Caso 4 — toggle desde light dos veces: dark y luego light.
# ---------------------------------------------------------------------------
crear_fixture
correr light --no-reload
correr toggle --no-reload
assert_igual "${CODIGO}" "0" "toggle desde light sale 0"
assert_igual "$(cat "${STATE_HOME}/dotfiles/tema" 2>/dev/null || true)" "dark" \
  "toggle desde light pasa a dark"
assert_enlace "${CONFIG}/waybar/style.css" "themes/dark.css" \
  "toggle desde light apunta waybar a dark"
correr toggle --no-reload
assert_igual "${CODIGO}" "0" "toggle desde dark sale 0"
assert_igual "$(cat "${STATE_HOME}/dotfiles/tema" 2>/dev/null || true)" "light" \
  "toggle desde dark vuelve a light"
assert_enlace "${CONFIG}/waybar/style.css" "themes/light.css" \
  "toggle desde dark apunta waybar a light"

# ---------------------------------------------------------------------------
# Caso 5 — dark dos veces: idempotente.
# ---------------------------------------------------------------------------
crear_fixture
correr dark --no-reload
correr dark --no-reload
assert_igual "${CODIGO}" "0" "segundo dark --no-reload sale 0"
assert_igual "$(cat "${STATE_HOME}/dotfiles/tema" 2>/dev/null || true)" "dark" \
  "segundo dark conserva estado dark"
assert_enlace "${CONFIG}/waybar/style.css" "themes/dark.css" \
  "segundo dark conserva waybar en dark"
assert_linea "${CONFIG}/foot/foot.ini" "initial-color-theme=dark" \
  "segundo dark conserva foot.ini sin cambios"

# ---------------------------------------------------------------------------
# Caso 6 — acción desconocida: exit 2, uso en stderr, nada cambia.
# ---------------------------------------------------------------------------
crear_fixture
correr light --no-reload
correr bogus
assert_igual "${CODIGO}" "2" "acción desconocida sale 2"
assert_igual "${SALIDA}" "" "acción desconocida no escribe a stdout"
assert_stderr_contiene "Uso:" "acción desconocida imprime el uso en stderr"
assert_igual "$(cat "${STATE_HOME}/dotfiles/tema" 2>/dev/null || true)" "light" \
  "acción desconocida no toca el estado"
assert_enlace "${CONFIG}/waybar/style.css" "themes/light.css" \
  "acción desconocida no toca los enlaces"

# ---------------------------------------------------------------------------
# Caso 7 — falta un archivo de tema: exit 1, nombra la ruta, no toca nada.
# ---------------------------------------------------------------------------
crear_fixture
correr dark --no-reload
rm -f "${CONFIG}/wofi/themes/light.css"
correr light --no-reload
assert_igual "${CODIGO}" "1" "light con archivo de tema faltante sale 1"
assert_stderr_contiene "${CONFIG}/wofi/themes/light.css" \
  "light con tema faltante nombra la ruta faltante en stderr"
assert_igual "$(cat "${STATE_HOME}/dotfiles/tema" 2>/dev/null || true)" "dark" \
  "tema faltante no cambia el estado"
assert_enlace "${CONFIG}/waybar/style.css" "themes/dark.css" \
  "tema faltante no cambia los enlaces"
assert_enlace "${CONFIG}/wofi/style.css" "themes/dark.css" \
  "tema faltante no cambia el enlace de wofi"

# ---------------------------------------------------------------------------
# Caso 8 — recarga sin --no-reload: foot, swaync, sway, nvim y notificación.
# ---------------------------------------------------------------------------
crear_fixture
: > "${RUN}/nvim.999.0"
correr light
assert_igual "${CODIGO}" "0" "light con recarga sale 0"
assert_contiene "${RELOAD_LOG}" "pkill -USR2 -x foot" \
  "claro recarga foot con SIGUSR2"
assert_contiene "${RELOAD_LOG}" "swaync-client -rs" \
  "recarga swaync con swaync-client -rs"
assert_contiene "${RELOAD_LOG}" "pkill -x wob" \
  "la recarga limpia el OSD apilado de reloads viejos"
assert_contiene "${RELOAD_LOG}" "pgrep -x tail" \
  "la recarga busca los tail huérfanos del FIFO de wob"
assert_contiene "${RELOAD_LOG}" "swaymsg reload" \
  "recarga sway con swaymsg reload"
assert_contiene "${RELOAD_LOG}" "herdr server reload-config" \
  "recarga herdr con server reload-config"
# kill es un builtin de bash: no se puede doblar con un stub en PATH, así que
# esta parte se verifica en el código (la ruta se ejecuta en la vida real con
# cualquier herdr abierto: el sidebar sólo se actualiza con esa señal).
assert_contiene "${SCRIPT}" "kill -WINCH" \
  "herdr recibe SIGWINCH para releer la paleta del terminal"
assert_contiene "${RELOAD_LOG}" "tmux source-file ${CONFIG}/tmux/tmux.conf" \
  "recarga tmux con source-file del tema activo"
assert_contiene "${RELOAD_LOG}" "notify-send Tema Modo claro" \
  "notifica 'Modo claro'"
assert_contiene "${RELOAD_LOG}" "nvim --server ${RUN}/nvim.999.0" \
  "recarga nvim por su socket"
assert_contiene "${RELOAD_LOG}" 'luaeval("require(\"config.theme\").apply()")' \
  "nvim aplica config.theme.apply()"

: > "${RELOAD_LOG}"
correr dark
assert_igual "${CODIGO}" "0" "dark con recarga sale 0"
assert_contiene "${RELOAD_LOG}" "pkill -USR1 -x foot" \
  "oscuro recarga foot con SIGUSR1"
assert_contiene "${RELOAD_LOG}" "notify-send Tema Modo oscuro" \
  "notifica 'Modo oscuro'"

# ---------------------------------------------------------------------------
# Caso 9 — --quiet suprime la notificación (pero no el resto de la recarga).
# ---------------------------------------------------------------------------
crear_fixture
correr light --quiet
assert_igual "${CODIGO}" "0" "light --quiet sale 0"
if grep -Fq 'notify-send' "${RELOAD_LOG}" 2>/dev/null; then
  falla "--quiet suprime notify-send (se registró)"
else
  pasa "--quiet suprime notify-send"
fi
assert_contiene "${RELOAD_LOG}" "pkill -USR2 -x foot" \
  "--quiet no suprime la recarga de foot"
assert_igual "${ERROR}" "" "--quiet no escribe avisos a stderr"

# ---------------------------------------------------------------------------
# Caso 10 — foot.ini sin initial-color-theme: se inserta tras [main].
# ---------------------------------------------------------------------------
crear_fixture
sed -i '/^initial-color-theme=/d' "${CONFIG}/foot/foot.ini"
correr dark --no-reload
assert_igual "${CODIGO}" "0" "dark --no-reload con foot.ini sin la línea sale 0"
assert_linea "${CONFIG}/foot/foot.ini" "initial-color-theme=dark" \
  "foot.ini recupera initial-color-theme"
if grep -A1 '^\[main\]$' "${CONFIG}/foot/foot.ini" | grep -Fxq 'initial-color-theme=dark'; then
  pasa "initial-color-theme se inserta justo después de [main]"
else
  falla "initial-color-theme se inserta justo después de [main]"
fi
assert_linea "${CONFIG}/foot/foot.ini" "font=JetBrainsMono Nerd Font:size=12" \
  "foot.ini sin la línea conserva font= intacta"

# ---------------------------------------------------------------------------
# ---------------------------------------------------------------------------
# Caso 11 — una app que no está desplegada se saltea, no rompe el tema.
#
# El escritorio puede tener sólo sway+waybar aplicados: el toggle tiene que
# cambiar lo que existe y no fallar por las apps ausentes (si no, el autostart
# re-aplicaría un tema a medias en cada inicio).
# ---------------------------------------------------------------------------
crear_fixture
rm -rf "${CONFIG}/wob"
correr light --no-reload
assert_igual "${CODIGO}" "0" "app no desplegada (wob) no hace fallar el tema"
assert_igual "$(cat "${STATE_HOME}/dotfiles/tema" 2>/dev/null || true)" "light" \
  "app no desplegada igual escribe el estado"
assert_enlace "${CONFIG}/waybar/style.css" "themes/light.css" \
  "app no desplegada no impide aplicar las demás"
assert_enlace "${CONFIG}/sway/themes/current.conf" "light.conf" \
  "app no desplegada aplica sway igual"
if [[ ! -e "${CONFIG}/wob" ]]; then
  pasa "app no desplegada no se crea de la nada"
else
  falla "app no desplegada no se crea de la nada (existe ${CONFIG}/wob)"
fi

# ---------------------------------------------------------------------------
# Caso 12 — foot sin foot.ini: se saltea con aviso, el resto se aplica.
# ---------------------------------------------------------------------------
crear_fixture
rm -f "${CONFIG}/foot/foot.ini"
correr light --no-reload
assert_igual "${CODIGO}" "0" "foot sin foot.ini no hace fallar el tema"
assert_enlace "${CONFIG}/waybar/style.css" "themes/light.css" \
  "foot sin foot.ini no impide aplicar los enlaces"
if [[ "${ERROR}" == *"foot"* ]]; then
  pasa "foot sin foot.ini deja un aviso en stderr"
else
  falla "foot sin foot.ini deja un aviso en stderr (stderr: '${ERROR}')"
fi

# ---------------------------------------------------------------------------
# Caso 13 — apply también valida los payloads antes de tocar enlaces.
#
# El autostart y el despliegue usan `apply`: si un archivo de tema desapareció,
# apply no puede dejar style.css apuntando a la nada (el escritorio quedaría sin
# CSS hasta el próximo toggle).
# ---------------------------------------------------------------------------
crear_fixture
correr dark --no-reload
# El estado dice "light" (lo que apply va a re-aplicar) y le falta el payload;
# el enlace vivo sigue apuntando a dark, que está completo.
printf 'light\n' > "${STATE_HOME}/dotfiles/tema"
rm -f "${CONFIG}/waybar/themes/light.css"
correr apply --no-reload
assert_igual "${CODIGO}" "1" "apply con payload faltante sale 1"
assert_stderr_contiene "${CONFIG}/waybar/themes/light.css" \
  "apply con payload faltante nombra el archivo en stderr"
assert_enlace "${CONFIG}/waybar/style.css" "themes/dark.css" \
  "apply con payload faltante no reescribe el enlace vivo"
assert_resuelve "${CONFIG}/waybar/style.css" \
  "apply con payload faltante deja el enlace vivo resoluble"

# ---------------------------------------------------------------------------
# Caso 14 — foot.ini no escribible: aviso, no aborto a mitad del apply.
# ---------------------------------------------------------------------------
crear_fixture
# Se quita el permiso de escritura al DIRECTORIO: `sed -i` crea un temporal y
# renombra, así que con el archivo sólo (chmod 444) el reemplazo igual funciona.
chmod 555 "${CONFIG}/foot"
correr light --no-reload
chmod 755 "${CONFIG}/foot"
assert_igual "${CODIGO}" "0" "foot.ini no escribible no aborta el apply"
assert_enlace "${CONFIG}/waybar/style.css" "themes/light.css" \
  "foot.ini no escribible igual deja el tema aplicado"
if [[ "${ERROR}" == *"foot.ini"* ]]; then
  pasa "foot.ini no escribible deja un aviso"
else
  falla "foot.ini no escribible deja un aviso (stderr: '${ERROR}')"
fi

printf '\n%d pasos, %d fallos\n' "${pasos}" "${fallos}"
[[ ${fallos} -eq 0 ]]
