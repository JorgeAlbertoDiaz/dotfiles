#!/usr/bin/env bash
# 06-network-wifi: conecta a una red WiFi con NetworkManager (nmcli).
#
#   - Verifica que nmcli esté disponible.
#   - Detecta si ya hay una conexión WiFi activa; si es así, pregunta si
#     se desea cambiar de red (sin volver a pedir la contraseña si no).
#   - Activa la radio WiFi y rescannea las redes (con sudo: modifica estado).
#   - Muestra las redes ordenadas por señal (gum choose o select bash).
#   - Pide la contraseña (gum input --password o read -s) y conecta;
#     las redes abiertas se conectan sin contraseña.
#   - Verifica la conexión activa y muestra la IP obtenida.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if ! command -v nmcli &>/dev/null; then
  error "NetworkManager no está instalado (paquete 'NetworkManager' en openSUSE)."
  warn "Instálalo con: sudo zypper -n in NetworkManager"
  exit 1
fi

# ---------------------------------------------------------------------------
# 0) Detectar si ya hay una conexión WiFi activa
#    IN-USE == '*' indica la red actualmente conectada.
# ---------------------------------------------------------------------------
current_ssid="$(nmcli -t -f IN-USE,SSID device wifi list 2>/dev/null \
  | awk -F: '$1 == "*" {print $2; exit}')"

if [[ -n "${current_ssid}" ]]; then
  ok "Ya estás conectado a la red: ${current_ssid}"
  cambiar=0
  if command -v gum &>/dev/null; then
    if gum confirm --default=false "¿Querés conectarte a otra red WiFi?"; then
      cambiar=1
    fi
  else
    if confirm "¿Querés conectarte a otra red WiFi?"; then
      cambiar=1
    fi
  fi
  if [[ ${cambiar} -eq 0 ]]; then
    ok "Saliendo sin cambiar de red."
    exit 0
  fi
  info "Continuando con el escaneo de redes..."
fi

# ---------------------------------------------------------------------------
# 1) Radio WiFi y rescan
# ---------------------------------------------------------------------------
info "Activando la radio WiFi..."
if ! as_root nmcli radio wifi on 2>/dev/null; then
  warn "No se pudo activar la radio WiFi (¿hardware bloqueado?)."
fi

info "Buscando redes disponibles..."
as_root nmcli device wifi rescan 2>/dev/null || {
  warn "No se pudo forzar el rescan; usando la lista actual de redes."
}
sleep 2

# ---------------------------------------------------------------------------
# 2) Listar redes ordenadas por señal
#    Formato interno: ssid|senal|seguridad
#    Nota: las SSID que contienen ':' no se parsean correctamente con nmcli -t;
#    es una limitación conocida del formato terse de nmcli.
# ---------------------------------------------------------------------------
mapfile -t redes < <(
  nmcli -t -f SSID,SIGNAL,SECURITY device wifi list 2>/dev/null \
    | awk -F: 'NF >= 3 && $1 != "" { printf "%s|%s|%s\n", $1, $2, $3 }' \
    | sort -t'|' -k2,2rn
)

if [[ ${#redes[@]} -eq 0 ]]; then
  warn "No se encontraron redes WiFi."
  exit 1
fi

# Opciones legibles para mostrar; se mapea después por índice.
opciones=()
for r in "${redes[@]}"; do
  ssid="${r%%|*}"
  resto="${r#*|}"
  senal="${resto%%|*}"
  seg="${resto#*|}"
  if [[ -n "${seg}" && "${seg}" != "--" ]]; then
    opciones+=("${ssid}  (${senal}%)  [${seg}]")
  else
    opciones+=("${ssid}  (${senal}%)  [abierta]")
  fi
done

info "Redes WiFi disponibles (ordenadas por señal):"
if command -v gum &>/dev/null; then
  if ! elegida="$(gum choose --height 15 "Cancelar" "${opciones[@]}")"; then
    warn "Operación cancelada."
    exit 1
  fi
  [[ "${elegida}" == "Cancelar" ]] && { warn "Operación cancelada."; exit 0; }
else
  PS3="> "
  select elegida in "Cancelar" "${opciones[@]}"; do
    [[ -n "${elegida}" ]] && break
    warn "Opción inválida, intente de nuevo."
  done
  [[ "${elegida}" == "Cancelar" ]] && { warn "Operación cancelada."; exit 0; }
fi

# Mapear la opción elegida de vuelta al formato interno.
idx=""
for i in "${!opciones[@]}"; do
  [[ "${opciones[$i]}" == "${elegida}" ]] && idx="${i}"
done
if [[ -z "${idx}" ]]; then
  error "No se pudo identificar la red elegida."
  exit 1
fi

linea="${redes[$idx]}"
ssid="${linea%%|*}"
resto="${linea#*|}"
senal="${resto%%|*}"
seguridad="${resto#*|}"

info "Elegiste: ${ssid} (señal ${senal}%)"

# ---------------------------------------------------------------------------
# 3) Conectar (con o sin contraseña)
# ---------------------------------------------------------------------------
if [[ -n "${seguridad}" && "${seguridad}" != "--" ]]; then
  if command -v gum &>/dev/null; then
    if ! pass="$(gum input --password --prompt "Contraseña de ${ssid}: ")"; then
      warn "Contraseña no ingresada; cancelando."
      exit 1
    fi
  else
    read -r -s -p "Contraseña de ${ssid}: " pass || true
    printf '\n'
  fi

  if [[ -z "${pass}" ]]; then
    error "No se ingresó contraseña para una red protegida."
    exit 1
  fi
  info "Conectando a ${ssid} (red protegida)..."
  if ! as_root nmcli device wifi connect "${ssid}" password "${pass}"; then
    error "No se pudo conectar a ${ssid}."
    warn "Verifica la contraseña o que la red esté al alcance."
    exit 1
  fi
else
  info "Red abierta: conectando a ${ssid} sin contraseña..."
  if ! as_root nmcli device wifi connect "${ssid}"; then
    error "No se pudo conectar a ${ssid}."
    warn "Verifica que la red esté al alcance."
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 4) Verificación: conexión activa e IP obtenida
# ---------------------------------------------------------------------------
info "Verificando la conexión activa..."
if nmcli connection show --active | grep -Fqi "${ssid}"; then
  ok "Conectado a ${ssid}"
  info "Dirección(es) IP:"
  ip -4 -o addr show up scope global | awk '{print "  - " $2 ": " $4}'
else
  warn "No se encontró una conexión activa con SSID '${ssid}'."
  nmcli connection show --active || true
fi

ok "Proceso de conexión WiFi finalizado"