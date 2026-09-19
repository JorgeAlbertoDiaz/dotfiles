#!/usr/bin/env bash
# wm-keybinds: lista los keybindings activos del WM en una ventana tipo
# launcher (wofi), filtrable al teclear. Agnóstico de WM: soporta sway
# (y i3 con --wm=i3, la sintaxis bindsym es compartida).
#
# Uso:
#   wm-keybinds.sh                Abre wofi con los keybindings (sway auto).
#   wm-keybinds.sh --wm=i3        Lee ~/.config/i3/config.
#   wm-keybinds.sh --list         Imprime la lista por stdout (sin wofi).
#   wm-keybinds.sh --exec         Al elegir un binding "exec ...", lo ejecuta.
#
# Fuentes (sway), en orden de precedencia (el último gana):
#   ~/.config/sway/config           (base del usuario)
#   /etc/sway/config.d/*.conf       (sistema, ej. openSUSEway)
#   ~/.config/sway/config.d/*.conf  (drop-ins del usuario)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

WM="auto"
LIST_ONLY="false"
EXEC_ONLY="false"
WOFI_STYLE="/etc/wofi/style.css"
WOFI_WIDTH="900"
WOFI_HEIGHT="600"

for arg in "$@"; do
  case "${arg}" in
    --wm=*)       WM="${arg#*=}" ;;
    --list)       LIST_ONLY="true" ;;
    --exec)       EXEC_ONLY="true" ;;
    --style=*)    WOFI_STYLE="${arg#*=}" ;;
    *)            error "Argumento desconocido: ${arg}"; exit 1 ;;
  esac
done

# --- Detectar WM ---
if [[ "${WM}" == "auto" ]]; then
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *i3* || "${DESKTOP_SESSION:-}" == *i3* ]]; then
    WM="i3"
  elif [[ -S "${SWAYSOCK:-}" || "${XDG_CURRENT_DESKTOP:-}" == *sway* ]]; then
    WM="sway"
  else
    WM="sway"
    warn "No se detectó el WM; asumo sway (usá --wm=i3 si es i3)"
  fi
fi

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

