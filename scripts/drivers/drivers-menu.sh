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

# Modelo compuesto por varios tokens separados por '-': cada token se pasa por
# pretty_token y se unen con espacio.
#   hp-smart-tank-580 -> HP Smart Tank 580
#   gtx1060           -> GTX 1060
pretty_model() {
  local model="$1" out="" tok
  local -a parts
  IFS='-' read -ra parts <<< "${model}"
  for tok in "${parts[@]}"; do
    [[ -z "${tok}" ]] && continue
    out+="${out:+ }$(pretty_token "${tok}")"
  done
  printf '%s' "${out}"
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
  modelo_txt="$(pretty_model "${modelo}")"

  if [[ -n "${marca}" ]]; then
    printf '%s %s %s' "${vendor_txt}" "${marca}" "${modelo_txt}"
  elif [[ -n "${modelo_txt}" ]]; then
    printf '%s %s' "${vendor_txt}" "${modelo_txt}"
  else
    printf '%s' "${vendor_txt}"
  fi
}

# Grupo jerárquico de un driver: el primer token del nombre de archivo
# (vendor para hardware, clase para periféricos).
#   driver-nvidia-gtx1060.sh -> NVIDIA
#   driver-impresora-hp.sh   -> Impresora
driver_group() {
  local base="${1#driver-}"
  base="${base%.sh}"
  pretty_token "${base%%-*}"
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
grupos=()
hojas=()
for f in "${candidatos[@]}"; do
  [[ "${f}" == "${SELF_NAME}" ]] && continue
  drivers+=("${f}")

  etiqueta="$(pretty_driver_label "$(basename "${f}")")"
  grupo="$(driver_group "$(basename "${f}")")"

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

  # Hoja = etiqueta sin el prefijo del grupo, para el árbol jerárquico.
  hoja="${etiqueta}"
  [[ "${hoja}" == "${grupo} "* ]] && hoja="${hoja#"${grupo}" }"
  grupos+=("${grupo}")
  hojas+=("${hoja}")
done

if [[ ${#drivers[@]} -eq 0 ]]; then
  warn "No hay ningún driver en ${SCRIPT_DIR} (no se encontraron scripts driver-*.sh)."
  warn "Agregá al menos un driver-*.sh para poder configurar el hardware."
  exit 1
fi

# ---------------------------------------------------------------------------
# Selección jerárquica (árbol + multi-selección)
# ---------------------------------------------------------------------------

# Árbol visible: Drivers › <grupo> › <device>. Los grupos se preservan en el
# orden de descubrimiento.
info "Drivers disponibles:"
grupos_vistos=()
for i in "${!drivers[@]}"; do
  g="${grupos[$i]}"
  if [[ ! " ${grupos_vistos[*]:-} " == *" ${g} "* ]]; then
    grupos_vistos+=("${g}")
    printf '  » %s\n' "${g}"
  fi
  printf '      • %s\n' "${hojas[$i]}"
done

# Entradas del menú (indentadas y únicas) mapeadas a su archivo.
menu_entries=()
menu_files=()
menu_labels=()
for i in "${!drivers[@]}"; do
  menu_entries+=("  ${grupos[$i]} › ${hojas[$i]}")
  menu_files+=("${drivers[$i]}")
  menu_labels+=("${etiquetas[$i]}")
done
menu_entries+=("  No configurar drivers ahora")

seleccionados=()   # índices de drivers elegidos

if has_gum; then
  if ! elegidas="$(gum choose --no-limit --height 12 \
      --header "Elegí los dispositivos a configurar (Espacio=seleccionar, Enter=continuar):" \
      "${menu_entries[@]}")"; then
    warn "Selección cancelada; no se configuró ningún dispositivo."
    exit 0
  fi
  while IFS= read -r linea; do
    [[ -z "${linea}" ]] && continue
    [[ "${linea}" == *"No configurar drivers ahora"* ]] && continue
    for i in "${!menu_entries[@]}"; do
      if [[ "${menu_entries[$i]}" == "${linea}" ]]; then
        seleccionados+=("${i}")
        break
      fi
    done
  done <<< "${elegidas}"
else
  info "gum no está disponible; usando flujo bash simple."
  for i in "${!drivers[@]}"; do
    if confirm "¿Configurar ${etiquetas[$i]}?"; then
      seleccionados+=("${i}")
    fi
  done
fi

if [[ ${#seleccionados[@]} -eq 0 ]]; then
  info "No se configuró ningún driver."
  exit 0
fi

# ---------------------------------------------------------------------------
# Ejecución
#     Se ejecuta cada driver elegido y se propaga el peor exit code para que
#     install.sh (y quien llame) sepa si algún paso falló.
# ---------------------------------------------------------------------------

# Sangrar la salida de los drivers un nivel más adentro que install.sh.
export LOG_PREFIX="    "

rc_total=0
for i in "${seleccionados[@]}"; do
  objetivo="${menu_files[$i]}"
  etiqueta_sel="${menu_labels[$i]}"
  info "Ejecutando driver: ${etiqueta_sel}"
  set +e
  "${objetivo}"
  rc=$?
  set -e
  if [[ ${rc} -eq 0 ]]; then
    ok "Driver finalizado correctamente: ${etiqueta_sel}"
  else
    warn "El driver '${etiqueta_sel}' terminó con código ${rc}."
    rc_total=${rc}
  fi
done

exit "${rc_total}"
