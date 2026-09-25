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

iniciar() {
  local modo="$1" destino archivo pid
  destino="$(directorio_destino)"
  mkdir -p "${destino}"
  archivo="${destino}/video_${modo}_$(date +%Y%m%d_%H%M%S).mp4"

  if [[ "${modo}" == 'area' ]]; then
    # Geometría por stdin desde slurp, igual que grim -g- en screenshots.conf.
    slurp | wf-recorder -g- -f "${archivo}" &
  else
    wf-recorder -f "${archivo}" &
  fi
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
  if [[ "${modo}" == 'area' ]] && ! command -v slurp &>/dev/null; then
    echo "Falta slurp; hace falta para elegir el área a grabar." >&2
    return 127
  fi

  iniciar "${modo}"
}

main "$@"
