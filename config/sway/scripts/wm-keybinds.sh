#!/usr/bin/env bash
# wm-keybinds: lista los keybindings activos del WM de forma hermosa usando gum y fzf.
# Agnóstico de WM: soporta sway (y i3 con --wm=i3).
#
# Uso:
#   wm-keybinds.sh                Abre una TUI en terminal con fzf y gum.
#   wm-keybinds.sh --gui          Fuerza el uso de Wofi (estilo ventana gráfica).
#   wm-keybinds.sh --list         Imprime la lista por stdout (sin TUI).
#   wm-keybinds.sh --exec         Al elegir un binding "exec ...", lo ejecuta.
#
# Dónde busca los bindsyms:
#   Sway 1.12 no tiene API de bindings: `swaymsg -t bindings` y `-t bindlist`
#   no existen ("Unknown message type") y `swaymsg -t get_config` devuelve solo
#   el texto del archivo raíz, SIN resolver los `include`. La config de este
#   repo es modular (config/sway/config solo tiene `include`; los ~100 bindsyms
#   viven en features/, keybindings/, modes/ y hosts/), así que leer un solo
#   archivo no encuentra nada. Por eso el script resuelve el árbol de includes
#   a mano, igual que hace sway al cargar, y parsea el resultado aplanado.
#   El punto de entrada NO se adivina: se le pregunta a sway con
#   `swaymsg -t get_version | jq -r .loaded_config_file_name`.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Si tienes tu archivo common.sh, descomenta la siguiente línea:
# source "${SCRIPT_DIR}/common.sh"

WM="auto"
LIST_ONLY="false"
EXEC_ONLY="false"
USE_GUI="false"

# --- Estilos Wofi (si se usa --gui) ---
# Vacío = usar /etc/wofi/style.css. Guardamos el override aparte del path por
# defecto para poder chequear con [[ -f ]] antes de pasárselo a wofi: si un día
# el style del sistema no está, wofi corre con su estilo por defecto en vez de
# morir con "no such file". Mismo patrón condicional que dashboard.sh y
# menu-sway.sh.
WOFI_STYLE_OVERRIDE=""
WOFI_WIDTH="900"
WOFI_HEIGHT="600"

for arg in "$@"; do
  case "${arg}" in
    --wm=*)       WM="${arg#*=}" ;;
    --list)       LIST_ONLY="true" ;;
    --exec)       EXEC_ONLY="true" ;;
    --gui)        USE_GUI="true" ;;
    --style=*)    WOFI_STYLE_OVERRIDE="${arg#*=}" ;;
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

# Avisos a stderr a propósito: --list escribe la tabla en stdout y el caller
# puede estar haciendo `wm-keybinds.sh --list | wc -l` o guardándolo en un
# archivo. Un include roto tiene que verse, pero no puede ensuciar la lista.
warn() { printf 'wm-keybinds: %s\n' "$*" >&2; }

# --- 2. Localizar el archivo de configuración REAL ---
# Preferimos el archivo que sway REALMENTE cargó (swaymsg -t get_version) en
# vez del path por convención XDG: si el usuario lanzó sway con
# `sway -c /ruta/alternativa/config`, el path por convención miente y mostraría
# la config equivocada. Sin sesión sway (o sin jq) caemos a la convención.
config_entry=""
case "${WM}" in
  sway)
    if command -v swaymsg &>/dev/null && command -v jq &>/dev/null; then
      config_entry="$(swaymsg -t get_version 2>/dev/null \
        | jq -r '.loaded_config_file_name // empty' 2>/dev/null || true)"
    fi
    if [[ -z "${config_entry}" || ! -f "${config_entry}" ]]; then
      config_entry="${CONFIG_HOME}/sway/config"
    fi
    ;;
  i3)
    config_entry="${CONFIG_HOME}/i3/config"
    ;;
  *)
    echo "WM no soportado: ${WM} (sway|i3)"
    exit 1
    ;;
esac

# --- 3. Aplanar el árbol de includes en un array de líneas ---
# El orden es SEMÁNTICO en sway, no cosmético:
#   - `set $mod Mod4` tiene que leerse antes del bindsym que lo usa.
#   - `unbindsym` tiene que leerse DESPUÉS del bindsym que anula.
# Por eso resolvemos en profundidad respetando el orden textual de cada archivo
# y apilamos las líneas en un array, en vez de concatenar archivos con un
# separador: un separador elegiría mal si la config tuviera una línea vacía o
# un `}` suelto, y un array no puede colisionar con nada.
CONFIG_LINES=()
# Pila de archivos que estamos incluyendo AHORA MISMO. No es un "ya visto":
# un include repetido (diamante A→B→D, A→C→D) es legítimo en sway y se
# procesa dos veces. Solo cortamos cuando el archivo ya está en la pila, que
# es exactamente el caso de ciclo.
INCLUDE_STACK=()

