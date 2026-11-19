#!/usr/bin/env bash
# Instala el greeter de LightDM con la paleta rust del escritorio.
# Ficha: odd/tasks/lightdm-greeter.md (S1-S5).
#
# Pasos:
#   1. verificar dependencias (lightdm + greeter GTK) y el payload del repo
#   2. instalar el tema rust-login en /usr/share/themes
#   3. instalar el fondo del login (copia de scripts/lightdm/background.png)
#   4. instalar la fuente mono del escritorio para el usuario del greeter
#   5. instalar el helper que elige variante por hora y apuntarlo en el hook
#   6. escribir el conf del greeter (respaldo la primera vez)
#   7. conservar el resto de lightdm.conf (user-session=sway no se toca)
#
# El greeter corre como el usuario `lightdm`, no como vos: por eso todo lo que
# necesita (tema, fuente, fondo) se instala a nivel sistema.
#
# Uso:
#   ./scripts/15-setup-lightdm.sh            # instala / actualiza
#   ./scripts/15-setup-lightdm.sh --check    # sólo informa qué falta
#   ./scripts/15-setup-lightdm.sh --help
#
# Rutas sobrescribibles (las usa scripts/tests/15-setup-lightdm-spec.sh para no
# tocar el sistema): LIGHTDM_ETC, LIGHTDM_THEMES, LIGHTDM_FONTS, LIGHTDM_SBIN,
# LIGHTDM_BIN, LIGHTDM_GREETER_BIN.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "${SCRIPT_DIR}")"
# shellcheck source=scripts/common.sh
source "${SCRIPT_DIR}/common.sh"

readonly PAYLOAD="${SCRIPT_DIR}/lightdm"
readonly MARCA="# gestionado por dotfiles"

readonly ETC="${LIGHTDM_ETC:-/etc/lightdm}"
readonly THEMES="${LIGHTDM_THEMES:-/usr/share/themes}"
readonly FONTS="${LIGHTDM_FONTS:-/usr/share/fonts/truetype/JetBrainsMonoNerdFont}"
readonly SBIN="${LIGHTDM_SBIN:-/usr/local/sbin}"

readonly GREETER_BIN="${LIGHTDM_GREETER_BIN:-/usr/sbin/lightdm-gtk-greeter}"
readonly LIGHTDM_BIN="${LIGHTDM_BIN:-/usr/sbin/lightdm}"

readonly TEMA_DIR="${THEMES}/rust-login/gtk-3.0"
readonly CONF_GREETER="${ETC}/lightdm-gtk-greeter.conf"
readonly CONF_LIGHTDM="${ETC}/lightdm.conf"
readonly FONDO="${ETC}/background.png"
readonly HELPER="${SBIN}/lightdm-greeter-setup"

# como_root "descripción" comando... -> lo que hace as_root, con traza legible.
como_root() {
  local descripcion="$1"
  shift
  info "${descripcion}"
  as_root "$@"
}

# gestionado <archivo> -> 0 si lo escribió este script (marca en la 1ª línea).
gestionado() {
  [[ -f "$1" ]] && [[ "$(head -n 1 "$1" 2>/dev/null)" == "${MARCA}"* ]]
}

# respaldar_una_vez <archivo> <sufijo>: deja una copia sin pisar respaldos
# anteriores (si ya hay uno, el original ya está a salvo).
respaldar_una_vez() {
  local archivo="$1" respaldo="$1.$2"
  [[ -f "${archivo}" ]] || return 0
  [[ -e "${respaldo}" ]] && return 0
  como_root "respaldar ${archivo} -> ${respaldo##*/}" cp -p "${archivo}" "${respaldo}" || return 1
  ok "respaldo: ${respaldo}"
}

