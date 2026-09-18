#!/usr/bin/env bash
# 07-network-config: configura la red (IP estática o DHCP) de una conexión
# existente de NetworkManager con nmcli.
#
#   - Verifica que nmcli esté disponible.
#   - Lista las conexiones existentes y deja elegir una (gum o select bash).
#   - Muestra la configuración IP4 actual.
#   - Pregunta el modo: DHCP o Estática (IP, prefijo/máscara, gateway, DNS).
#   - Aplica los cambios con as_root y reactiva la conexión.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if ! command -v nmcli &>/dev/null; then
  error "NetworkManager no está instalado (paquete 'NetworkManager' en openSUSE)."
  warn "Instálalo con: sudo zypper -n in NetworkManager"
  exit 1
fi

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Pregunta un valor (gum input si está, sino read). Devuelve 1 si se cancela.
ask_input() {
  local prompt="$1" default="${2:-}" valor
  if command -v gum &>/dev/null; then
    if ! valor="$(gum input --prompt "${prompt} " --value "${default}" 2>/dev/null)"; then
      return 1
    fi
  else
    read -r -p "${prompt} [${default}]: " valor || return 1
    valor="${valor:-${default}}"
  fi
  printf '%s\n' "${valor}"
}

# Valida una dirección IPv4.
validar_ip() {
  local ip="$1" oct
  [[ "${ip}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 1
  IFS=. read -r o1 o2 o3 o4 <<< "${ip}"
  for oct in "${o1}" "${o2}" "${o3}" "${o4}"; do
    (( 10#${oct} > 255 )) && return 1
  done
  return 0
}

# Convierte una máscara (255.255.255.0) a su prefijo (/24).
mask_to_prefix() {
  local mask="$1" bin="" oct n b
  [[ "${mask}" =~ ^[0-9]+(\.[0-9]+){3}$ ]] || return 1
  IFS=. read -r o1 o2 o3 o4 <<< "${mask}"
  for oct in "${o1}" "${o2}" "${o3}" "${o4}"; do
    (( 10#${oct} > 255 )) && return 1
    n=$((10#${oct}))
    b=""
    while (( n > 0 )); do
      b="$(( n % 2 ))${b}"
      n=$(( n / 2 ))
    done
    bin+="$(printf '%08d' "${b:-0}")"
  done
  printf '%s\n' "$(printf '%s' "${bin}" | tr -d '0' | wc -c)"
}

# ---------------------------------------------------------------------------
# 1) Elegir una conexión existente
#    Nota: los nombres de conexión que contienen ':' no se parsean
#    correctamente con nmcli -t (limitación del formato terse).
# ---------------------------------------------------------------------------
mapfile -t conexiones < <(nmcli -t -f NAME,TYPE connection show 2>/dev/null)

if [[ ${#conexiones[@]} -eq 0 ]]; then
  error "No hay conexiones configuradas en NetworkManager."
  exit 1
fi

nombres=()
tipos=()
for c in "${conexiones[@]}"; do
  nombre="${c%%:*}"
  nombre="${nombre//\\:/:}"
  tipo="${c#*:}"
  nombres+=("${nombre}")
  tipos+=("${tipo}")
done

if command -v gum &>/dev/null; then
  opciones=()
  for i in "${!nombres[@]}"; do
    opciones+=("${nombres[$i]}  (${tipos[$i]})")
  done
  if ! elegida="$(gum choose --height 12 "Cancelar" "${opciones[@]}")"; then
    warn "Operación cancelada."
    exit 1
  fi
else
  info "Conexiones disponibles:"
  PS3="> "
  select elegida in "Cancelar" "${nombres[@]}"; do
    [[ -n "${elegida}" ]] && break
    warn "Opción inválida, intente de nuevo."
  done
fi

[[ "${elegida}" == "Cancelar" ]] && { warn "Operación cancelada."; exit 0; }

idx=""
if command -v gum &>/dev/null; then
  # Con gum la opción elegida es la cadena formateada ("Nombre  (tipo)"), no el
  # nombre crudo; buscarla en opciones (mismos índices que nombres; "Cancelar"
  # es un argumento literal del menú y se descartó antes).
  for i in "${!opciones[@]}"; do
    if [[ "${opciones[$i]}" == "${elegida}" ]]; then
      idx="${i}"
      break
    fi
  done
else
  for i in "${!nombres[@]}"; do
    if [[ "${nombres[$i]}" == "${elegida}" ]]; then
      idx="${i}"
      break
    fi
  done
fi
if [[ -z "${idx}" ]]; then
  error "No se pudo identificar la conexión elegida."
  exit 1
fi

nombre="${nombres[$idx]}"
info "Conexión elegida: ${nombre} (${tipos[$idx]})"

info "Configuración IP4 actual de '${nombre}':"
nmcli -f IP4 connection show "${nombre}" || true

# ---------------------------------------------------------------------------
# 2) Elegir modo: DHCP o Estática
# ---------------------------------------------------------------------------
if command -v gum &>/dev/null; then
  if ! modo="$(gum choose "DHCP" "Estática")"; then
    warn "Operación cancelada."
    exit 1
  fi
else
  PS3="> "
  select modo in "DHCP" "Estática"; do
    [[ -n "${modo}" ]] && break
    warn "Opción inválida, intente de nuevo."
  done
fi

# ---------------------------------------------------------------------------
# 3a) Modo DHCP
# ---------------------------------------------------------------------------
if [[ "${modo}" == "DHCP" ]]; then
  info "Configurando ${nombre} en modo DHCP..."
  as_root nmcli connection modify "${nombre}" ipv4.method auto
  warn "Reactivando la conexión (puede perder conectividad momentáneamente)..."
  as_root nmcli connection up "${nombre}"
else
  # -------------------------------------------------------------------------
  # 3b) Modo Estática
  # -------------------------------------------------------------------------
  actual_ip="$(nmcli -g IP4.ADDRESS connection show "${nombre}" 2>/dev/null | head -n1 || true)"
  actual_gw="$(nmcli -g IP4.GATEWAY connection show "${nombre}" 2>/dev/null | head -n1 || true)"
  prefijo_actual=""
  if [[ "${actual_ip}" == */* ]]; then
    prefijo_actual="${actual_ip##*/}"
  fi

  ip=""
  while [[ -z "${ip}" ]]; do
    ip="$(ask_input "Dirección IP (ej: 192.168.1.50)" "${actual_ip%%/*}" || true)"
    ip="${ip:-}"
    if [[ -n "${ip}" ]] && ! validar_ip "${ip}"; then
      warn "IP no válida: ${ip}"
      ip=""
    fi
  done

  prefijo=""
  while [[ -z "${prefijo}" ]]; do
    prefijo="$(ask_input "Prefijo de red (ej: 24) o máscara (ej: 255.255.255.0)" "${prefijo_actual:-24}" || true)"
    prefijo="${prefijo:-}"
    if [[ -n "${prefijo}" && "${prefijo}" == *"."* ]]; then
      if ! prefijo="$(mask_to_prefix "${prefijo}")"; then
        warn "Máscara no válida: ${prefijo}"
        prefijo=""
      fi
    elif [[ -n "${prefijo}" ]]; then
      if [[ ! "${prefijo}" =~ ^[0-9]+$ ]] || (( 10#${prefijo} > 32 )); then
        warn "Prefijo no válido (0-32): ${prefijo}"
        prefijo=""
      fi
    fi
  done

  gw=""
  while [[ -z "${gw}" ]]; do
    gw="$(ask_input "Gateway (ej: 192.168.1.1)" "${actual_gw}" || true)"
    gw="${gw:-}"
    if [[ -n "${gw}" ]] && ! validar_ip "${gw}"; then
      warn "Gateway no válido: ${gw}"
      gw=""
    fi
  done

  dns_csv=""
  dns="$(ask_input "DNS (varios separados por coma, ej: 8.8.8.8,1.1.1.1)" "" || true)"
  dns="${dns:-}"
  if [[ -n "${dns}" ]]; then
    dns_csv=""
    IFS=',' read -r -a dns_lista <<< "${dns}"
    for d in "${dns_lista[@]}"; do
      d="${d//[[:space:]]/}"
      if validar_ip "${d}"; then
        dns_csv+="${dns_csv:+,}${d}"
      else
        warn "DNS no válido, omitiendo: ${d}"
      fi
    done
  fi

  info "Aplicando configuración estática a ${nombre}: IP ${ip}/${prefijo}, gateway ${gw}"
  if [[ -n "${dns_csv}" ]]; then
    as_root nmcli connection modify "${nombre}" \
      ipv4.method manual \
      ipv4.addresses "${ip}/${prefijo}" \
      ipv4.gateway "${gw}" \
      ipv4.dns "${dns_csv}"
  else
    as_root nmcli connection modify "${nombre}" \
      ipv4.method manual \
      ipv4.addresses "${ip}/${prefijo}" \
      ipv4.gateway "${gw}"
    warn "No se configuraron DNS; se mantienen los actuales de la conexión."
  fi

  warn "Reactivando la conexión (puede perder conectividad momentáneamente)..."
  as_root nmcli connection up "${nombre}"
fi

# ---------------------------------------------------------------------------
# 4) Verificación
# ---------------------------------------------------------------------------
info "Nueva configuración IP4 de '${nombre}':"
nmcli -f IP4.ADDRESS,IP4.GATEWAY,IP4.DNS connection show "${nombre}" || true

ok "Configuración de red finalizada"