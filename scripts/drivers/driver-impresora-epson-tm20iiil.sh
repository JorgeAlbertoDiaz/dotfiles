#!/usr/bin/env bash
# driver-impresora-epson-tm20iiil — entry-point por hardware para una impresora
# térmica de recibos Epson TM-T20IIIL conectada por CABLE DIRECTO (RJ45) a la
# PC, en su propio enlace (no pasa por el router).
#
# La TM-T20IIIL es ESC/POS y NO soporta IPP (el puerto 631 está cerrado). No
# hay driver de fabricante en Tumbleweed, así que este script instala un PPD
# propio + un filtro (rastertoescpos) que convierten PDF a ESC/POS y agregan
# el avance de 10 mm antes del corte automático. Esto reemplaza la cola "raw"
# anterior, que cortaba sin margen y no ofrecía tamaño de papel a Chromium/
# Firefox (por eso el botón de imprimir aparecía desactivado).
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
# 3.5) Filtro + PPD del driver
#      El filtro convierte PDF a ESC/POS (raster + avance de corte); el PPD
#      declara el tamaño de rollo 80 mm y engancha el filtro. Ambos viven en
#      el repo (scripts/drivers/) y se copian a sus rutas de CUPS.
# ---------------------------------------------------------------------------
FILTER_SRC="${SCRIPT_DIR}/rastertoescpos"
FILTER_DST="/usr/lib/cups/filter/rastertoescpos"
PPD_SRC="${SCRIPT_DIR}/Epson-TM-T20III.ppd"
PPD_DST="/usr/share/cups/model/Epson-TM-T20III.ppd"

asegurar_filtro() {
  if [[ ! -f "${FILTER_SRC}" ]]; then
    warn "No se encontró ${FILTER_SRC}; se omite el filtro."
    return 1
  fi
  if [[ -f "${FILTER_DST}" ]] && cmp -s "${FILTER_SRC}" "${FILTER_DST}"; then
    ok "Filtro rastertoescpos ya instalado y al día"
  else
    info "Instalando filtro rastertoescpos en ${FILTER_DST}"
    as_root install -o root -g root -m 0755 "${FILTER_SRC}" "${FILTER_DST}"
    ok "Filtro instalado"
  fi
  return 0
}

asegurar_ppd() {
  if [[ ! -f "${PPD_SRC}" ]]; then
    warn "No se encontró ${PPD_SRC}; se omite el PPD."
    return 1
  fi
  if [[ -f "${PPD_DST}" ]] && cmp -s "${PPD_SRC}" "${PPD_DST}"; then
    ok "PPD TM-T20III ya instalado y al día"
  else
    info "Instalando PPD en ${PPD_DST}"
    as_root install -o root -g root -m 0644 "${PPD_SRC}" "${PPD_DST}"
    ok "PPD instalado"
  fi
  return 0
}

filtro_ok=1; ppd_ok=1
asegurar_filtro || filtro_ok=0
asegurar_ppd || ppd_ok=0

# ---------------------------------------------------------------------------
# 4) Cola CUPS con driver (PPD + filtro), idempotente
#     Si la cola ya existe y apunta al URI correcto, no se llama a lpadmin.
# ---------------------------------------------------------------------------
uri_actual_cola() {
  LC_ALL=C lpstat -v "${PRINTER_NAME}" 2>/dev/null \
    | sed -n 's/^device for [^:]*:[[:space:]]*//p' | head -n1
}

alta_cola() {
  if [[ ${ppd_ok} -eq 0 ]]; then
    warn "Sin PPD instalado; no se puede dar de alta la cola con driver."
    return 1
  fi
  info "Configurando '${PRINTER_NAME}' -> ${PRINTER_URI} (PPD + filtro ESC/POS)"
  if as_root lpadmin -p "${PRINTER_NAME}" -E -v "${PRINTER_URI}" -i "${PPD_DST}"; then
    ok "Cola '${PRINTER_NAME}' configurada (driver ESC/POS con corte)"
    return 0
  fi
  warn "lpadmin falló para ${PRINTER_URI}."
  return 1
}

# ¿La cola ya usa un driver (PPD) en vez de raw? Se mira printer-make-and-model
# vía lpoptions, que NO requiere leer el .ppd (root:lp 640, ilegible por el
# usuario normal). Una cola raw reporta exactamente "Local Raw Printer".
# Falso => hay que reconfigurar con el PPD + filtro.
cola_usa_driver() {
  local mm
  mm="$(LC_ALL=C lpoptions -p "${PRINTER_NAME}" 2>/dev/null \
        | tr ' ' '\n' | sed -n "s/^printer-make-and-model='//p" | head -n1)" || true
  [[ -n "${mm}" && "${mm}" != "Local" ]]
}

if lpstat -p "${PRINTER_NAME}" &>/dev/null; then
  uri_actual="$(uri_actual_cola || true)"
  if [[ "${uri_actual}" == "${PRINTER_URI}" ]] && cola_usa_driver; then
    ok "La cola '${PRINTER_NAME}' ya apunta a ${PRINTER_URI} y usa el driver ESC/POS; no se toca."
  elif [[ "${uri_actual}" == "${PRINTER_URI}" ]] && ! cola_usa_driver; then
    warn "La cola '${PRINTER_NAME}' apunta al URI correcto pero NO usa el driver"
    warn "(posiblemente quedó como raw). Se reconfigura con el PPD + filtro."
    alta_cola || exit 1
  elif confirm "La cola '${PRINTER_NAME}' apunta a '${uri_actual:-desconocido}'. ¿Actualizarla a ${PRINTER_URI} con el driver?"; then
    alta_cola || exit 1
  else
    info "Se conserva la cola existente."
  fi
else
  info "La cola '${PRINTER_NAME}' no está agregada todavía."
  if confirm "¿Agregar '${PRINTER_NAME}' (${PRINTER_URI}, driver ESC/POS)?"; then
    alta_cola || exit 1
  else
    warn "Alta cancelada; la impresora queda sin configurar."
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# 5) Ticket de prueba (PDF -> ESC/POS, opcional)
# ---------------------------------------------------------------------------
if confirm "¿Imprimir un ticket de prueba (PDF -> ESC/POS)?"; then
  tmp="$(mktemp --suffix=.pdf)"
  # PDF válido de una línea, generado con ghostscript (con xref correcto),
  # no con printf crudo: un PDF sin xref hace fallar a pdftopdf (etapa previa
  # al filtro) con "file is damaged". Cadena completa:
  #   PDF -> pdftopdf -> application/vnd.cups-pdf -> rastertoescpos -> ESC/POS.
  printf '%%!PS\n/Courier findfont 16 scalefont setfont\n10 100 moveto\n(Prueba TM-T20III via filtro) show\nshowpage\n' > "${tmp}.ps"
  if command -v gs &>/dev/null; then
    gs -dSAFER -dBATCH -dNOPAUSE -dQUIET -sDEVICE=pdfwrite \
       -sPAPERSIZE=custom -dDEVICEWIDTHPOINTS=227 -dDEVICEHEIGHTPOINTS=300 \
       -sOutputFile="${tmp}" "${tmp}.ps" 2>/dev/null
  else
    mv "${tmp}.ps" "${tmp}"
  fi
  rm -f "${tmp}.ps"
  if lp -d "${PRINTER_NAME}" "${tmp}"; then
    ok "Ticket de prueba enviado a ${PRINTER_NAME}"
  else
    warn "No se pudo enviar el ticket de prueba."
  fi
  rm -f "${tmp}"
fi

ok "Epson TM-T20IIIL lista"
