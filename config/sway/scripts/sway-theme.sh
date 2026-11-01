#!/usr/bin/env bash
# sway-theme.sh — cambia el tema claro/oscuro de todo el escritorio sway.
#
# Un solo comando mueve TODO el escritorio (sway, waybar, swaync, wofi, foot,
# swaylock, wob, GTK/libadwaita y nvim) entre "dark" y "light".
#
# Uso:
#   sway-theme.sh [toggle|dark|light|apply|status] [--no-reload] [--quiet]
#   sway-theme.sh -h|--help
#
# El tema activo es UN estado de texto (dark|light) en
#   ${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles/tema
# Los estilos son enlaces simbólicos RELATIVOS al archivo de tema del repo;
# foot lleva initial-color-theme en foot.ini y las terminales abiertas cambian
# en vivo con SIGUSR1 (oscuro) / SIGUSR2 (claro).
set -euo pipefail

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/dotfiles"
STATE_FILE="${STATE_DIR}/tema"

QUIET=0
NO_RELOAD=0
ACCION=""

uso() {
  cat <<'EOF'
Uso: sway-theme.sh [toggle|dark|light|apply|status] [--no-reload] [--quiet]

Acciones:
  toggle        cambia entre claro y oscuro
  dark          aplica el tema oscuro
  light         aplica el tema claro
  apply         re-aplica el tema guardado (nunca recarga)
  status        imprime el tema activo (dark|light)

Opciones:
  --no-reload   no recarga las apps abiertas (foot, sway, swaync, nvim)
  --quiet       suprime avisos y la notificación
  -h, --help    muestra esta ayuda
EOF
}

# Aviso de progreso para humanos: va a stderr y se omite con --quiet. La salida
# estándar queda reservada exclusivamente para `status`.
aviso() {
  if [[ "${QUIET}" -eq 0 ]]; then
    printf '%s\n' "$1" >&2
  fi
}

# Tema actual: "dark" cuando el archivo no existe, está vacío o no se puede
# leer (un clon recién instalado nunca hizo toggle y dark es el valor por
# defecto). Solo la primera línea importa; "light" es el único valor claro.
tema_actual() {
  local linea=""
  if [[ -r "${STATE_FILE}" ]]; then
    linea="$(head -n1 "${STATE_FILE}" 2>/dev/null || true)"
  fi
  if [[ "${linea}" == "light" ]]; then
    printf 'light\n'
  else
    printf 'dark\n'
  fi
}

# Los temas son archivos reales del repo y el enlace activo apunta a uno. Se
# comprueba que existan ANTES de escribir nada: si falta uno, dejar el
# escritorio con un enlace roto y a medio tema sería peor que no cambiar nada.
#
# Cada app participa con un enlace; el payload es su archivo de tema. Formato
# de la tabla: <app>|<enlace relativo a CONFIG_HOME>|<payload relativo>.
enlaces_de_tema() {
  local tema="$1"
  printf '%s\n' \
    "waybar|waybar/style.css|waybar/themes/${tema}.css" \
    "swaync|swaync/style.css|swaync/themes/${tema}.css" \
    "wofi|wofi/style.css|wofi/themes/${tema}.css" \
    "sway|sway/themes/current.conf|sway/themes/${tema}.conf" \
    "swaylock|swaylock/config|swaylock/themes/${tema}.conf" \
    "wob|wob/wob.ini|wob/themes/${tema}.ini"
}

# Una app está desplegada cuando existe su directorio en $CONFIG_HOME. Las que
# no están se saltean: un escritorio puede tener sólo sway+waybar aplicados y el
# tema tiene que cambiar lo que existe en vez de fallar por lo que falta (el
# autostart re-aplica el tema en cada inicio, así que un fallo acá dejaría el
# tema a medias en cada login).
app_desplegada() {
  [[ -d "${CONFIG_HOME}/$1" ]]
}

verificar_tema() {
  local tema="$1" app="" enlace="" payload=""
  while IFS='|' read -r app enlace payload; do
    [[ -n "${app}" ]] || continue
    app_desplegada "${app}" || continue
    if [[ ! -f "${CONFIG_HOME}/${payload}" ]]; then
      printf 'ERROR: falta el archivo de tema %s\n' "${CONFIG_HOME}/${payload}" >&2
      return 1
    fi
  done < <(enlaces_de_tema "${tema}")
}

