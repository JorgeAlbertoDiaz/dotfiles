#!/usr/bin/env bash
# sway-font.sh — personaliza la fuente de sway sobre la config APLICADA
# (~/.config/sway), no sobre la del repositorio.
#
# Uso:
#   sway-font.sh                      # interactivo: familia + tamaño en wofi
#   sway-font.sh <familia>            # aplica familia (tamaño actual o por defecto)
#   sway-font.sh <familia> <tamaño>   # aplica familia y tamaño
#
# Edita el archivo del árbol que REALMENTE tiene la fuente: si la línea
# "font pango:" delega en $font-family/$font-size, reescribe esas variables donde
# estén definidas y deja la línea intacta; si la lleva literal, reescribe la
# línea donde esté. Nunca agrega una línea nueva. Si más de un archivo declara
# "font pango:" no elige por vos: lo dice y sale. Si hay una sesión de sway
# activa, recarga la configuración.
set -euo pipefail

CONFIG_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sway/config"
DEFAULT_FAMILY='JetBrainsMono Nerd Font'
# Se resuelve en tiempo de ejecución (ver archivo_variables): quién define
# $font-family depende de cómo esté montado el árbol de cada máquina.
VARS_FILE=''

# Opciones base de wofi (estilo consistente con el launcher del sistema).
WOFI_OPTS=(--dmenu --insensitive)
[[ -f /etc/wofi/config ]] && WOFI_OPTS+=(--conf /etc/wofi/config)
[[ -f /etc/wofi/style.css ]] && WOFI_OPTS+=(--style /etc/wofi/style.css)

# Familias de fuentes mono instaladas (fc-list), ordenadas, sin duplicados.
# Usa fc-list ':spacing=100' (FC_MONO) y toma el nombre primario de cada
# familia (fc-list devuelve los alias separados por coma).
familias_mono() {
  fc-list ':spacing=100' family 2>/dev/null | cut -d, -f1 | sort -u
}

# Elige familia en wofi (la default aparece primero; Enter la selecciona).
elegir_familia() {
  local lista
  lista="$(printf '%s\n%s\n' "${DEFAULT_FAMILY}" "$(familias_mono)" | awk '!seen[$0]++')"
  printf '%s\n' "${lista}" | wofi "${WOFI_OPTS[@]}" --prompt "Fuente (Enter = ${DEFAULT_FAMILY}) > " || true
}

# Elige tamaño en wofi (8-14; la default aparece primero).
elegir_tamano() {
  local tamano_default="${1:-10}"
  printf '%s\n' 8 9 "${tamano_default}" 10 11 12 13 14 |
    awk '!seen[$0]++' |
    wofi "${WOFI_OPTS[@]}" --prompt 'Tamaño > ' || true
}

# --- Dónde vive la fuente dentro del árbol de configuración ---
# Ni la línea "font pango:" ni las variables que la alimentan están en el config
# raíz: viven en módulos incluidos (features/appearance.conf y
# features/variables-colors.conf). El script no adivina qué archivo es: recorre
# los que el config raíz carga y exige que cada valor tenga un único dueño.

TREE=()
TREE_VISTOS=''
CANDIDATOS=()

