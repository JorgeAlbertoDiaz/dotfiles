#!/usr/bin/env bash
# driver-impresora-hp-smart-tank-580 — entry-point por hardware para una
# impresora HP Smart Tank 580 conectada por WiFi (misma LAN).
#
# Autocontenido e idempotente, igual que el resto de scripts/drivers/ (ver
# driver-nvidia-gtx1060.sh para el patrón).
#
# Cola de impresión: IPP Everywhere (driverless / AirPrint), que la Smart Tank
# 580 soporta, así que NO hace falta el PPD de fabricante. avahi + nss-mdns
# permiten descubrirla por mDNS; si el descubrimiento no sirve o devuelve un
# hostname que no resuelve, se puede escribir la IP/hostname a mano.
#
# El submenú scripts/drivers/drivers-menu.sh la descubre sola por el nombre.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../common.sh"

# lpadmin/lpinfo viven en /usr/sbin, que puede no estar en el PATH de una shell
# no-login. Se agrega acá para poder llamarlos directo (y también para el
# command -v de más abajo).
export PATH="/usr/sbin:/sbin:${PATH}"

PRINTER_NAME="HP_Smart_Tank_580"
# En Tumbleweed los filtros de CUPS 2.x viven en "cups-filters2". El paquete
# legacy "cups-filters" (1.x) choca con libcupsfilters/cups-filters2 ya
# instalados: zypper no puede resolver el conflicto y aborta con código 4
# (ZYPPER_EXIT_ERR_ZYPP). Por eso se pide "cups-filters2".
PKGS=(cups cups-filters2 avahi nss-mdns)

# ---------------------------------------------------------------------------
# 1) Paquetes
#    Idempotente: sólo se instala lo que falte (rpm -q).
# ---------------------------------------------------------------------------
missing=()
for pkg in "${PKGS[@]}"; do
  if rpm -q "${pkg}" &>/dev/null; then
    ok "${pkg} ya instalado"
  else
    missing+=("${pkg}")
  fi
done

