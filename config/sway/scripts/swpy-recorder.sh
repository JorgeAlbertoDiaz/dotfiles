#!/usr/bin/env bash
# swpy-recorder.sh — grabador de video (wf-recorder) con semántica de toggle.
#
# Uso:
#   swpy-recorder.sh              # equivale a "full"
#   swpy-recorder.sh full         # pantalla completa
#   swpy-recorder.sh area         # área elegida con slurp
#
# La PRIMERA pulsación arranca wf-recorder en background y devuelve el control
# al instante; la SEGUNDA lo detiene con SIGINT para que wf-recorder cierre y
# finalice el archivo. El modo se ignora si ya hay una grabación activa: una
# sola tecla arranca y para.
#
# wf-recorder no adivina el monitor: sin -o pide uno por stdin y, como acá
# corre sin stdin, muere al instante. Por eso el output se resuelve antes
# (preferentemente el que está enfocado) y se pasa siempre explícito.
set -euo pipefail

PIDFILE="${XDG_RUNTIME_DIR:-/tmp}/swpy-recorder.pid"
SUBDIR='Screenshots'
MODO_POR_DEFECTO='full'

# ¿El PID guardado sigue siendo un wf-recorder vivo? Un pidfile obsoleto
# (por ejemplo, una grabación que murió sola) no debe provocar un arranque doble.
pid_activo() {
  local pid="$1" comm
  [[ -n "${pid}" ]] || return 1
  kill -0 "${pid}" 2>/dev/null || return 1
  # /proc evita mandar el SIGINT a un PID reciclado por otro proceso.
  if [[ -r "/proc/${pid}/comm" ]]; then
    comm="$(<"/proc/${pid}/comm")" || return 1
    [[ "${comm}" == 'wf-recorder' ]] || return 1
  fi
  return 0
}

# Carpeta de destino. Mismo criterio escalonado que downloads_dir() en
# scripts/common.sh: nada de hardcodear $HOME/Pictures, que no existe en un
# sistema en español.
directorio_destino() {
  local dir
  if command -v xdg-user-dir &>/dev/null \
      && dir="$(xdg-user-dir PICTURES 2>/dev/null)" \
      && [[ -n "${dir}" && "${dir}" != "${HOME}" ]]; then
    :
  elif [[ -n "${XDG_PICTURES_DIR:-}" ]]; then
    dir="${XDG_PICTURES_DIR}"
  elif [[ -d "${HOME}/Imágenes" ]]; then
    dir="${HOME}/Imágenes"
  else
    dir="${HOME}/Pictures"
  fi
  printf '%s\n' "${dir}/${SUBDIR}"
}

