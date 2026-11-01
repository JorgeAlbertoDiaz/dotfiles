#!/usr/bin/env bash
# 02b-install-flatpak: instala aplicaciones Flatpak del catálogo
# packages/flatpak-apps.txt desde el remote flathub, dejando elegir cuáles.
#
# Uso: 02b-install-flatpak.sh [opciones]
#   (sin opciones)   selección interactiva del catálogo
#   --all            instala todas las apps del catálogo
#   --apps A,B,C     instala exactamente esos appids (tienen que estar en el catálogo)
#   --list           imprime los appids del catálogo (uno por línea) y sale 0
#   -h, --help       ayuda
#
# Por qué cada validación existe (y en este orden):
#   * --list es de sólo lectura: no exige flatpak ni registra flathub, para que
#     otros pasos puedan inspeccionar el catálogo sin efectos colaterales.
#   * El catálogo se lee antes de tocar flatpak: un catálogo ausente o vacío
#     debe informarse sin dejar flathub registrado de más.
#   * flatpak se verifica antes de registrar flathub: sin él, salimos avisando
#     y no dejamos el remote a medio registrar (se instala vía packages/base.txt).
#   * La selección interactiva exige gum Y TTY: sin eso no hay forma de elegir,
#     así que mostramos el uso y salimos 2 en vez de "no hacer nada" en silencio.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

REPO_DIR="$(dirname "${SCRIPT_DIR}")"
FLATPAK_APPS="${REPO_DIR}/packages/flatpak-apps.txt"

usage() {
  cat <<'EOF'
Uso: 02b-install-flatpak.sh [opciones]
  (sin opciones)   selección interactiva del catálogo
  --all            instala todas las apps del catálogo
  --apps A,B,C     instala exactamente esos appids (tienen que estar en el catálogo)
  --list           imprime los appids del catálogo (uno por línea) y sale 0
  -h, --help       ayuda
EOF
}

# ---------------------------------------------------------------------------
# 1) Flags: un único selector por invocación (all | apps | list | interactivo).
# ---------------------------------------------------------------------------
MODO=""            # vacío = interactivo
APPS_CRUDO=""      # lista de appids tal cual la escribe el usuario (--apps)