# Recorre en profundidad los includes de un archivo, en el orden en que sway los
# lee (primero el config raíz, después sus includes). Tope de profundidad y
# control de ciclos para que un include recursivo no cuelgue el script.
_recolectar() {
  local archivo="$1" nivel="$2" include patron hijo
  if [[ "${nivel}" -gt 8 ]] || [[ " ${TREE_VISTOS} " == *" ${archivo} "* ]]; then
    return 0
  fi
  TREE_VISTOS+=" ${archivo}"
  TREE+=("${archivo}")
  while read -r include; do
    [[ -n "${include}" ]] || continue
    if [[ "${include}" == /* ]]; then
      patron="${include}"
    else
      patron="$(dirname "${archivo}")/${include}"
    fi
    # Sin entrecomillar para que un include con comodín se expanda; los
    # patrones sin coincidencia caen en el -f y se descartan.
    for hijo in ${patron}; do
      if [[ -f "${hijo}" ]]; then
        _recolectar "${hijo}" "$(( nivel + 1 ))"
      fi
    done
  done < <(sed -nE 's/^[[:space:]]*include[[:space:]]+//p' "${archivo}" 2>/dev/null)
}

# CANDIDATOS = archivos del árbol con una línea que matchea $1.
buscar_en_arbol() {
  local regex="$1" archivo
  TREE=()
  TREE_VISTOS=''
  CANDIDATOS=()
  _recolectar "${CONFIG_FILE}" 0
  for archivo in ${TREE[@]+"${TREE[@]}"}; do
    if grep -qlE "${regex}" "${archivo}" 2>/dev/null; then
      CANDIDATOS+=("${archivo}")
    fi
  done
}

# Resuelve el único dueño de un valor o explica por qué no se puede decidir.
# $1 = regex, $2 = qué se busca, $3 = pista para el usuario.
resolver_unico() {
  local regex="$1" que="$2" pista="$3" rc=0
  unico_en_arbol "${regex}" || rc=$?
  case "${rc}" in
    0) return 0 ;;
    1)
      echo "No encontré ${que} en el árbol de configuración de sway." >&2
      echo "  Busqué en ${#TREE[@]} archivos alcanzables desde ${CONFIG_FILE}" >&2
      echo "  (directorio base: $(dirname "${CONFIG_FILE}"))." >&2
      echo "  ${pista}" >&2
      return 1 ;;
    *)
      echo "Hay ${#CANDIDATOS[@]} archivos que definen ${que}; no puedo elegir por vos:" >&2
      printf '  %s\n' "${CANDIDATOS[@]}" >&2
      echo "  Dejá una sola definición y volvé a correr el script." >&2
      return 1 ;;
  esac
}

# Imprime el path del único archivo que matchea $1. Falla con 1 si no hay
# ninguno y con 2 si hay varios: en el caso múltiple el llamador avisa.
unico_en_arbol() {
  buscar_en_arbol "$1"
  case "${#CANDIDATOS[@]}" in
    0) return 1 ;;
    1) printf '%s' "${CANDIDATOS[0]}" ;;
    *) return 2 ;;
  esac
}

# Archivo que declara la fuente.
archivo_fuente() {
  resolver_unico '^font pango:' 'una línea "font pango:"' \
    'Revisá que features/appearance.conf siga declarando la fuente.'
}

# Archivo que define $font-family (y por lo tanto $font-size).
archivo_variables() {
  resolver_unico '^set[[:space:]]+\$font-family[[:space:]]' 'la variable $font-family' \
    'La línea "font pango:" delega en $font-family, pero nadie lo define.'
}

# Tamaño actual de la fuente, sea literal o delegado en $font-size. Vacío si no
# se puede determinar: el llamador aplica su default.
tamano_actual() {
  local fuente variables token salida
  fuente="$(archivo_fuente 2>/dev/null)" || return 0
  salida="$(sed -nE 's|^font pango:.* (\$[A-Za-z-]+\|[0-9]+)$|\1|p' "${fuente}" 2>/dev/null)"
  token="${salida%%$'\n'*}"
  if [[ "${token}" == \$* ]]; then
    # Delegada: el número no está en la línea, está en "set $font-size".
    variables="$(archivo_variables 2>/dev/null)" || return 0
    salida="$(sed -nE 's|^set[[:space:]]+\$font-size[[:space:]]+([0-9]+).*$|\1|p' "${variables}" 2>/dev/null)"
    token="${salida%%$'\n'*}"
  fi
  printf '%s' "${token}"
}

# Escapa una cadena para usarla como REEMPLAZO en sed: el separador elegido
# (|), & (que expande al texto matcheado) y \ (backreference) tienen
# significado. El orden importa: primero la barra invertida.
escapar_sed() {
  local s="$1"
  s="${s//\\/\\\\}"
  s="${s//&/\\&}"
  s="${s//|/\\|}"
  printf '%s' "${s}"
}

cambiar_fuente() {
  local familia="$1"
  local tamano="$2"
  local nueva_linea="font pango:${familia}"
  [[ -n "${tamano}" ]] && nueva_linea="font pango:${familia} ${tamano}"
  # La familia viene de wofi o de la línea de comandos: no se asume que sea
  # "limpia", así que se escapa antes de interpolarla en un sed.
  local familia_sed tamano_sed
  familia_sed="$(escapar_sed "${familia}")"
  tamano_sed="$(escapar_sed "${tamano}")"

  if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "No existe ${CONFIG_FILE}; primero aplicá los dotfiles (scripts/04-setup-dotfiles.sh)." >&2
    return 1
  fi

  local fuente
  fuente="$(archivo_fuente)" || return 1

  if grep -qE '^font pango:.* \$' "${fuente}"; then
    # Delegada: el valor real no está en la línea, así que se edita quien define
    # la variable y la línea "font pango:" queda byte a byte igual.
    VARS_FILE="$(archivo_variables)" || return 1
    sed -i -E "s|^set[[:space:]]+\\\$font-family[[:space:]].*|set \$font-family ${familia_sed}|" "${VARS_FILE}"
    if [[ -n "${tamano}" ]]; then
      sed -i -E "s|^set[[:space:]]+\\\$font-size[[:space:]].*|set \$font-size ${tamano_sed}|" "${VARS_FILE}"
    fi
  else
    # Literal: se reescribe la línea donde está, sin tocar el resto.
    sed -i -E "s|^font pango:.*|font pango:${familia_sed}${tamano:+ ${tamano_sed}}|" "${fuente}"
  fi

  echo "Fuente de sway actualizada: ${nueva_linea}"
  recargar_si_activo
}

# Recarga sway solo si hay una sesión activa.
recargar_si_activo() {
  if command -v swaymsg &>/dev/null &&
     { [[ -S "${SWAYSOCK:-}" ]] || [[ -n "${WAYLAND_DISPLAY:-}" ]]; } &&
     pgrep -x sway &>/dev/null; then
    swaymsg reload && echo 'Configuración de sway recargada.'
  fi
}

# --- Modo argumentos: sway-font.sh <familia> [tamaño] ---
if [[ $# -ge 1 ]]; then
  cambiar_fuente "$1" "${2:-}"
  exit 0
fi

# --- Modo interactivo ---
familia="$(elegir_familia)"
[[ -z "${familia}" ]] && { echo 'Cancelado.'; exit 0; }

tamano="$(elegir_tamano "$(tamano_actual)")"
[[ -z "${tamano}" ]] && { echo 'Cancelado.'; exit 0; }

cambiar_fuente "${familia}" "${tamano}"