# Nombre del output donde grabar, por stdout. Escribe el motivo por stderr y
# devuelve 1 si no puede determinarlo: nunca deja que wf-recorder pregunte.
#
# Sin argumentos (modo full) elige el output ENFOCADO, que es el que el usuario
# está mirando. Con una geometría "x,y WxH" (modo area) elige en cambio el
# output que CONTIENE esa geometría: en Sway el foco sigue a la ventana
# enfocada, no al puntero, así que arrastrar el mouse sobre el monitor
# secundario no cambia el foco y el output enfocado puede ser otro. Pasarle a
# wf-recorder un -o que no contiene la región hace que grabe el monitor entero
# sin avisar ("Bad geometry" no aparece cuando la geometría es válida pero
# cae fuera del output elegido).
#
# Se parsea con python3 y no con jq a propósito. jq es la convención del repo
# (features/screenshots.conf usa `jq -r '.[] | select(.focused) | .name'`),
# pero acá no se lo da por sentado: python3 viene siempre en el sistema, así
# este script no depende de un paquete opcional para funcionar. El JSON igual
# se valida y se informa qué se buscó y qué se encontró.
resolver_salida() {
  local json geometria="${1:-}"

  if ! json="$(swaymsg -t get_outputs 2>/dev/null)" || [[ -z "${json}" ]]; then
    echo "No pude consultar los outputs de Sway con 'swaymsg -t get_outputs'; no hay forma de saber en qué monitor grabar." >&2
    return 1
  fi

  printf '%s' "${json}" | python3 -c '
import json, sys

geometria = sys.argv[1] if len(sys.argv) > 1 else ""

try:
    outputs = json.load(sys.stdin)
except ValueError as exc:
    print("swaymsg -t get_outputs no devolvió JSON válido: " + str(exc), file=sys.stderr)
    sys.exit(1)

if not isinstance(outputs, list) or not outputs:
    print("swaymsg -t get_outputs no devolvió ningún output.", file=sys.stderr)
    sys.exit(1)

nombres = ", ".join(str(o.get("name")) for o in outputs) or "ninguno"
active = [o for o in outputs if o.get("active")]

if not active:
    print("La sesión de Sway no tiene ningún output activo (encontrados: "
          + nombres + ").", file=sys.stderr)
    sys.exit(1)

def contiene(o, x, y, w, h):
    r = o.get("rect") or {}
    try:
        return (int(r["x"]) <= x and int(r["y"]) <= y
                and x + w <= int(r["x"]) + int(r["width"])
                and y + h <= int(r["y"]) + int(r["height"]))
    except (KeyError, TypeError, ValueError):
        return False

elegido = None
origen = ""

if geometria:
    # slurp emite "x,y WxH": la coma separa x de y, el ancho y el alto vienen
    # unidos por una "x" (640x480 es UN token, no dos).
    partes = geometria.replace(",", " ").split()
    if len(partes) == 3 and "x" in partes[-1]:
        partes = partes[:-1] + partes[-1].split("x")
    if len(partes) == 4:
        try:
            gx, gy, gw, gh = (int(v) for v in partes)
        except ValueError:
            gx = gy = gw = gh = None
        if gw is not None:
            for o in active:
                if contiene(o, gx, gy, gw, gh):
                    elegido = o
                    origen = "contiene la selección " + geometria
                    break
            if elegido is None:
                print("La selección " + geometria + " no cae dentro de un único output "
                      + "(" + nombres + "); puede abarcar dos monitores. "
                      "Grabo el output enfocado, que puede no ser el que seleccionaste.",
                      file=sys.stderr)

if elegido is None:
    focused = [o for o in active if o.get("focused")]
    if focused:
        elegido = focused[0]
        origen = "está enfocado"
    else:
        elegido = active[0]
        origen = "primer output activo (ninguno está enfocado)"
        print("Ningún output activo tiene focused=true; grabo en el primero activo: "
              + str(elegido.get("name")), file=sys.stderr)

name = elegido.get("name")
if not name:
    print("El output elegido no tiene campo name; no puedo pasarle -o a wf-recorder "
          "(encontrados: " + nombres + ").", file=sys.stderr)
    sys.exit(1)

sys.stderr.write("Output a grabar: " + str(name) + " (" + origen + ").\n")
print(name)
' "${geometria}"
}