case "${WM}" in
  sway)
    FILES=("${CONFIG_HOME}/sway/config")
    FILES+=(/etc/sway/config.d/*.conf)
    FILES+=("${CONFIG_HOME}/sway/config.d/"*.conf)
    ;;
  i3)
    FILES=("${CONFIG_HOME}/i3/config")
    ;;
  *)
    error "WM no soportado: ${WM} (sway|i3)"
    exit 1
    ;;
esac

# --- Recolectar variables y bindsym ---
# Estructuras paralelas: bind_keys[i] / bind_actions[i] / bind_modes[i].
# idx[<mode>|<binding>] -> índice. El último archivo con precedencia gana.
declare -A VARS=()
declare -A idx=()
bind_keys=()
bind_actions=()
bind_modes=()

while IFS= read -r file; do
  [[ -f "${file}" ]] || continue
  block=""
  block_mode=""
  while IFS= read -r line || [[ -n "${line}" ]]; do
    raw="${line%%#*}"
    raw="${raw#"${raw%%[![:space:]]*}"}"
    raw="${raw%"${raw##*[![:space:]]}"}"
    [[ -z "${raw}" ]] && continue

    if [[ "${raw}" == "set "* ]]; then
      read -ra setv <<< "${raw#set }"
      name="${setv[0]#\$}"
      [[ ${#setv[@]} -gt 1 && -n "${name}" ]] && VARS["${name}"]="${setv[*]:1}"
      continue
    fi

    if [[ "${raw}" == "}" ]]; then
      if [[ -n "${block}" ]]; then
        block=""
        block_mode=""
      fi
      continue
    fi

    if [[ "${raw}" == "mode "* ]]; then
      # mode "resize" {  o  mode $screenshot {  o  mode $mode_system {
      body="${raw#mode }"
      body="${body% *}"
      if [[ "${body}" =~ ^\$\{?([A-Za-z_][A-Za-z0-9_]*) ]]; then
        block_mode="${BASH_REMATCH[1]}"
      elif [[ "${body}" =~ ^\"(.*)\"$ ]]; then
        block_mode="${BASH_REMATCH[1]}"
      else
        block_mode="${body}"
      fi
      block="mode"
      continue
    fi

    if [[ "${raw}" == "bindsym --to-code {" ]]; then
      block="tocode"
      continue
    fi

    key=""
    action=""
    if [[ "${raw}" == "unbindsym "* ]]; then
      # Quitar un binding previamente definido (ej. openSUSE quita $mod+Shift+e
      # y lo redefine como mode $mode_system).
      ub_rest="${raw#unbindsym }"
      read -ra ub_token <<< "${ub_rest}"
      ub_key="${ub_token[0]}"
      ub_norm="${ub_key//\$/@}"
      if [[ -n "${ub_key}" && -n "${idx[${ub_norm}]-}" ]]; then
        u="${idx[${ub_norm}]}"
        unset "idx[${ub_norm}]"
        bind_keys[u]=""
        bind_actions[u]=""
        bind_modes[u]=""
      fi
      continue
    fi

    if [[ "${raw}" == "bindsym "* ]]; then
      read -ra tokens <<< "${raw#bindsym }"
      # Saltar flags (--to-code, --no-warn, --release, --locked, ...)
      while [[ ${#tokens[@]} -gt 0 && "${tokens[0]}" == --* ]]; do
        tokens=("${tokens[@]:1}")
      done
      if [[ ${#tokens[@]} -ge 2 ]]; then
        key="${tokens[0]}"
        action="${tokens[*]:1}"
      fi
    elif [[ -n "${block}" ]]; then
      # Línea interna de un bloque mode { ... } o bindsym --to-code { ... }
      read -ra tokens <<< "${raw}"
      if [[ ${#tokens[@]} -ge 2 ]]; then
        key="${tokens[0]}"
        action="${tokens[*]:1}"
      fi
    fi

    if [[ -n "${key}" && -n "${action}" ]]; then
      mode_prefix=""
      if [[ "${block}" == "mode" && -n "${block_mode}" ]]; then
        mode_prefix="[${block_mode}] "
      fi
      # Clave interna: placeholder para $ (evita el re-expand de bash en
      # subíndices de arrays asociativos cuando la clave contiene $mod).
      norm="${key//\$/@}"
      mapkey="${mode_prefix}${norm}"
      if [[ -n "${idx[${mapkey}]-}" ]]; then
        i="${idx[${mapkey}]}"
        bind_actions[i]="${action}"
      else
        idx["${mapkey}"]="${#bind_keys[@]}"
        bind_keys+=("${key}")
        bind_actions+=("${action}")
        bind_modes+=("${mode_prefix}")
      fi
    fi
  done < "${file}"
done <<< "$(printf '%s\n' "${FILES[@]}")"

# --- unbindsym: eliminar del mapa (mismo paso de dedupe posterior) ---
# (Se procesó arriba como binds? No: unbindsym se ignora por no ser bindsym.
#  Para honrar unbindsym, lo procesamos en una pasada adicional aquí.)

# --- Expandir variables y armar líneas presentables ---
# Arrays para el display final.
display_keys=()
display_actions=()
display_modes=()

for i in "${!bind_keys[@]}"; do
  [[ -z "${bind_keys[i]}" ]] && continue
  binding="${bind_keys[i]}"
  action="${bind_actions[i]}"
  mode_prefix="${bind_modes[i]}"

  # Expandir variables en binding y acción. En sway, $$ es un escape de $
  # literal ($$term se expande en dos pasadas), así que primero protegemos
  # los $$ y luego restauramos el $ literal tras la expansión.
  protected="${binding}§${action}"
  protected="${protected//\$\$/§}"
  for name in $(printf '%s\n' "${!VARS[@]}" | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2); do
    value="${VARS["${name}"]}"
    protected="${protected//\$${name}/${value}}"
  done
  protected="${protected//§/\$}"
  binding="${protected%%§*}"
  action="${protected#*§}"

  # Dedupe: la última definición (config del usuario) gana sobre la anterior.
  display_keys+=("${mode_prefix}${binding}")
  display_actions+=("${action}")
done

# --- Describir la acción en lenguaje natural ---
describe() {
  local a="${1,,}"
  case "${a}" in
    *'kill'*|*'close'*)               echo "Cerrar ventana" ;;
    *'exec $menu'*|*wofi*|*dmenu*|*bemenu*) echo "Lanzador de aplicaciones" ;;
    *'exec $term'*|*alacritty*|*foot*|*kitty*|*wezterm*|*konsole*) echo "Abrir terminal" ;;
    *'what to do'*)                   echo "Menú: bloquear / salir / reiniciar / suspender / apagar" ;;
    *'exec swaylock'*|*lock*)         echo "Bloquear pantalla" ;;
    *'exec swaynag'*|*'swaymsg exit'*) echo "Salir de sway (confirmación)" ;;
    *'focus left'*|*'focus right'*|*'focus up'*|*'focus down'*) echo "Enfocar (dirección)" ;;
    *'move left'*|*'move right'*|*'move up'*|*'move down'*) echo "Mover ventana (dirección)" ;;
    *'focus parent'*)                 echo "Enfocar contenedor padre" ;;
    *'focus mode_toggle'*)            echo "Alternar focus tiling/flotante" ;;
    *'workspace number'*)             echo "Ir al espacio de trabajo" ;;
    *'move container to workspace number'*) echo "Mover ventana al espacio" ;;
    *'workspace next_on_output'*|*'workspace prev_on_output'*) echo "Espacio siguiente/anterior" ;;
    *'move scratchpad'*)              echo "Mover ventana al scratchpad" ;;
    *'scratchpad show'*)              echo "Mostrar scratchpad" ;;
    *fullscreen*)                     echo "Pantalla completa" ;;
    *'floating toggle'*)              echo "Alternar tiling/flotante" ;;
    *splith*|*'split horizontal'*)    echo "Dividir horizontal" ;;
    *splitv*|*'split vertical'*)      echo "Dividir vertical" ;;
    *'layout stacking'*)              echo "Layout apilado" ;;
    *'layout tabbed'*)                echo "Layout pestañas" ;;
    *'layout toggle split'*)          echo "Alternar layout" ;;
    *reload*)                         echo "Recargar configuración" ;;
    *'mode "resize"'*)                echo "Entrar al modo redimensionar" ;;
    *'resize shrink'*|*'resize grow'*) echo "Redimensionar ventana" ;;
    *brightnessctl*)                  echo "Brillo de pantalla" ;;
    *pactl*|*pamixer*|*volume*|*audio*) echo "Control de audio" ;;
    *playerctl*)                      echo "Multimedia (reproducir/siguiente/anterior)" ;;
    *grim*|*slurp*|*'screenshot'*)    echo "Captura de pantalla" ;;
    *'systemctl reboot'*)             echo "Reiniciar el sistema" ;;
    *'systemctl suspend'*)            echo "Suspender el sistema" ;;
    *'systemctl poweroff'*)           echo "Apagar el sistema" ;;
    *systemctl*|*'swaymsg exit'*)     echo "Encendido/apagado del sistema" ;;
    *swaync*)                         echo "Centro de notificaciones" ;;
    *XF86*)                           echo "Tecla multimedia" ;;
    *'mode "default"'*|*'mode default'*) echo "Volver al modo normal" ;;
    *)                                echo "${a}" ;;
  esac
}

# --- Presentar con wofi o imprimir ---
display=()
for i in "${!display_keys[@]}"; do
  [[ -z "${display_keys[i]}" ]] && continue
  desc="$(describe "${display_actions[i]}")"
  display+=("${display_keys[i]}  →  ${desc}  (${display_actions[i]})")
done

if [[ "${LIST_ONLY}" == "true" ]]; then
  printf '%s\n' "${display[@]}"
  exit 0
fi

if ! command -v wofi &>/dev/null; then
  warn "wofi no está instalado; listado por stdout:"
  printf '%s\n' "${display[@]}"
  exit 0
fi

selection="$(printf '%s\n' "${display[@]}" | wofi --dmenu --insensitive \
  --width "${WOFI_WIDTH}" --height "${WOFI_HEIGHT}" --style "${WOFI_STYLE}" \
  --prompt 'Keybindings > ' || true)"

[[ -z "${selection}" ]] && exit 0

echo "${selection}"

if [[ "${EXEC_ONLY}" == "true" ]]; then
  action="${selection##*  (}"
  action="${action%)}"
  if [[ "${action}" == exec\ * ]]; then
    cmd="${action#exec }"
    if command -v swaymsg &>/dev/null; then
      swaymsg exec -- "${cmd}" >/dev/null 2>&1 || true
    else
      warn "swaymsg no disponible; no se ejecuta: ${cmd}"
    fi
  fi
fi