escribir_estado() {
  local tema="$1"
  mkdir -p "${STATE_DIR}"
  printf '%s\n' "${tema}" > "${STATE_FILE}"
}

# Enlaces RELATIVOS: siguen siendo válidos aunque $CONFIG_HOME se mueva, y
# apuntan al archivo de tema del repo sin duplicar contenido. `-n` evita que
# ln siga un enlace existente hacia un directorio. El target se calcula
# quitando el prefijo del directorio del enlace (waybar/style.css ->
# themes/dark.css), para no repetir a mano las seis rutas.
aplicar_enlaces() {
  local tema="$1" app="" enlace="" payload="" dir="" target=""
  while IFS='|' read -r app enlace payload; do
    [[ -n "${app}" ]] || continue
    if ! app_desplegada "${app}"; then
      aviso "aviso: ${app} no está desplegada; se saltea"
      continue
    fi
    dir="$(dirname "${enlace}")"
    target="${payload#"${dir}"/}"
    ln -sfn "${target}" "${CONFIG_HOME}/${enlace}"
  done < <(enlaces_de_tema "${tema}")
}

# foot no usa enlace: [colors-dark] y [colors-light] conviven en foot.ini y solo
# se reescribe initial-color-theme. El resto del archivo queda byte a byte (un
# sed -i sobre un enlace lo reemplazaría por un archivo regular; foot.ini es un
# archivo del repo, no un enlace).
configurar_foot() {
  local tema="$1"
  local ini="${CONFIG_HOME}/foot/foot.ini"
  if [[ ! -f "${ini}" ]]; then
    aviso "aviso: no existe ${ini}; foot no cambia de tema"
    return 0
  fi
  if grep -q '^initial-color-theme=' "${ini}"; then
    sed -i "s/^initial-color-theme=.*/initial-color-theme=${tema}/" "${ini}"
  else
    sed -i "/^\[main\]$/a initial-color-theme=${tema}" "${ini}"
  fi
}

# GTK3 (waybar/wofi) y libadwaita (swaync) siguen el tema vía gsettings. Sin
# gsettings instalado se omite; si falla es un aviso, nunca un error fatal.
configurar_gsettings() {
  local tema="$1"
  command -v gsettings >/dev/null 2>&1 || return 0
  local gtk="Adwaita"
  local esquema="prefer-light"
  if [[ "${tema}" == "dark" ]]; then
    gtk="Adwaita-dark"
    esquema="prefer-dark"
  fi
  if ! gsettings set org.gnome.desktop.interface gtk-theme "${gtk}"; then
    aviso "aviso: no se pudo aplicar gtk-theme ${gtk}"
  fi
  if ! gsettings set org.gnome.desktop.interface color-scheme "${esquema}"; then
    aviso "aviso: no se pudo aplicar color-scheme ${esquema}"
  fi
}

aplicar() {
  local tema="$1"
  aplicar_enlaces "${tema}"
  configurar_foot "${tema}"
  configurar_gsettings "${tema}"
}

# Hay sesión de sway cuando el proceso existe y podemos hablarle: SWAYSOCK
# apunta al socket IPC de sway (o WAYLAND_DISPLAY está definido).
sesion_sway() {
  [[ -n "${SWAYSOCK:-}" || -n "${WAYLAND_DISPLAY:-}" ]]
}

# Las instancias de nvim ya abiertas cambian en vivo a través de su socket en
# $XDG_RUNTIME_DIR (nvim.<pid>.0). Sin XDG_RUNTIME_DIR no hay nada que hacer.
recargar_nvim() {
  [[ -n "${XDG_RUNTIME_DIR:-}" ]] || return 0
  local sock
  for sock in "${XDG_RUNTIME_DIR}/nvim."*.0; do
    [[ -e "${sock}" ]] || continue
    nvim --server "${sock}" --remote-expr 'luaeval("require(\"config.theme\").apply()")' >/dev/null 2>&1 || true
  done
}

