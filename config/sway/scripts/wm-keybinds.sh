#!/usr/bin/env bash
# wm-keybinds: lista los keybindings activos del WM de forma hermosa usando gum y fzf.
# Agnóstico de WM: soporta sway (y i3 con --wm=i3).
#
# Uso:
#   wm-keybinds.sh                Abre una TUI en terminal con fzf y gum.
#   wm-keybinds.sh --gui          Fuerza el uso de Wofi (estilo ventana gráfica).
#   wm-keybinds.sh --list         Imprime la lista por stdout (sin TUI).
#   wm-keybinds.sh --exec         Al elegir un binding "exec ...", lo ejecuta.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Si tienes tu archivo common.sh, descomenta la siguiente línea:
# source "${SCRIPT_DIR}/common.sh"

WM="auto"
LIST_ONLY="false"
EXEC_ONLY="false"
USE_GUI="false"

# --- Estilos Wofi (si se usa --gui) ---
WOFI_STYLE="/etc/wofi/style.css"
WOFI_WIDTH="900"
WOFI_HEIGHT="600"

for arg in "$@"; do
  case "${arg}" in
    --wm=*)       WM="${arg#*=}" ;;
    --list)       LIST_ONLY="true" ;;
    --exec)       EXEC_ONLY="true" ;;
    --gui)        USE_GUI="true" ;;
    --style=*)    WOFI_STYLE="${arg#*=}" ;;
    *)            echo "Argumento desconocido: ${arg}"; exit 1 ;;
  esac
done

# --- 1. Detectar WM (Lógica Original Intacta) ---
if [[ "${WM}" == "auto" ]]; then
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *i3* || "${DESKTOP_SESSION:-}" == *i3* ]]; then
    WM="i3"
  elif [[ -S "${SWAYSOCK:-}" || "${XDG_CURRENT_DESKTOP:-}" == *sway* ]]; then
    WM="sway"
  else
    WM="sway"
  fi
fi

CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

case "${WM}" in
  sway)
    # Config autocontenida: ya no se incluye /etc/sway/config.d/*.conf.
    # Se lee la config aplicada + drop-ins opcionales si el usuario los crea.
    FILES=("${CONFIG_HOME}/sway/config")
    FILES+=("${CONFIG_HOME}/sway/config.d/"*.conf)
    ;;
  i3)
    FILES=("${CONFIG_HOME}/i3/config")
    ;;
  *)
    echo "WM no soportado: ${WM} (sway|i3)"
    exit 1
    ;;
esac

