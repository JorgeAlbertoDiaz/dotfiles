#!/usr/bin/env bash
# drivers-menu.sh — submenú de controladores por hardware.
#
# Lista dinámicamente TODOS los scripts driver-*.sh que viven en este mismo
# directorio y lanza el que elija el usuario. No hay una lista hardcodeada
# acá a propósito: mañana se agrega driver-impresora-hp.sh y aparece solo en
# el menú, sin tocar ni este archivo ni install.sh.
#
# Se invoca sin argumentos (menú interactivo) desde install.sh, en el
# componente "Drivers".
set -euo pipefail

# Este archivo vive DENTRO de scripts/drivers/, así que el directorio de los
# drivers es el propio SCRIPT_DIR. common.sh está un nivel arriba.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# ---------------------------------------------------------------------------
# Etiquetas legibles
#     El nombre de archivo es técnico (driver-nvidia-gtx1060.sh) y la UI
#     necesita texto humano (NVIDIA GeForce GTX 1060). Se traduce por partes
#     en vez de con una tabla fija, así un driver nuevo se lee bien sin
#     registrar nada acá.
# ---------------------------------------------------------------------------

# Un token suelto -> texto legible.
#   nvidia   -> NVIDIA          (vendedor: se reconoce en minúsculas)
#   gtx1060  -> GTX 1060        (letras + dígitos: "gtx" y "1060" separados)
#   hp       -> HP              (marca corta en minúsculas)
#   impresora-> Impresora       (palabra normal: solo la inicial mayúscula)
pretty_token() {
  local token="$1"

  # Vacío (p. ej. un archivo llamado driver-nvidia.sh, sin modelo).
  [[ -z "${token}" ]] && return 0

  case "${token}" in
    nvidia|amd|intel|hp|epson|canon|brother|logitech|realtek)
      printf '%s' "${token^^}"
      return 0
      ;;
  esac

  # "gtx1060" -> "GTX 1060": se parte donde acaba la parte alfabética.
  if [[ "${token}" =~ ^([a-z]+)([0-9]+)([a-z]*)$ ]]; then
    printf '%s %s%s' "${BASH_REMATCH[1]^^}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]^^}"
    return 0
  fi

  # Sustantivo corriente ("impresora", "monitor"): Initial Cap.
  printf '%s' "${token^}"
}

# driver-<vendor>-<modelo>.sh -> "<Vendor> [marca] <Modelo>"
pretty_driver_label() {
  local base="${1#driver-}"
  base="${base%.sh}"

  local vendor="${base%%-*}"
  local modelo=""
  [[ "${base}" == *-* ]] && modelo="${base#*-}"

  # La familia técnica de NVIDIA no incluye su nombre de marketing:
  # nadie dice "gtx1060", dicen "GeForce GTX 1060".
  local marca=""
  if [[ "${vendor}" == "nvidia" ]]; then
    case "${modelo}" in
      gtx*|rtx*) marca="GeForce" ;;
      quadro*)   marca="Quadro" ;;
      tesla*)    marca="Tesla" ;;
    esac
  fi

  local vendor_txt modelo_txt
  vendor_txt="$(pretty_token "${vendor}")"
  modelo_txt="$(pretty_token "${modelo}")"

  if [[ -n "${marca}" ]]; then
    printf '%s %s %s' "${vendor_txt}" "${marca}" "${modelo_txt}"
  elif [[ -n "${modelo_txt}" ]]; then
    printf '%s %s' "${vendor_txt}" "${modelo_txt}"
  else
    printf '%s' "${vendor_txt}"
  fi
}

# ---------------------------------------------------------------------------
# Descubrimiento de drivers
#     Glob de bash (con nullglob) en vez de "ls | grep": no depende de parsear
#     salida humana, no se rompe con espacios en el path y no arrastra
#     subdirectorios. Se excluye este propio script por si alguien lo
#     renombra a driver-*.sh algún día.
# ---------------------------------------------------------------------------

SELF_NAME="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"

shopt -s nullglob
candidatos=("${SCRIPT_DIR}"/driver-*.sh)
shopt -u nullglob

drivers=()
etiquetas=()
for f in "${candidatos[@]}"; do
  [[ "${f}" == "${SELF_NAME}" ]] && continue
  drivers+=("${f}")

  etiqueta="$(pretty_driver_label "$(basename "${f}")")"

  # Las etiquetas tienen que ser únicas porque son la clave con la que se
  # vuelve del texto elegido al archivo. Si dos drivers colapsan al mismo
  # nombre, se desambigua con el archivo.
  for existente in "${etiquetas[@]:-}"; do
    [[ -z "${existente}" ]] && continue
    if [[ "${existente}" == "${etiqueta}" ]]; then
      etiqueta="${etiqueta} [${f##*/}]"
      break
    fi
  done

  etiquetas+=("${etiqueta}")
done

if [[ ${#drivers[@]} -eq 0 ]]; then
  warn "No hay ningún driver en ${SCRIPT_DIR} (no se encontraron scripts driver-*.sh)."
  warn "Agregá al menos un driver-*.sh para poder configurar el hardware."
  exit 1
fi

# ---------------------------------------------------------------------------
# Selección
# ---------------------------------------------------------------------------

if command -v gum &>/dev/null; then
  if ! seleccion="$(gum choose --header "Elegí el dispositivo a configurar:" "${etiquetas[@]}")"; then
    warn "Selección cancelada; no se configuró ningún dispositivo."
    exit 1
  fi
else
  info "gum no está disponible; usando flujo bash simple."
  PS3="> "
  select seleccion in "${etiquetas[@]}"; do
    [[ -n "${seleccion}" ]] && break
    warn "Opción inválida, intente de nuevo."
  done
fi

# gum puede devolver vacío en algunos edge cases de terminal: se rechaza
# explícito antes de buscar el archivo.
if [[ -z "${seleccion:-}" ]]; then
  warn "No se seleccionó ningún dispositivo."
  exit 1
fi

objetivo=""
for i in "${!etiquetas[@]}"; do
  if [[ "${etiquetas[$i]}" == "${seleccion}" ]]; then
    objetivo="${drivers[$i]}"
    break
  fi
done

if [[ -z "${objetivo}" ]]; then
  warn "No se pudo resolver la selección '${seleccion}' a ningún driver."
  exit 1
fi

# ---------------------------------------------------------------------------
# Ejecución
#     Se propaga el exit code del driver para que install.sh (y quien llame)
#     sepa si el paso terminó bien, pero sin perder el resumen final.
# ---------------------------------------------------------------------------

info "Ejecutando driver: ${objetivo}"
set +e
"${objetivo}"
rc=$?
set -e

if [[ ${rc} -eq 0 ]]; then
  ok "Driver finalizado correctamente: ${seleccion}"
else
  warn "El driver '${seleccion}' terminó con código ${rc}."
fi

exit "${rc}"