resolver_include() {
  local file="$1" dir line stripped inc_path target dup i depth
  local -a tokens=() targets=() matches=()

  if [[ ! -f "${file}" ]]; then
    warn "no existe: ${file}"
    return 0
  fi
  dir="$(dirname "${file}")"

  while IFS= read -r line || [[ -n "${line}" ]]; do
    # Comentarios primero: un `include` comentado no incluye nada.
    stripped="${line%%#*}"
    stripped="${stripped#"${stripped%%[![:space:]]*}"}"

    if [[ "${stripped}" == include[[:space:]]* ]]; then
      read -ra tokens <<< "${stripped#include}"
      if [[ ${#tokens[@]} -eq 0 ]]; then
        warn "include sin ruta en ${file}"
        continue
      fi
      for inc_path in "${tokens[@]}"; do
        # Regla de sway: un path relativo se resuelve contra el DIRECTORIO
        # del archivo que hace el include, no contra el CWD. Por eso el
        # árbol se puede mover entero sin tocar los includes.
        if [[ "${inc_path}" == /* ]]; then
          targets=("${inc_path}")
        else
          targets=("${dir}/${inc_path}")
        fi

        # Un include puede traer glob (`include keybindings/*.conf`).
        # Usamos compgen -G en vez de depender de una expansión de globs
        # Desactivating nullglob: en bash una asignación `a=("$x")` NO undergo
        # word splitting ni globbing, así que el patrón literal se colaba en
        # la lista como si fuera un archivo y terminaba en el chequeo -f como
        # "include inexistente". compgen -G deja el array vacío cuando el glob
        # no matchea nada, que es justo lo que queremos señalar abajo.
        if [[ "${targets[0]}" == *[\*\?\[]* ]]; then
          mapfile -t matches < <(compgen -G "${targets[0]}")
        else
          matches=("${targets[0]}")
        fi

        if [[ ${#matches[@]} -eq 0 ]]; then
          warn "include inexistente: ${inc_path} (desde ${file})"
          continue
        fi

        for target in "${matches[@]}"; do
          if [[ ! -f "${target}" ]]; then
            warn "include inexistente: ${target} (desde ${file})"
            continue
          fi
          dup=""
          for i in "${INCLUDE_STACK[@]}"; do
            if [[ "${i}" == "${target}" ]]; then dup="1"; break; fi
          done
          if [[ -n "${dup}" ]]; then
            warn "ciclo de include: ${target} se incluye a sí mismo; corte"
            continue
          fi
          depth="${#INCLUDE_STACK[@]}"
          INCLUDE_STACK+=("${target}")
          resolver_include "${target}"
          INCLUDE_STACK=("${INCLUDE_STACK[@]:0:depth}")
        done
      done
      continue   # la línea `include` nunca llega al parser
    fi

    CONFIG_LINES+=("${line}")
  done < "${file}"
}

depth="${#INCLUDE_STACK[@]}"
INCLUDE_STACK+=("${config_entry}")
resolver_include "${config_entry}"
INCLUDE_STACK=("${INCLUDE_STACK[@]:0:depth}")

# --- 4. Recolectar variables y bindsym (Lógica Original Intacta) ---
# Ahora el for corre sobre CONFIG_LINES, no sobre una lista de archivos: es el
# mismo cuerpo de parseo, pero alimentado por el árbol ya aplanado y en orden.
# Un `set` Define y un bindsym Usa pueden vivir en archivos distintos (el $mod
# está en features/variables-colors.conf y los binds en keybindings/*.conf):
# VARS es un único mapa global y la expansión es un post-parse (sección 5), así
# que el orden del include garantiza que las variables existan antes de usarse.
declare -A VARS=()
declare -A idx=()
bind_keys=()
bind_actions=()
bind_modes=()

block=""
block_mode=""
for line in "${CONFIG_LINES[@]}"; do
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
done

# --- 5. Expandir variables ---
sep=$'\x1f'
display_keys=()
display_actions=()
display_modes=()

for i in "${!bind_keys[@]}"; do
  [[ -z "${bind_keys[i]}" ]] && continue
  binding="${bind_keys[i]}"
  action="${bind_actions[i]}"
  mode_prefix="${bind_modes[i]}"

  # Separador key/action: US (0x1F, unit separator), un carácter de control
  # que no puede aparecer en una config de sway ni colisionar con un pipe, una
  # barra o un tab. Antes el script usaba '§' para DOS cosas a la vez —
  # separar key de action y proteger los '$$' de un exec — y el `§`→`$` de
  # cierre destruía la separación: `%%§*` y `#*§` no encontraban nada, así que
  # key y action salían pegados ("Mod4+comma$exec dashboard.sh") y la lista
  # era ilegible. Un solo separador, y la protección de '$$' desaparece: no
  # hacía falta (el bucle sustituye $nombre, nunca $$) y además era falsa,
  # porque convertía `echo $$HOME` en `echo $HOME`.
  protected="${binding}${sep}${action}"
  # Nombres de variable de MÁS largo a MÁS corto: $color-primary tiene que
  # sustituirse antes que $color, o el prefijo corto se comería al largo
  # ($color-primary -> #6da741-primary). El largo se ordena con printf
  # %04d + `sort -rn` en vez del `awk | sort -rn | cut -f2` de antes: el padding
  # de ancho fijo ordena igual aunque mixes longitudes 4 y 12 (sort numérico
  # sobre "4" vs "12" no), y el `for` no emite nada cuando VARS está vacío
  # (antes podía colar un nombre vacío y romper con "bad array subscript").
  for name in $(for n in "${!VARS[@]}"; do printf '%04d %s\n' "${#n}" "${n}"; done \
                  | sort -rn | cut -d' ' -f2-); do
    value="${VARS["${name}"]}"
    protected="${protected//\$${name}/${value}}"
  done
  binding="${protected%%${sep}*}"
  action="${protected#*${sep}}"

  display_keys+=("${mode_prefix}${binding}")
  display_actions+=("${action}")
done

describe() {
  local a="${1,,}"
  case "${a}" in
    *'kill'*|*'close'*)               echo "Cerrar ventana" ;;
    *'exec $launcher'*|*wofi*|*dmenu*|*bemenu*) echo "Lanzador de aplicaciones" ;;
    *'exec $terminal'*|*alacritty*|*foot*|*kitty*|*wezterm*|*konsole*) echo "Abrir terminal" ;;
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

# --- 6. Formateo y Presentación Visual ---

# Preparamos la salida tabular usando un Array para conservar los saltos de línea
display=()
for i in "${!display_keys[@]}"; do
  [[ -z "${display_keys[i]}" ]] && continue
  desc="$(describe "${display_actions[i]}")"
  # Guardamos cada fila como un elemento del array, separados por tabulaciones
  display+=("$(printf "%s\t%s\t%s" "${display_keys[i]}" "${desc}" "${display_actions[i]}")")
done

# Lista vacía: antes `printf '%s\n' "${display[@]}"` sobre un array vacío
# imprimía una línea en blanco y --list devolvía "1 línea vacía" sin ningún
# error visible, que es el síntoma que escondía este bug. Ahora avisamos a
# stderr y no emitimos nada.
if [[ ${#display[@]} -eq 0 ]]; then
  warn "no se encontró ningún bindsym en ${config_entry}"
  exit 0
fi

# Opción 1: Solo imprimir lista
if [[ "${LIST_ONLY}" == "true" ]]; then
  printf '%s\n' "${display[@]}" | awk -F'\t' '{printf "%-25s | %-40s | %s\n", $1, $2, $3}'
  exit 0
fi

selection=""

# Opción 2: Usar Wofi (Modo Gráfico Original)
if [[ "${USE_GUI}" == "true" ]]; then
  if command -v wofi &>/dev/null; then
    # Mismo armado condicional que dashboard.sh/menu-sway.sh: sólo se le pasa
    # --conf/--style si el archivo existe, así un /etc/wofi incompleto no
    # rompe el menú (wofi corre con su estilo por defecto).
    WOFI_OPTS=(--dmenu --insensitive)
    [[ -f /etc/wofi/config ]] && WOFI_OPTS+=(--conf /etc/wofi/config)
    wofi_style="${WOFI_STYLE_OVERRIDE:-/etc/wofi/style.css}"
    [[ -f "${wofi_style}" ]] && WOFI_OPTS+=(--style "${wofi_style}")
    selection=$(printf '%s\n' "${display[@]}" | awk -F'\t' '{printf "%-25s | %s\n", $1, $2}' | wofi "${WOFI_OPTS[@]}" --width "${WOFI_WIDTH}" --height "${WOFI_HEIGHT}" --prompt 'Keybindings > ' || true)
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

# --- 7. Ejecutar Acción Seleccionada ---
if [[ "${EXEC_ONLY}" == "true" ]]; then
  # Extraemos el comando real que estaba oculto en la cadena (o al final en Wofi)
  
  if [[ "${USE_GUI}" == "true" ]]; then
     # Para wofi, necesitamos re-mapear la selección a su comando original
     key_selected=$(echo "$selection" | awk -F' \\| ' '{print $1}')
     # La fila que ve wofi viene de un `printf "%-25s | %s"`, así que awk se
     # lleva el padding de ancho fijo pegado a la key. Sin recortar, el match
     # exacto contra display_keys NUNCA dispara, `action` conserva el valor
     # viejo del loop de parseo y el script ejecuta el comando de otro
     # binding: elegir "Mod4+Return" corría swaync-client. Trimeamos con el
     # mismo idiom que usa el parser para normalizar líneas.
     key_selected="${key_selected#"${key_selected%%[![:space:]]*}"}"
     key_selected="${key_selected%"${key_selected##*[![:space:]]}"}"
     # Buscamos el key_selected exacto en el arreglo (incluye el prefijo de
     # modo, así que "[resize] h" y "h" no se confunden).
     action=""
     for i in "${!display_keys[@]}"; do
        if [[ "${display_keys[i]}" == "${key_selected}" ]]; then
           action="${display_actions[i]}"
           break
        fi
     done
     # Sin match no adivinamos: antes `action` quedaba con el residuo del
     # parseo y disparaba un comando arbitrario.
     if [[ -z "${action}" ]]; then
        warn "no se pudo mapear la selección '${key_selected}' a un binding; no se ejecuta nada"
        exit 0
     fi
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