iniciar() {
  local modo="$1" destino archivo pid salida geometria
  destino="$(directorio_destino)"
  mkdir -p "${destino}"
  # Contenedor Matroska, no MP4. El build de openSUSE usa utvideo (lossless,
  # el codec que sí acepta el pixel format gbrp que le pasa wf-recorder) y
  # utvideo no está soportado en MP4: ffmpeg aborta con "Could not find tag
  # for codec utvideo in stream #0". No es negociable con -c porque este
  # build de libavcodec no trae ningún otro encoder que acepte gbrp
  # (no hay h264/libx264/vp9, y mpeg4/mjpeg/ffv1 rechazan gbrp). Además .mkv
  # es válido con cualquier otro codec por defecto en otras distros, así que
  # el archivo sigue siendo portable.
  #
  # OJO: utvideo es lossless, así que estos videos pesan mucho (~7 MB/s a
  # 1080p). Para archivos chicos hace falta un build de ffmpeg con x264.
  archivo="${destino}/video_${modo}_$(date +%Y%m%d_%H%M%S).mkv"

  if [[ "${modo}" == 'area' ]]; then
    # Geometría de slurp pasada como ARGUMENTO, no por stdin.
    #
    # OJO: "-g-" es la sintaxis de GRIM, no de wf-recorder. wf-recorder no
    # tiene ninguna ruta de lectura por stdin: su -g espera el formato literal
    # "x,y WxH", así que "-g-" se interpreta como la geometría "-" y responde
    # "Bad geometry: -, capturing whole output instead." — o sea, graba la
    # pantalla ENTERA en silencio, como si hubiera respetado la selección.
    # Por eso slurp se corre primero y su salida se valida antes de grabar.
    if ! geometria="$(slurp)"; then
      echo "slurp no devolvió geometría (¿selección cancelada?); no se graba nada." >&2
      return 1
    fi
    geometria="${geometria//$'\n'/ }"
    if [[ ! "${geometria}" =~ ^[0-9]+,[0-9]+[[:space:]]+[0-9]+x[0-9]+$ ]]; then
      echo "Geometría inválida desde slurp: '${geometria}'; no se graba nada." >&2
      return 1
    fi
    # Con geometría: el output se deduce de la región seleccionada, no del
    # foco (ver resolver_salida), así que se resuelve después de slurp.
    salida="$(resolver_salida "${geometria}")" || return 1
  else
    salida="$(resolver_salida)" || return 1
  fi

  # Una sola invocación, y SIEMPRE con -o: la geometría no le dice a
  # wf-recorder a qué monitor pertenece, así que sin esto vuelve a pedirlo por
  # stdin y muere al instante (que es el bug que se arregla acá).
  local -a args
  args=(-o "${salida}")
  if [[ "${modo}" == 'area' ]]; then
    args+=(-g "${geometria}")
  fi
  args+=(-f "${archivo}")
  wf-recorder "${args[@]}" &
  pid=$!
  printf '%s\n' "${pid}" >"${PIDFILE}"

  # wf-recorder puede morir al instante (binario roto, sin permisos): no
  # prometamos una grabación que no existe.
  sleep 0.4
  if ! pid_activo "${pid}"; then
    rm -f "${PIDFILE}"
    echo "wf-recorder no pudo iniciar la grabación; revisá que funcione en una terminal." >&2
    return 1
  fi

  echo "Grabación iniciada (${modo}): ${archivo}" >&2
  echo "Volvé a pulsar la misma tecla para detenerla." >&2
}

detener() {
  local pid="$1"
  # SIGINT, no SIGTERM: wf-recorder cierra el contenedor y finaliza el archivo.
  kill -INT "${pid}" || true
  rm -f "${PIDFILE}"
  echo "Grabación detenida." >&2
}

uso() {
  echo "Uso: $0 [full|area]" >&2
}

main() {
  local modo="${1:-$MODO_POR_DEFECTO}" pid

  # Primero el toggle: si hay grabación activa, cualquier pulsación la detiene
  # y el argumento se ignora por completo.
  if [[ -f "${PIDFILE}" ]]; then
    pid="$(<"${PIDFILE}")"
    if pid_activo "${pid}"; then
      detener "${pid}"
      return 0
    fi
    rm -f "${PIDFILE}" # obsoleto: se limpia antes de arrancar de nuevo
  fi

  if [[ $# -gt 1 ]]; then
    uso
    return 2
  fi

  case "${modo}" in
    full|area) ;;
    *)
      uso
      return 2
      ;;
  esac

  if ! command -v wf-recorder &>/dev/null; then
    echo "Falta wf-recorder; instalalo para grabar video (ej. sudo zypper in wf-recorder)." >&2
    return 127
  fi
  if ! command -v swaymsg &>/dev/null; then
    echo "Falta swaymsg; hace falta para saber en qué monitor grabar." >&2
    return 127
  fi
  if [[ "${modo}" == 'area' ]] && ! command -v slurp &>/dev/null; then
    echo "Falta slurp; hace falta para elegir el área a grabar." >&2
    return 127
  fi

  iniciar "${modo}"
}

main "$@"
