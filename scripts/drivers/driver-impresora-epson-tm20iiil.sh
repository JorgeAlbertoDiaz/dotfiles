#!/usr/bin/env bash
# driver-impresora-epson-tm20iiil — entry-point por hardware para una impresora
# térmica de recibos Epson TM-T20IIIL conectada por CABLE DIRECTO (RJ45) a la
# PC, en su propio enlace (no pasa por el router).
#
# La TM-T20IIIL es ESC/POS y NO soporta IPP (el puerto 631 está cerrado). Por
# eso la cola de CUPS es "raw": CUPS entrega los bytes ESC/POS tal cual los
# manda la aplicación (típicamente un sistema de punto de venta). No requiere
# driver de fabricante ni paquetes extra.
#
# Red: la impresora conserva su IP fija 192.168.192.168/24 (DHCP apagado) y la
# PC toma 192.168.192.1/24 en la interfaz cableada. Se administra con
# NetworkManager; el perfil usa never-default para no pisar la ruta por defecto
# de la WiFi.
#
# Autocontenido e idempotente, igual que el resto de scripts/drivers/ (ver
# driver-impresora-hp-smart-tank-580.sh para el patrón).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# lpadmin/lpstat viven en /usr/sbin, que puede no estar en el PATH de una shell
# no-login.
export PATH="/usr/sbin:/sbin:${PATH}"

PRINTER_NAME="Epson_TM_T20IIIL"
PRINTER_IP="${EPSON_PRINTER_IP:-192.168.192.168}"
PC_IP="${EPSON_PC_IP:-192.168.192.1}"
PRINTER_URI="socket://${PRINTER_IP}:9100"
CON_NAME="epson-direct"

# ---------------------------------------------------------------------------
# 1) CUPS con backend socket (idempotente)
# ---------------------------------------------------------------------------
if rpm -q cups &>/dev/null; then
  ok "cups ya instalado"
else
  info "Instalando cups"
  if as_root zypper -n in cups; then
    ok "cups instalado"
  else
    warn "No se pudo instalar cups; se continúa."
  fi
fi

if systemctl is-active --quiet cups.service || systemctl is-active --quiet cups.socket; then
  ok "CUPS ya está activo"
else
  info "Habilitando CUPS"
  as_root systemctl enable --now cups.service
  ok "CUPS habilitado"
fi

# ---------------------------------------------------------------------------
# 2) Enlace directo PC <-> impresora (NetworkManager)
#    La impresora vive en 192.168.192.0/24 con DHCP apagado; la PC necesita una
#    IP en esa subred en su interfaz cableada. never-default evita que este
#    enlace pise la ruta por defecto (la WiFi sigue siendo el gateway).
# ---------------------------------------------------------------------------
interfaz_cableada() {
  nmcli -t -f DEVICE,TYPE dev status 2>/dev/null \
    | awk -F: '$2 == "ethernet" { print $1; exit }'
}

IFACE="$(interfaz_cableada || true)"

if [[ -z "${IFACE}" ]]; then
  warn "No se detectó ninguna interfaz Ethernet; se omite la configuración de red."
elif nmcli -t -f NAME con show 2>/dev/null | grep -qx "${CON_NAME}"; then
  ok "Perfil NetworkManager '${CON_NAME}' ya existe"
  as_root nmcli con up "${CON_NAME}" &>/dev/null \
    || warn "No se pudo activar '${CON_NAME}' (¿cable conectado y Epson encendida?)"
else
  info "Creando perfil '${CON_NAME}' en ${IFACE} (${PC_IP}/24, never-default)"
  if as_root nmcli con add type ethernet ifname "${IFACE}" con-name "${CON_NAME}" \
       ipv4.method manual ipv4.addresses "${PC_IP}/24" \
       ipv4.never-default yes ipv6.method disabled \
       connection.autoconnect yes connection.autoconnect-priority 10; then
    ok "Perfil '${CON_NAME}' creado"
    as_root nmcli con up "${CON_NAME}" &>/dev/null \
      || warn "Perfil creado pero sin link (¿cable conectado y Epson encendida?)"
  else
    warn "No se pudo crear el perfil '${CON_NAME}'."
  fi
fi

# ---------------------------------------------------------------------------
# 3) Alcance a la impresora
# ---------------------------------------------------------------------------
if ping -c 2 -W 2 "${PRINTER_IP}" &>/dev/null; then
  ok "La impresora responde en ${PRINTER_IP}"
else
  warn "No hay respuesta de ${PRINTER_IP}."
  warn "Revisá: cable RJ45 PC<->Epson, impresora encendida, e IP ${PRINTER_IP}."
fi

# ---------------------------------------------------------------------------
# 4) Cola CUPS raw (ESC/POS), idempotente
#     Si la cola ya existe y apunta al URI correcto, no se llama a lpadmin.
# ---------------------------------------------------------------------------
uri_actual_cola() {
  LC_ALL=C lpstat -v "${PRINTER_NAME}" 2>/dev/null \
    | sed -n 's/^device for [^:]*:[[:space:]]*//p' | head -n1
}

alta_cola() {
  info "Configurando '${PRINTER_NAME}' -> ${PRINTER_URI} (raw ESC/POS)"
  if as_root lpadmin -p "${PRINTER_NAME}" -E -v "${PRINTER_URI}" -m raw; then
    ok "Cola '${PRINTER_NAME}' configurada (raw ESC/POS)"
    return 0
  fi
  warn "lpadmin falló para ${PRINTER_URI}."
  return 1
}

if lpstat -p "${PRINTER_NAME}" &>/dev/null; then
  uri_actual="$(uri_actual_cola || true)"
  if [[ "${uri_actual}" == "${PRINTER_URI}" ]]; then
    ok "La cola '${PRINTER_NAME}' ya apunta a ${PRINTER_URI}; no se toca."
  elif confirm "La cola '${PRINTER_NAME}' apunta a '${uri_actual:-desconocido}'. ¿Actualizarla a ${PRINTER_URI}?"; then
    alta_cola || exit 1
  else
    info "Se conserva la cola existente."
  fi
else
  info "La cola '${PRINTER_NAME}' no está agregada todavía."
  if confirm "¿Agregar '${PRINTER_NAME}' (${PRINTER_URI}, raw ESC/POS)?"; then
    alta_cola || exit 1
  else
    warn "Alta cancelada; la impresora queda sin configurar."
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# 5) Ticket de prueba ESC/POS (opcional)
# ---------------------------------------------------------------------------
if confirm "¿Imprimir un ticket de prueba?"; then
  tmp="$(mktemp)"
  printf '\033@\033a\001== Epson TM-T20IIIL ==\n\033a\000Prueba desde Linux\nIP: %s\n\n\n\035V\001' "${PRINTER_IP}" > "${tmp}"
  if lp -d "${PRINTER_NAME}" -o raw "${tmp}"; then
    ok "Ticket de prueba enviado a ${PRINTER_NAME}"
  else
    warn "No se pudo enviar el ticket de prueba."
  fi
  rm -f "${tmp}"
fi

ok "Epson TM-T20IIIL lista"