# --- 1) Dependencias y payload --------------------------------------------
verificar_dependencias() {
  local faltan=()
  [[ -x "${LIGHTDM_BIN}" ]] || faltan+=("lightdm")
  [[ -x "${GREETER_BIN}" ]] || faltan+=("lightdm-gtk-greeter")
  if ((${#faltan[@]} > 0)); then
    warn "no encontré ${faltan[*]}: acá no hay greeter de LightDM que configurar."
    warn "Si usás otro display manager (sddm, gdm), este componente no aplica."
    return 1
  fi
  return 0
}

# El fondo es obligatorio (S3): sin imagen el greeter queda en un color liso.
verificar_payload() {
  local falta=0 archivo mime
  for archivo in "${PAYLOAD}/background.png" \
    "${PAYLOAD}/lightdm-gtk-greeter.conf" \
    "${PAYLOAD}/greeter/dark.css" \
    "${PAYLOAD}/greeter/light.css" \
    "${PAYLOAD}/bin/lightdm-greeter-setup"; do
    if [[ ! -f "${archivo}" ]]; then
      error "falta ${archivo#"${REPO_DIR}"/}"
      falta=1
    fi
  done
  ((falta == 0)) || return 1

  if [[ ! -s "${PAYLOAD}/background.png" ]]; then
    error "scripts/lightdm/background.png está vacío: copiá ahí la imagen del login."
    return 1
  fi
  mime="$(file -b --mime-type "${PAYLOAD}/background.png" 2>/dev/null || true)"
  case "${mime}" in
    image/*) : ;;
    *)
      error "scripts/lightdm/background.png no es una imagen (${mime:-desconocido})."
      return 1
      ;;
  esac
  return 0
}

# --- 2) Tema --------------------------------------------------------------
instalar_tema() {
  como_root "crear ${TEMA_DIR}" mkdir -p "${TEMA_DIR}" || return 1
  como_root "instalar dark.css" install -m 0644 "${PAYLOAD}/greeter/dark.css" "${TEMA_DIR}/dark.css" || return 1
  como_root "instalar light.css" install -m 0644 "${PAYLOAD}/greeter/light.css" "${TEMA_DIR}/light.css" || return 1
  ok "tema rust-login en ${TEMA_DIR}"
}

# --- 3) Fondo -------------------------------------------------------------
instalar_fondo() {
  como_root "instalar el fondo del login" install -m 0644 "${PAYLOAD}/background.png" "${FONDO}" || return 1
  ok "fondo: ${FONDO} (origen editable: scripts/lightdm/background.png)"
}

# --- 4) Fuente ------------------------------------------------------------
# El usuario `lightdm` no lee ~/.local/share/fonts, así que la mono del
# escritorio se copia a /usr/share/fonts (aditivo y reversible: se borra el
# directorio y listo).
instalar_fuente() {
  local origen="${HOME:-}/.local/share/fonts/JetBrainsMono" archivos=() archivo
  if [[ -d "${origen}" ]]; then
    while IFS= read -r archivo; do
      archivos+=("${archivo}")
    done < <(find "${origen}" -maxdepth 1 -name 'JetBrainsMonoNerdFont-*.ttf' 2>/dev/null | sort)
  fi
  if ((${#archivos[@]} == 0)); then
    warn "no encontré JetBrainsMono Nerd Font en ${origen}."
    warn "El greeter va a usar la fuente por defecto: corré 05-install-fonts.sh y repetí."
    return 0
  fi
  como_root "crear ${FONTS}" mkdir -p "${FONTS}" || return 1
  como_root "instalar la fuente del escritorio (${#archivos[@]} archivos)" \
    install -m 0644 "${archivos[@]}" "${FONTS}/" || return 1
  as_root fc-cache -f >/dev/null 2>&1 || warn "fc-cache no disponible: refrescá el cache a mano"
  ok "fuente JetBrainsMono Nerd Font disponible para el greeter"
}

# --- 5) Helper + hook -----------------------------------------------------
# Apunta greeter-setup-script al helper conservando el resto del archivo
# (user-session=sway, comentarios, otras claves). Si la clave ya está, la
# reemplaza; si falta, la agrega dentro de [Seat:*] o al final.
escribir_lightdm_conf() {
  local temporal
  temporal="$(mktemp "${TMPDIR:-/tmp}/lightdm.conf.XXXXXX")" || return 1
  # Una sola pasada: reemplaza la clave si existe, o la agrega al final de
  # [Seat:*] (creando la sección si el archivo no la tenía).
  awk -v helper="${HELPER}" '
    BEGIN { visto = 0; en_seat = 0 }
    /^[[:space:]]*\[/ {
      if (en_seat && !visto) { print "greeter-setup-script=" helper; visto = 1 }
      en_seat = ($0 ~ /^[[:space:]]*\[Seat:\*\]/) ? 1 : 0
      print
      next
    }
    /^[[:space:]]*greeter-setup-script[[:space:]]*=/ {
      if (!visto) { print "greeter-setup-script=" helper; visto = 1 }
      next
    }
    { print }
    END {
      if (visto) exit
      if (en_seat) { print "greeter-setup-script=" helper }
      else { print ""; print "[Seat:*]"; print "greeter-setup-script=" helper }
    }' "${CONF_LIGHTDM}" >"${temporal}" || {
    rm -f "${temporal}"
    return 1
  }

  # Guarda de seguridad: el archivo nuevo tiene que seguir siendo válido para
  # lightdm (sección de seat + la sesión sway que ya estaba configurada).
  if ! grep -q '^\s*\[Seat:\*\]' "${temporal}"; then
    error "el lightdm.conf nuevo perdería [Seat:*]: no lo instalo"
    rm -f "${temporal}"
    return 1
  fi
  if grep -q '^user-session=' "${CONF_LIGHTDM}" && ! grep -q '^user-session=' "${temporal}"; then
    error "el lightdm.conf nuevo perdería user-session: no lo instalo"
    rm -f "${temporal}"
    return 1
  fi

  como_root "escribir ${CONF_LIGHTDM}" install -m 0644 "${temporal}" "${CONF_LIGHTDM}" || {
    rm -f "${temporal}"
    return 1
  }
  rm -f "${temporal}"
  ok "${CONF_LIGHTDM}: greeter-setup-script -> ${HELPER}"
}

instalar_helper() {
  como_root "crear ${SBIN}" mkdir -p "${SBIN}" || return 1
  como_root "instalar ${HELPER}" install -m 0755 "${PAYLOAD}/bin/lightdm-greeter-setup" "${HELPER}" || return 1
  # Aplicar la variante de esta hora ahora mismo (el hook lo repite en cada
  # login). Se pasa el directorio del tema por `env` porque sudo descarta el
  # entorno: lightdm sí lo llama sin variables y ahí usa su default.
  as_root env "LIGHTDM_GREETER_THEME_DIR=${TEMA_DIR}" "${HELPER}" ||
    warn "no pude aplicar la variante ahora; se aplica en el próximo login"
  ok "helper: ${HELPER}"
}

# --- 6) Conf del greeter --------------------------------------------------
escribir_greeter_conf() {
  local temporal
  temporal="$(mktemp "${TMPDIR:-/tmp}/greeter.conf.XXXXXX")" || return 1
  # @FONDO@ existe para que el conf no hardcodee /etc/lightdm: el instalador
  # escribe la ruta real y así el spec corre aislado sin tocar el archivo.
  sed -e "s|@FONDO@|${FONDO}|g" "${PAYLOAD}/lightdm-gtk-greeter.conf" >"${temporal}" || {
    rm -f "${temporal}"
    return 1
  }
  if ! grep -q "^background=${FONDO}$" "${temporal}"; then
    error "el conf del greeter no quedó apuntando a ${FONDO}: no lo instalo"
    rm -f "${temporal}"
    return 1
  fi
  if [[ -f "${CONF_GREETER}" ]] && ! gestionado "${CONF_GREETER}"; then
    respaldar_una_vez "${CONF_GREETER}" "bak.$(date +%Y%m%d-%H%M%S)" || {
      rm -f "${temporal}"
      return 1
    }
  fi
  como_root "escribir ${CONF_GREETER}" install -m 0644 "${temporal}" "${CONF_GREETER}" || {
    rm -f "${temporal}"
    return 1
  }
  rm -f "${temporal}"
  ok "${CONF_GREETER}: tema rust-login + fondo ${FONDO}"
}

# --- --check --------------------------------------------------------------
# Sólo lectura: informa qué falta o está desviado, sin escribir nada.
revisar() {
  local desvio=0
  for archivo in "${TEMA_DIR}/dark.css" "${TEMA_DIR}/light.css" "${FONDO}" "${HELPER}"; do
    if [[ -f "${archivo}" ]]; then
      ok "instalado: ${archivo}"
    else
      warn "falta: ${archivo}"
      desvio=1
    fi
  done
  if [[ -L "${TEMA_DIR}/gtk.css" ]]; then
    ok "variante activa: $(readlink "${TEMA_DIR}/gtk.css")"
  else
    warn "falta: ${TEMA_DIR}/gtk.css (enlace a dark.css o light.css)"
    desvio=1
  fi
  if gestionado "${CONF_GREETER}" && grep -q '^theme-name=rust-login$' "${CONF_GREETER}"; then
    ok "${CONF_GREETER}: gestionado con rust-login"
  else
    warn "${CONF_GREETER}: no lo gestiona este script o no usa rust-login"
    desvio=1
  fi
  if grep -qx "greeter-setup-script=${HELPER}" "${CONF_LIGHTDM}" 2>/dev/null; then
    ok "${CONF_LIGHTDM}: hook -> ${HELPER}"
  else
    warn "${CONF_LIGHTDM}: el hook no apunta a ${HELPER}"
    desvio=1
  fi
  ((desvio == 0)) && return 0 || return 1
}

uso() {
  printf 'Uso: %s [--check|--help]\n\n' "${0##*/}"
  printf '  (sin argumentos)  instala o actualiza el greeter rust-login\n'
  printf '  --check           sólo informa el estado, no escribe nada\n'
  printf '  --help            esta ayuda\n'
}

main() {
  local modo=instalar
  case "${1:-}" in
    --check) modo=revisar ;;
    --help | -h)
      uso
      exit 0
      ;;
    "") : ;;
    *)
      error "opción desconocida: $1"
      uso >&2
      exit 2
      ;;
  esac

  verificar_dependencias || exit 0
  verificar_payload || exit 1

  if [[ "${modo}" == revisar ]]; then
    revisar
    exit $?
  fi

  instalar_tema || exit 1
  instalar_fondo || exit 1
  instalar_fuente || exit 1
  instalar_helper || exit 1
  escribir_greeter_conf || exit 1
  respaldar_una_vez "${CONF_LIGHTDM}" "pre-rust-login.bak" || exit 1
  escribir_lightdm_conf || exit 1

  info "Listo. Para ver el login sin reiniciar: sudo dm-tool switch-to-greeter"
  info "Para volver atrás: restaurá ${CONF_GREETER}.*.bak y ${CONF_LIGHTDM}.pre-rust-login.bak"
}

main "$@"