seleccionar_modo() {
  local nuevo="$1"
  if [[ -n "${MODO}" ]]; then
    # Dos selectores a la vez son ambiguos: no hay forma de saber cuál manda.
    error "No se pueden combinar varios selectores (--all, --apps, --list)."
    usage >&2
    exit 2
  fi
  MODO="${nuevo}"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all)
      seleccionar_modo all
      shift
      ;;
    --list)
      seleccionar_modo list
      shift
      ;;
    --apps)
      if [[ $# -lt 2 ]]; then
        error "--apps requiere una lista de appids separados por coma."
        usage >&2
        exit 2
      fi
      seleccionar_modo apps
      APPS_CRUDO="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      error "Opción desconocida: $1"
      usage >&2
      exit 2
      ;;
  esac
done

# ---------------------------------------------------------------------------
# 2) Leer el catálogo una sola vez (para todos los modos, incluido --list).
# ---------------------------------------------------------------------------
catalogo=()
if [[ ! -f "${FLATPAK_APPS}" ]]; then
  error "El catálogo de aplicaciones no existe: ${FLATPAK_APPS}"
  exit 1
fi

while IFS= read -r linea || [[ -n "${linea}" ]]; do
  # Quitar comentarios (#) y cualquier espacio; saltar líneas en blanco.
  app="${linea%%#*}"
  app="${app//[[:space:]]/}"
  [[ -z "${app}" ]] && continue
  catalogo+=("${app}")
done < "${FLATPAK_APPS}"

# ---------------------------------------------------------------------------
# 3) --list: sólo lectura, sin flatpak ni flathub.
# ---------------------------------------------------------------------------
if [[ "${MODO}" == "list" ]]; then
  for app in "${catalogo[@]}"; do
    printf '%s\n' "${app}"
  done
  exit 0
fi

# Catálogo sin appids: nada que instalar; avisar y salir 0 (igual que hoy).
if [[ ${#catalogo[@]} -eq 0 ]]; then
  warn "Sin aplicaciones en ${FLATPAK_APPS}. Omitiendo."
  exit 0
fi

# ---------------------------------------------------------------------------
# 4) flatpak presente ANTES de registrar flathub.
# ---------------------------------------------------------------------------
if ! command -v flatpak &>/dev/null; then
  # A stderr (no a stdout) para que la automatización pueda detectar el aviso
  # sin mezclarlo con la salida informativa de info/ok.
  warn "flatpak no instalado — instalalo vía packages/base.txt primero" >&2
  exit 0
fi

# ---------------------------------------------------------------------------
# 5) Resolver el conjunto seleccionado (siempre en orden del catálogo).
# ---------------------------------------------------------------------------
contiene() {
  local aguja="$1" item
  shift
  for item in "$@"; do
    if [[ "${item}" == "${aguja}" ]]; then
      return 0
    fi
  done
  return 1
}

seleccionadas=()
case "${MODO}" in
  all)
    seleccionadas=("${catalogo[@]}")
    ;;
  apps)
    # Normalizar la lista: sin espacios, separada por comas.
    APPS_CRUDO="${APPS_CRUDO//[[:space:]]/}"
    IFS=',' read -r -a pedidas <<< "${APPS_CRUDO}"
    pedidas_ok=()
    for p in "${pedidas[@]}"; do
      [[ -n "${p}" ]] && pedidas_ok+=("${p}")
    done
    if [[ ${#pedidas_ok[@]} -eq 0 ]]; then
      error "--apps requiere al menos un appid."
      usage >&2
      exit 2
    fi

    # Validar ANTES de instalar nada: los appids pedidos deben existir.
    faltan=()
    for p in "${pedidas_ok[@]}"; do
      en_catalogo=0
      for c in "${catalogo[@]}"; do
        if [[ "${c}" == "${p}" ]]; then
          en_catalogo=1
          break
        fi
      done
      if [[ ${en_catalogo} -eq 0 ]]; then
        faltan+=("${p}")
      fi
    done
    if [[ ${#faltan[@]} -gt 0 ]]; then
      error "Appid(s) no encontrado(s) en el catálogo: ${faltan[*]}"
      exit 1
    fi

    # Respetar el orden del catálogo (no el orden tecleado).
    for c in "${catalogo[@]}"; do
      for p in "${pedidas_ok[@]}"; do
        if [[ "${c}" == "${p}" ]]; then
          seleccionadas+=("${c}")
          break
        fi
      done
    done
    ;;
  *)
    # Modo interactivo (MODO vacío): requiere gum Y TTY.
    if ! command -v gum &>/dev/null || ! [[ -t 0 && -t 1 ]]; then
      error "Sin TTY o sin gum no se puede elegir; usá --all o --apps."
      usage >&2
      exit 2
    fi
    ;;
esac

# ---------------------------------------------------------------------------
# 6) Detectar apps ya instaladas (tolerar fallo: sin salida útil = ninguna).
# ---------------------------------------------------------------------------
instaladas=()
lista="$(flatpak list --app --columns=application 2>/dev/null || true)"
while IFS= read -r l; do
  l="${l//[[:space:]]/}"
  [[ -n "${l}" ]] && instaladas+=("${l}")
done <<< "${lista}"

esta_instalada() {
  local app="$1" i
  for i in "${instaladas[@]}"; do
    if [[ "${i}" == "${app}" ]]; then
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# 7) Selección interactiva (gum multi-selección, como en 05-install-fonts).
# ---------------------------------------------------------------------------
if [[ -z "${MODO}" ]]; then
  etiquetas=()
  for app in "${catalogo[@]}"; do
    if esta_instalada "${app}"; then
      etiquetas+=("${app} (instalada)")
    else
      etiquetas+=("${app}")
    fi
  done

  seleccion="$(gum choose --no-limit --height 12 \
    --header "Aplicaciones Flatpak a instalar (Espacio=seleccionar, Enter=continuar):" \
    "${etiquetas[@]}")" || {
    warn "Selección cancelada; no se instalará nada."
    exit 0
  }

  elegidas=()
  mapfile -t elegidas <<< "${seleccion}"
  filtradas=()
  for item in "${elegidas[@]}"; do
    [[ -n "${item}" ]] && filtradas+=("${item}")
  done

  elegidas_appids=()
  for item in "${filtradas[@]}"; do
    # Quitar el sufijo "(instalada)" que agrega el menú y mapear al appid:
    # nunca se instala una etiqueta.
    app="${item% (instalada)}"
    if contiene "${app}" "${catalogo[@]}"; then
      elegidas_appids+=("${app}")
    else
      warn "Selección no reconocida; se ignora: ${item}"
    fi
  done

  if [[ ${#elegidas_appids[@]} -eq 0 ]]; then
    warn "No se seleccionó ninguna aplicación."
    exit 0
  fi

  # Orden del catálogo, igual que los demás modos.
  for c in "${catalogo[@]}"; do
    if contiene "${c}" "${elegidas_appids[@]}"; then
      seleccionadas+=("${c}")
    fi
  done
fi

# ---------------------------------------------------------------------------
# 8) Filtrar las ya instaladas (idempotencia): no se reinstalan.
# ---------------------------------------------------------------------------
pendientes=()
for app in "${seleccionadas[@]}"; do
  if esta_instalada "${app}"; then
    info "Ya instalada, se omite: ${app}"
  else
    pendientes+=("${app}")
  fi
done

if [[ ${#pendientes[@]} -eq 0 ]]; then
  ok "No hay aplicaciones Flatpak nuevas para instalar."
  exit 0
fi

# ---------------------------------------------------------------------------
# 9) Registrar flathub UNA vez y, recién entonces, instalar.
# ---------------------------------------------------------------------------
info "Registrando el remote flathub (si no existe) a nivel de usuario..."
if ! flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo; then
  error "No se pudo registrar el remote flathub a nivel de usuario"
  exit 1
fi
ok "Remote flathub disponible a nivel de usuario"

for app in "${pendientes[@]}"; do
  info "Instalando: ${app}"
  flatpak install -y --noninteractive --user flathub "${app}"
  ok "Instalada: ${app}"
done

ok "Instalación de aplicaciones Flatpak completada"