if [[ ${#missing[@]} -gt 0 ]]; then
  info "Instalando paquetes de impresión: ${missing[*]}"
  # "warn y seguir" (igual que driver-nvidia-gtx1060.sh): un problema de
  # paquetes no debe tumbar toda la instalación. Si cups y los filtros ya
  # están, la cola se puede configurar igual.
  if as_root zypper -n in "${missing[@]}"; then
    ok "Paquetes de impresión instalados"
  else
    warn "zypper no pudo instalar: ${missing[*]}"
    warn "Se continúa; si cups y cups-filters2 ya están, la cola puede configurarse igual."
  fi
else
  ok "Paquetes de impresión ya instalados"
fi

# ---------------------------------------------------------------------------
# 2) Servicios (CUPS + avahi para el descubrimiento mDNS)
# ---------------------------------------------------------------------------
if systemctl is-active --quiet cups.service || systemctl is-active --quiet cups.socket; then
  ok "CUPS ya está activo"
else
  info "Habilitando CUPS"
  as_root systemctl enable --now cups.service
  ok "CUPS habilitado"
fi

if systemctl is-active --quiet avahi-daemon.service; then
  ok "avahi-daemon ya está activo"
elif rpm -q avahi &>/dev/null; then
  info "Habilitando avahi-daemon (descubrimiento mDNS)"
  as_root systemctl enable --now avahi-daemon.service
  ok "avahi-daemon habilitado"
else
  warn "avahi no está instalado; se omite el descubrimiento mDNS (se puede configurar por IP)."
fi

# ---------------------------------------------------------------------------
# 2b) Parche: cadena de conversión PDF -> raster en la base MIME de CUPS
#
#     CUPS no le manda el PDF a la impresora: el scheduler arma una CADENA de
#     filtros usando su base MIME (*.types / *.convs) y recién después habla
#     con el aparato. Para una cola IPP Everywhere sobre una impresora que no
#     soporta PDF nativo (la Smart Tank ofrece PCL3GUI, JPEG, PCLm, urf y
#     PWG-raster) esa cadena es:
#
#       application/pdf --pdftopdf--> application/vnd.cups-pdf
#                       --pdftoraster/gstoraster--> image/urf --> impresora
#
#     openSUSE construye cups-filters2 con --disable-universal-cups-filter pero
#     SIN --enable-individual-cups-filters (upstream deja ese flag en "no"),
#     así que no instala ninguno de los dos juegos de reglas: quedan sólo las de
#     texto de cupsfilters.convs. Los filtros (pdftopdf, pdftoraster,
#     gstoraster, bannertopdf) SÍ están instalados; falta el cableado. Sin él
#     CUPS rechaza el trabajo ANTES de tocar la impresora:
#
#       E [..] Returning IPP client-error-document-format-not-supported for
#              Print-Job (ipp://localhost:631/printers/HP_Smart_Tank_580)
#
#     Síntoma típico: la impresora figura, responde al ping y su web interna
#     imprime, pero desde Firefox/LibreOffice no sale nada y el trabajo
#     desaparece de la cola.
#
#     Se instalan los tres fragmentos VERBATIM del tarball upstream, con su
#     sha256, en el mismo directorio donde el paquete ya pone cupsfilters.convs.
#     Es un parche de empaquetado, no de la impresora: cuando openSUSE arregle
#     el spec, estos archivos se pueden borrar.
#     Detalle y reporte: docs/referencia/bug-opensuse-cups-filters2-pdf.md
# ---------------------------------------------------------------------------

# Directorios donde el scheduler busca los *.convs.
MIME_DIRS=(/usr/share/cups/mime /etc/cups/mime)

# ¿La base MIME ya sabe convertir PDF a raster? La regla que falta es la que
# declara a pdftoraster; su ausencia es la firma exacta del paquete roto.
cadena_pdf_presente() {
  local dir f
  for dir in "${MIME_DIRS[@]}"; do
    [[ -d "${dir}" ]] || continue
    for f in "${dir}"/*.convs; do
      [[ -f "${f}" ]] || continue        # glob sin coincidencias
      if grep -q 'pdftoraster' "${f}"; then
        return 0
      fi
    done
  done
  return 1
}

# Fragmentos que openSUSE no empaqueta, con el sha256 del tarball upstream.
CF2_VERSION="2.0.1"
declare -A CF2_FRAGMENTOS=(
  [cupsfilters-individual.convs]="f93f0d376c9e599452e14de9985057db3121d480ac42858c1d0e6d27d10a5fca"
  [cupsfilters-poppler.convs]="cdd618c0241596c02629827f7396534660ba0244d53cefdc0bc1fdcb61e93809"
  [cupsfilters-ghostscript.convs]="bcfbd2844af42749d4671496d6f73c82084589c2d7ce08306eaefd51848762ba"
)
CF2_URL="https://github.com/OpenPrinting/cups-filters/releases/download/${CF2_VERSION}/cups-filters-${CF2_VERSION}.tar.xz"

# Baja los fragmentos, verifica los 3 sha256 y recién entonces instala.
# Cualquier fallo deja el sistema como estaba.
instalar_fragmentos_mime() {
  local tmpdir tarball f src sum
  local -a origen=()

  if ! command -v curl &>/dev/null; then
    warn "curl no está disponible; no se puede bajar el parche."
    return 1
  fi

  tmpdir="$(mktemp -d)"
  tarball="${tmpdir}/cups-filters-${CF2_VERSION}.tar.xz"

  info "Descargando cups-filters ${CF2_VERSION} (upstream)"
  if ! curl -fsSL --output "${tarball}" "${CF2_URL}"; then
    warn "No se pudo descargar ${CF2_URL}"
    rm -rf "${tmpdir}"
    return 1
  fi

  if ! tar -xf "${tarball}" -C "${tmpdir}" "cups-filters-${CF2_VERSION}/mime"; then
    warn "No se pudo extraer mime/ del tarball"
    rm -rf "${tmpdir}"
    return 1
  fi

  for f in "${!CF2_FRAGMENTOS[@]}"; do
    src="${tmpdir}/cups-filters-${CF2_VERSION}/mime/${f}"
    if [[ ! -f "${src}" ]]; then
      warn "El tarball no trae ${f}"
      rm -rf "${tmpdir}"
      return 1
    fi
    sum="$(sha256sum "${src}" | cut -d' ' -f1)"
    if [[ "${sum}" != "${CF2_FRAGMENTOS[${f}]}" ]]; then
      warn "sha256 inesperado en ${f}"
      warn "  esperado: ${CF2_FRAGMENTOS[${f}]}"
      warn "  obtenido: ${sum}"
      rm -rf "${tmpdir}"
      return 1
    fi
    origen+=("${src}")
  done
  ok "sha256 de los 3 fragmentos verificado"

  as_root install -o root -g root -m 0644 "${origen[@]}" "${MIME_DIRS[0]}/"
  rm -rf "${tmpdir}"

  info "Reiniciando CUPS para que relea la base MIME"
  as_root systemctl restart cups.service
  return 0
}

# Detecta -> decide -> actúa, igual que el alta de la cola.
asegurar_cadena_pdf() {
  if cadena_pdf_presente; then
    ok "CUPS ya tiene la conversión PDF -> raster"
    return 0
  fi

  warn "CUPS no tiene reglas para convertir PDF: los trabajos de Firefox,"
  warn "LibreOffice y la página de prueba van a ser RECHAZADOS."
  info "Parche: instalar los fragmentos MIME que openSUSE no empaqueta."
  info "Son 3 archivos en ${MIME_DIRS[0]}; ver docs/referencia/bug-opensuse-cups-filters2-pdf.md"

  if ! confirm "¿Aplicar el parche ahora?"; then
    warn "Sin parche, imprimir desde aplicaciones no va a funcionar."
    return 0
  fi

  if ! instalar_fragmentos_mime; then
    warn "No se pudo aplicar el parche."
    warn "A mano: bajá ${CF2_URL} e instalá"
    warn "cupsfilters-{individual,poppler,ghostscript}.convs en ${MIME_DIRS[0]}/"
    return 1
  fi

  if cadena_pdf_presente; then
    ok "Cadena PDF -> raster instalada"
  else
    warn "Se copiaron los archivos pero la regla no aparece; revisá ${MIME_DIRS[0]}/"
  fi
  return 0
}

asegurar_cadena_pdf || warn "Se continúa sin el parche de PDF."

# ---------------------------------------------------------------------------
# 3) Resolver el URI de la impresora
#    Primero se intenta descubrir por mDNS (lpinfo -v). Si no aparece, o el
#    usuario prefiere otra cosa, se pide la IP/hostname.
# ---------------------------------------------------------------------------
descubrir_uri() {
  local uri
  # URI IPP cuyo nombre sugiera HP/Smart Tank.
  uri="$(lpinfo -v 2>/dev/null | awk '$1 == "network" && $2 ~ /^ipp:\/\// { print $2 }' \
          | grep -iE 'smart|hp' | head -n1)" || true
  if [[ -n "${uri}" ]]; then
    printf '%s' "${uri}"
    return 0
  fi
  # Si hay un único URI IPP descubierto, se usa ese.
  local -a todos
  mapfile -t todos < <(lpinfo -v 2>/dev/null | awk '$1 == "network" && $2 ~ /^ipp:\/\// { print $2 }')
  if [[ ${#todos[@]} -eq 1 ]]; then
    printf '%s' "${todos[0]}"
    return 0
  fi
  return 1
}

pedir_uri() {
  local host
  if has_gum; then
    host="$(gum input --prompt 'IP o hostname de la HP Smart Tank 580: ' 2>/dev/null)" || return 1
  else
    read -r -p "IP o hostname de la HP Smart Tank 580: " host || return 1
  fi
  [[ -n "${host}" ]] || return 1
  printf 'ipp://%s/ipp/print' "${host}"
}

# ---------------------------------------------------------------------------
# 3b) Alta idempotente: detectar y preguntar antes de tocar CUPS
#     - Si la cola ya existe, NO se llama a lpadmin (salvo reconfiguración
#       explícita).
#     - Si no existe, se pide confirmación antes de darla de alta.
#     El alta real queda encapsulada en alta_cola() para invocarla sólo cuando
#     corresponde; así el flujo es: detectar -> decidir -> actuar.
# ---------------------------------------------------------------------------

# URI con el que CUPS ya tiene la cola (vacío si no la tiene).
# LC_ALL=C evita depender del idioma de lpstat ("device for ...").
uri_actual_cola() {
  LC_ALL=C lpstat -v "${PRINTER_NAME}" 2>/dev/null \
    | sed -n 's/^device for [^:]*:[[:space:]]*//p' \
    | head -n1
}

# Resuelve el URI (mDNS o a mano), da de alta/actualiza la cola y devuelve
# 1 si no hay con qué configurarla o si lpadmin falla.
alta_cola() {
  local uri="" uri_descubierto=""

  uri_descubierto="$(descubrir_uri || true)"
  if [[ -n "${uri_descubierto}" ]]; then
    info "Descubierta por mDNS: ${uri_descubierto}"
    if confirm "¿Usar esa impresora?"; then
      uri="${uri_descubierto}"
    fi
  fi

  if [[ -z "${uri}" ]]; then
    if uri="$(pedir_uri)"; then
      ok "Usando URI: ${uri}"
    else
      warn "Sin IP/hostname; no se configura la impresora."
      return 1
    fi
  fi

  info "Configurando '${PRINTER_NAME}' con ${uri}"
  if as_root lpadmin -p "${PRINTER_NAME}" -E -v "${uri}" -m everywhere -o printer-is-shared=false; then
    ok "Cola '${PRINTER_NAME}' configurada (IPP Everywhere)"
    return 0
  fi
  warn "lpadmin falló con ${uri}."
  warn "Revisá que la impresora esté encendida y en la misma LAN, y reintentá con su IP."
  return 1
}

# ---------------------------------------------------------------------------
# 4) Decisión: ya está agregada / no está agregada
# ---------------------------------------------------------------------------
if lpstat -p "${PRINTER_NAME}" &>/dev/null; then
  uri_actual="$(uri_actual_cola || true)"
  ok "La cola '${PRINTER_NAME}' ya está agregada${uri_actual:+ -> ${uri_actual}}"
  if confirm "¿Reconfigurarla igual (volver a llamar a lpadmin)?"; then
    alta_cola || exit 1
  else
    info "Se conserva la cola existente; no se llama a lpadmin."
  fi
else
  info "La cola '${PRINTER_NAME}' no está agregada todavía."
  if confirm "¿Agregar '${PRINTER_NAME}' ahora con IPP Everywhere?"; then
    alta_cola || exit 1
  else
    warn "Alta cancelada; la impresora queda sin configurar."
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# 5) Predeterminada + página de prueba
# ---------------------------------------------------------------------------
if confirm "¿Usar la HP Smart Tank 580 como impresora predeterminada?"; then
  as_root lpadmin -d "${PRINTER_NAME}"
  ok "Impresora predeterminada: ${PRINTER_NAME}"
fi

# La cola anuncia application/pdf sólo si el scheduler encontró la cadena de
# filtros: es el chequeo del lado de CUPS, antes de mandar nada al aparato.
cola_acepta_pdf() {
  command -v ipptool &>/dev/null || return 1
  ipptool -tv "ipp://localhost:631/printers/${PRINTER_NAME}" \
    get-printer-attributes.test 2>/dev/null | grep -q 'application/pdf'
}

if confirm "¿Imprimir una página de prueba?"; then
  if ! cola_acepta_pdf; then
    warn "La cola '${PRINTER_NAME}' no anuncia application/pdf: CUPS va a"
    warn "rechazar el trabajo con client-error-document-format-not-supported."
    warn "Revisá el parche de la sección 2b y: lpstat -l -p ${PRINTER_NAME}"
  fi
  if lp -d "${PRINTER_NAME}" /usr/share/cups/data/testprint; then
    ok "Página de prueba enviada a ${PRINTER_NAME}"
  else
    warn "No se pudo enviar la página de prueba."
  fi
fi

ok "HP Smart Tank 580 lista"