# --- 2. Recolectar variables y bindsym (Lógica Original Intacta) ---
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
      while [[ ${#tokens[@]} -gt 0 && "${tokens[0]}" == --* ]]; do
        tokens=("${tokens[@]:1}")
      done
      if [[ ${#tokens[@]} -ge 2 ]]; then
        key="${tokens[0]}"
        action="${tokens[*]:1}"
      fi
    elif [[ -n "${block}" ]]; then
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

# --- 3. Expandir variables ---
display_keys=()
display_actions=()
display_modes=()

for i in "${!bind_keys[@]}"; do
  [[ -z "${bind_keys[i]}" ]] && continue
  binding="${bind_keys[i]}"
  action="${bind_actions[i]}"
  mode_prefix="${bind_modes[i]}"

  protected="${binding}§${action}"
  protected="${protected//\$\$/§}"
  for name in $(printf '%s\n' "${!VARS[@]}" | awk '{ print length, $0 }' | sort -rn | cut -d' ' -f2); do
    value="${VARS["${name}"]}"
    protected="${protected//\$${name}/${value}}"
  done
  protected="${protected//§/\$}"
  binding="${protected%%§*}"
  action="${protected#*§}"

  display_keys+=("${mode_prefix}${binding}")
  display_actions+=("${action}")
done

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
    *playerctl*)                      echo "Multimedia (reproducir/siguiente)" ;;
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

# --- 4. Formateo y Presentación Visual ---

# Preparamos la salida tabular usando un Array para conservar los saltos de línea
display=()
for i in "${!display_keys[@]}"; do
  [[ -z "${display_keys[i]}" ]] && continue
  desc="$(describe "${display_actions[i]}")"
  # Guardamos cada fila como un elemento del array, separados por tabulaciones
  display+=("$(printf "%s\t%s\t%s" "${display_keys[i]}" "${desc}" "${display_actions[i]}")")
done

# Opción 1: Solo imprimir lista
if [[ "${LIST_ONLY}" == "true" ]]; then
  printf '%s\n' "${display[@]}" | awk -F'\t' '{printf "%-25s | %-40s | %s\n", $1, $2, $3}'
  exit 0
fi

selection=""

# Opción 2: Usar Wofi (Modo Gráfico Original)
if [[ "${USE_GUI}" == "true" ]]; then
  if command -v wofi &>/dev/null; then
    selection=$(printf '%s\n' "${display[@]}" | awk -F'\t' '{printf "%-25s | %s\n", $1, $2}' | wofi --dmenu --insensitive --width "${WOFI_WIDTH}" --height "${WOFI_HEIGHT}" --style "${WOFI_STYLE}" --prompt 'Keybindings > ' || true)
  else
    echo "Wofi no instalado."
    exit 1
  fi

# Opción 3: Usar Terminal TUI con Gum y FZF (Nueva y hermosa)
else
  # Verifica dependencias
  if ! command -v fzf &>/dev/null || ! command -v gum &>/dev/null; then
      echo "Para la TUI necesitas instalar 'fzf' y 'gum'."
      exit 1
  fi

  # Encabezado bonito con Gum
  gum style --border normal --margin "1" --padding "1 2" --border-foreground 212 "⌨️  Keybindings del Window Manager (${WM})"

  # Usamos printf para volcar el array línea por línea hacia fzf
  selection=$(printf '%s\n' "${display[@]}" | awk -F'\t' '{printf "%-25s\033[90m|\033[0m%-28s\033[8m%s\033[0m\n", $1, $2, $3}' | \
      fzf --ansi \
          --prompt="🔍 Buscar: " \
          --pointer="▶" \
          --color="prompt:#ff79c6,pointer:#50fa7b,hl+:#8be9fd" \
          --layout=reverse \
          --border=rounded)
fi


[[ -z "${selection}" ]] && exit 0

echo "${selection}"

# --- 5. Ejecutar Acción Seleccionada ---
if [[ "${EXEC_ONLY}" == "true" ]]; then
  # Extraemos el comando real que estaba oculto en la cadena (o al final en Wofi)
  
  if [[ "${USE_GUI}" == "true" ]]; then
     # Para wofi, necesitamos re-mapear la selección a su comando original 
     key_selected=$(echo "$selection" | awk -F' \\| ' '{print $1}')
     # Buscamos el key_selected exacto en el arreglo
     for i in "${!display_keys[@]}"; do
        if [[ "${display_keys[i]}" == "${key_selected}" ]]; then
           action="${display_actions[i]}"
           break
        fi
     done
  else
     # En fzf está oculto al final gracias a los códigos ANSI, lo extraemos
     action=$(echo "$selection" | sed -E 's/.*\x1b\[8m(.*)\x1b\[0m.*/\1/')
  fi
  
  if [[ "${action}" == exec\ * ]]; then
    cmd="${action#exec }"
    # Pequeño feedback con gum si se ejecuta en terminal
    [[ "${USE_GUI}" != "true" ]] && gum spin --spinner dot --title "Ejecutando: $cmd" -- sleep 0.5
    
    if command -v swaymsg &>/dev/null; then
      swaymsg exec -- "${cmd}" >/dev/null 2>&1 || true
    else
      echo "swaymsg no disponible; no se ejecuta: ${cmd}"
    fi
  fi
fi