# Mata los `tail -f` que quedaron leyendo el FIFO de wob. Se buscan por nombre
# de proceso EXACTO (`pgrep -x tail`) y se confirma el FIFO en
# /proc/<pid>/cmdline: `pkill -f "tail -f ..."` es tentador pero puede matar
# cualquier proceso cuya línea de comando contenga el patrón (se midió: se mata
# a sí mismo cuando el patrón viaja en la línea del shell que lo invoca).
limpiar_tails_fifo() {
  [[ -n "${SWAYSOCK:-}" ]] || return 0
  local pid cmdline
  for pid in $(pgrep -x tail 2>/dev/null || true); do
    cmdline="$(tr '\0' ' ' < "/proc/${pid}/cmdline" 2>/dev/null || true)"
    if [[ "${cmdline}" == *"${SWAYSOCK}.wob"* ]]; then
      kill "${pid}" 2>/dev/null || true
    fi
  done
}

# Recarga las apps YA abiertas. Todo es best-effort: el tema ya quedó aplicado y
# un fallo aquí no debe deshacerlo, así que cada paso tolera errores.
recargar() {
  local tema="$1"

  # foot cambia en vivo: SIGUSR1 para oscuro, SIGUSR2 para claro.
  if [[ "${tema}" == "dark" ]]; then
    pkill -USR1 -x foot >/dev/null 2>&1 || true
  else
    pkill -USR2 -x foot >/dev/null 2>&1 || true
  fi

  # swaync recarga su CSS sin cerrar el panel (solo si está corriendo).
  if command -v swaync-client >/dev/null 2>&1 && pgrep -x swaync >/dev/null 2>&1; then
    swaync-client -rs >/dev/null 2>&1 || true
  fi

  # sway relee client.* con reload, solo si hay sesión.
  if pgrep -x sway >/dev/null 2>&1 && sesion_sway; then
    # wob: el OSD del tema se levanta desde el exec_always del autostart, pero
    # sway NO mata los procesos de exec_always al recargar. Sin limpiar, cada
    # reload deja un par tail|wob más leyendo el mismo FIFO y el OSD muestra
    # colores de temas distintos (o ninguno). Se matan los pares y el reload
    # levanta uno nuevo, ya con el wob.ini del tema activo.
    pkill -x wob >/dev/null 2>&1 || true
    limpiar_tails_fifo
    swaymsg reload >/dev/null 2>&1 || true
  fi

  recargar_nvim

  # Aviso en el escritorio (omitido con --quiet o sin notify-send).
  if [[ "${QUIET}" -eq 0 ]] && command -v notify-send >/dev/null 2>&1; then
    local texto="Modo oscuro"
    [[ "${tema}" == "light" ]] && texto="Modo claro"
    notify-send "Tema" "${texto}" >/dev/null 2>&1 || true
  fi
}

# --- Parseo de argumentos ---
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) uso; exit 0 ;;
    --no-reload) NO_RELOAD=1 ;;
    --quiet) QUIET=1 ;;
    -*) printf 'ERROR: opción desconocida: %s\n' "$1" >&2; uso >&2; exit 2 ;;
    *)
      if [[ -n "${ACCION}" ]]; then
        printf 'ERROR: acción duplicada: %s\n' "$1" >&2
        uso >&2
        exit 2
      fi
      ACCION="$1"
      ;;
  esac
  shift
done

case "${ACCION}" in
  toggle|dark|light|apply|status) ;;
  "")
    printf 'ERROR: falta la acción\n' >&2
    uso >&2
    exit 2
    ;;
  *)
    printf 'ERROR: acción desconocida: %s\n' "${ACCION}" >&2
    uso >&2
    exit 2
    ;;
esac

case "${ACCION}" in
  status)
    tema_actual
    exit 0
    ;;
  apply)
    tema="$(tema_actual)"
    escribir_estado "${tema}"
    aplicar "${tema}"
    aviso "Tema ${tema} reaplicado."
    ;;
  dark|light|toggle)
    if [[ "${ACCION}" == "toggle" ]]; then
      actual="$(tema_actual)"
      if [[ "${actual}" == "light" ]]; then
        tema="dark"
      else
        tema="light"
      fi
    else
      tema="${ACCION}"
    fi
    verificar_tema "${tema}" || exit 1
    escribir_estado "${tema}"
    aplicar "${tema}"
    if [[ "${NO_RELOAD}" -eq 0 ]]; then
      recargar "${tema}"
    fi
    aviso "Tema ${tema} aplicado."
    ;;
esac
