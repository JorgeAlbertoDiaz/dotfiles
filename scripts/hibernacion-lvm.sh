#!/usr/bin/env bash
# hibernacion-lvm: prepara la hibernación (suspend-to-disk) en openSUSE con swap
# sobre LVM, y verifica cada paso.
#
# Uso:
#   scripts/hibernacion-lvm.sh            # igual que --check
#   scripts/hibernacion-lvm.sh --check    # solo diagnostica: no cambia NADA
#   scripts/hibernacion-lvm.sh --apply    # propone cada cambio y pide confirmación
#   scripts/hibernacion-lvm.sh --verify   # relee el estado en vivo (post-reinicio)
#
# Nada se aplica sin una confirmación explícita, ni siquiera con --apply: cada
# paso se muestra, se pregunta, y después se verifica. El script NO reinicia.
#
# Por qué LVM y no un swapfile: hibernar sobre un swapfile en btrfs no está
# soportado en openSUSE (el archivo puede reasignarse y el kernel no encuentra la
# imagen al restaurar). Con una partición o un LV sí. Si el swap es un archivo,
# este script aborta en vez de intentar algo que no va a funcionar.
#
# Qué toca, si se lo autoriza:
#   1. Agranda el LV de swap para que alcance a la RAM (hoy 2 GiB vs 15 GiB).
#   2. Agrega `resume=` (y `rd.lvm.lv=`) a GRUB_CMDLINE_LINUX_DEFAULT.
#   3. Regenera grub.cfg e initramfs, que es lo que hace efectivo el resume=.
#   4. Opcional: HibernateDelaySec en /etc/systemd/sleep.conf.
#
# Documentación y estado medido: docs/referencia/hibernacion-opensuse-lvm.md
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

MODE="check"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check)  MODE="check" ;;
    --apply)  MODE="apply" ;;
    --verify) MODE="verify" ;;
    -h|--help) sed -n '2,30p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) error "Opción desconocida: $1"; exit 2 ;;
  esac
  shift
done

readonly GIB_KIB=1048576
readonly MARGEN_KIB=1048576   # 1 GiB de colchón sobre la RAM
BACKUP_SUFFIX=".bak.$(date +%Y%m%d-%H%M%S)"
readonly BACKUP_SUFFIX

# Estado detectado. Se llena en fase_estado y lo consumen todas las fases.
RAM_KIB=""
SWAP_TOTAL_KIB=""
SWAP_USADO_KIB=""
SWAP_DEV=""       # p. ej. /dev/system/swap (lo que dice fstab, estable)
SWAP_MAPPER=""    # p. ej. /dev/mapper/system-swap (lo que va en resume=)
SWAP_ACTUAL=""    # p. ej. /dev/dm-1 (lo que muestra /proc/swaps)
SWAP_TIPO=""      # partition | file | ""
VG=""
LV=""
TARGET_GIB=""

# ---------------------------------------------------------------------------
# Utilidades
# ---------------------------------------------------------------------------

# cabecera "titulo" -> separador visual para las fases.
cabecera() {
  printf '\n%b== %s ==%b\n' "${BLUE}" "$*" "${RESET}"
}

# verificar "descripción" comando... -> 0 si el comando sale bien.
verificar() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then
    ok "verificado: ${desc}"
    return 0
  fi
  error "NO verificado: ${desc}"
  return 1
}

# gib_a_mib -> bytes en GiB redondeados hacia arriba desde KiB.
kib_a_gib_techo() {
  local kib="$1"
  echo $(((kib + GIB_KIB - 1) / GIB_KIB))
}

# Respeta el modo: en check no se ejecuta nada que cambie estado.
ejecutar() {
  if [[ "${MODE}" != "apply" ]]; then
    info "(check) se omitiría: $*"
    return 1
  fi
  info "ejecutando: $*"
  "$@"
}

# ---------------------------------------------------------------------------
# Fase 1: estado
# ---------------------------------------------------------------------------
fase_estado() {
  cabecera "1/5 Estado actual"

  RAM_KIB=$(awk '/^MemTotal:/{print $2}' /proc/meminfo)
  ok "RAM: $(kib_a_gib_techo "${RAM_KIB}") GiB (${RAM_KIB} KiB)"

  # Ojo: /proc/swaps reporta tamaño 0 en stat(), así que `-s` no sirve como
  # prueba de "hay swap": hay que contar las líneas de datos.
  if [[ ! -r /proc/swaps ]] || [[ $(awk 'END{print NR-1}' /proc/swaps) -lt 1 ]]; then
    error "No hay swap activo. Sin swap no hay hibernación posible."
    return 1
  fi

  read -r SWAP_ACTUAL SWAP_TIPO SWAP_TOTAL_KIB SWAP_USADO_KIB _ < <(awk 'NR==2' /proc/swaps)
  ok "swap activo: ${SWAP_ACTUAL} (${SWAP_TIPO}), $(kib_a_gib_techo "${SWAP_TOTAL_KIB}") GiB, ${SWAP_USADO_KIB} KiB en uso"

  if [[ "${SWAP_TIPO}" == "file" ]]; then
    error "El swap es un ARCHIVO. Hibernar sobre swapfile en btrfs no está soportado:"
    error "el kernel no puede garantizar que la imagen siga en el mismo lugar al restaurar."
    error "Hace falta una partición o un LV. Abortando sin tocar nada."
    return 1
  fi

  # El dispositivo que muestra /proc/swaps es el dm-N; el nombre estable está en
  # fstab. Se usa ese, que es el que después va en resume=.
  SWAP_DEV=$(awk '$3=="swap"{print $1; exit}' /etc/fstab)
  if [[ -z "${SWAP_DEV}" ]]; then
    error "No encontré la entrada de swap en /etc/fstab; no puedo derivar un nombre estable."
    return 1
  fi
  ok "swap en fstab: ${SWAP_DEV} -> ${SWAP_ACTUAL}"

  # VG/LV a partir de /dev/<vg>/<lv> o /dev/mapper/<vg>-<lv>.
  if [[ "${SWAP_DEV}" =~ ^/dev/([^/]+)/([^/]+)$ ]]; then
    VG="${BASH_REMATCH[1]}"
    LV="${BASH_REMATCH[2]}"
  elif [[ "${SWAP_DEV}" =~ ^/dev/mapper/(.+)-([^-]+)$ ]]; then
    VG="${BASH_REMATCH[1]}"
    LV="${BASH_REMATCH[2]}"
  else
    warn "El swap no parece un LV de LVM. Este script no lo toca: aplicá los pasos a mano."
    return 1
  fi
  ok "LVM: VG=${VG} LV=${LV}"

  # resume= quiere el nombre estable del mapper, no el /dev/dm-N: la numeración
  # de device-mapper no es un contrato y el initramfs resuelve el mapper solo.
  # En /dev/mapper los guiones de los nombres van duplicados.
  SWAP_MAPPER="/dev/mapper/${VG//-/--}-${LV//-/--}"
  if [[ ! -e "${SWAP_MAPPER}" ]]; then
    SWAP_MAPPER="${SWAP_DEV}"
  fi
  if [[ "$(readlink -f "${SWAP_MAPPER}")" != "${SWAP_ACTUAL}" ]]; then
    error "fstab dice ${SWAP_DEV} pero el swap activo es ${SWAP_ACTUAL}: no coinciden"
    return 1
  fi
  ok "resume= apuntaría a: ${SWAP_MAPPER}"

  # El objetivo: RAM + 1 GiB, en GiB enteros.
  TARGET_GIB=$(kib_a_gib_techo $((RAM_KIB + MARGEN_KIB)))
  ok "swap objetivo: ${TARGET_GIB} GiB (RAM + 1 GiB de margen)"

  if ((SWAP_TOTAL_KIB >= RAM_KIB)); then
    ok "el swap ya alcanza a la RAM: no hace falta agrandarlo"
  else
    warn "el swap NO alcanza a la RAM: systemd rechaza la hibernación así"
  fi

  local estado_power
  estado_power=$(cat /sys/power/state)
  if [[ "${estado_power}" == *disk* ]]; then
    ok "el kernel soporta hibernación (/sys/power/state: ${estado_power})"
  else
    error "el kernel no ofrece 'disk' en /sys/power/state: no hay hibernación posible"
    return 1
  fi
  ok "/sys/power/disk: $(cat /sys/power/disk)"

  return 0
}

# ---------------------------------------------------------------------------
# Fase 2: resume= en el cmdline
# ---------------------------------------------------------------------------
fase_resume_param() {
  cabecera "2/5 Parámetro resume= del kernel"

  local actual
  actual=$(cat /proc/cmdline)
  if [[ "${actual}" == *"resume=${SWAP_MAPPER}"* ]]; then
    ok "el cmdline en ejecución ya trae resume=${SWAP_MAPPER}"
  else
    warn "el cmdline en ejecución NO trae resume=${SWAP_MAPPER}"
    warn "así como está, la imagen se escribiría en disco y al arrancar se perdería"
  fi

  local pendiente
  pendiente=$(grep -c "resume=" /etc/default/grub || true)
  if ((pendiente > 0)); then
    ok "/etc/default/grub ya declara resume=; no se toca"
    return 0
  fi

  info "se agregaría a GRUB_CMDLINE_LINUX_DEFAULT:"
  info "  resume=${SWAP_MAPPER} rd.lvm.lv=${VG}/${LV}"
  if [[ "${MODE}" != "apply" ]]; then
    info "(check) se preguntaría: ¿editar /etc/default/grub (con copia de respaldo)?"
    info "(check) y después: grub2-mkconfig -o /boot/grub2/grub.cfg && dracut -f"
    return 0
  fi
  if ! confirm "¿Editar /etc/default/grub (con copia de respaldo)?"; then
    warn "omitido por decisión del usuario"
    return 0
  fi

  as_root cp -a /etc/default/grub "/etc/default/grub${BACKUP_SUFFIX}"
  ok "respaldo: /etc/default/grub${BACKUP_SUFFIX}"
  as_root sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"|GRUB_CMDLINE_LINUX_DEFAULT=\"resume=${SWAP_MAPPER} rd.lvm.lv=${VG}/${LV} |" /etc/default/grub
  verificar "/etc/default/grub declara resume=" grep -q "resume=${SWAP_MAPPER}" /etc/default/grub || return 1

  if ! confirm "¿Regenerar grub.cfg e initramfs ahora? (sin esto resume= no se aplica)"; then
    warn "pendiente: grub2-mkconfig -o /boot/grub2/grub.cfg && dracut -f"
    return 0
  fi
  as_root grub2-mkconfig -o /boot/grub2/grub.cfg
  verificar "grub.cfg contiene resume=" grep -q "resume=${SWAP_MAPPER}" /boot/grub2/grub.cfg || return 1
  as_root dracut -f
  ok "initramfs regenerado"
  return 0
}

# ---------------------------------------------------------------------------
# Fase 3: tamaño del swap
# ---------------------------------------------------------------------------
fase_swap() {
  cabecera "3/5 Tamaño del swap"

  if ((SWAP_TOTAL_KIB >= RAM_KIB)); then
    ok "nada que hacer: $(kib_a_gib_techo "${SWAP_TOTAL_KIB}") GiB de swap para $(kib_a_gib_techo "${RAM_KIB}") GiB de RAM"
    return 0
  fi

  local libre_vg
  libre_vg=$(as_root vgs --noheadings --units b -o vg_free --select "vg_name=${VG}" 2>/dev/null | tr -d ' B' || true)
  if [[ -z "${libre_vg}" ]]; then
    warn "no pude leer el espacio libre de la VG ${VG} (¿hace falta sudo?)"
  else
    info "espacio libre en ${VG}: $((libre_vg / 1024 / 1024 / 1024)) GiB"
    local necesario_kib=$((TARGET_GIB * GIB_KIB - SWAP_TOTAL_KIB))
    if ((libre_vg / 1024 < necesario_kib)); then
      error "no hay espacio suficiente en ${VG} para llegar a ${TARGET_GIB} GiB de swap"
      return 1
    fi
  fi

  if ((SWAP_USADO_KIB > 0)); then
    local libre_ram_kib
    libre_ram_kib=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
    if ((SWAP_USADO_KIB > libre_ram_kib)); then
      error "hay ${SWAP_USADO_KIB} KiB en swap y solo ${libre_ram_kib} KiB de RAM disponible:"
      error "swapoff podría quedar sin memoria. Cerrá aplicaciones antes de continuar."
      return 1
    fi
  fi

  info "se haría: swapoff ${SWAP_DEV} && lvresize -L ${TARGET_GIB}G ${SWAP_DEV} && mkswap -U <UUID actual> && swapon -a"
  if [[ "${MODE}" != "apply" ]]; then
    info "(check) se preguntaría: ¿agrandar el swap de $(kib_a_gib_techo "${SWAP_TOTAL_KIB}") GiB a ${TARGET_GIB} GiB?"
    return 0
  fi
  if ! confirm "¿Agrandar el swap de $(kib_a_gib_techo "${SWAP_TOTAL_KIB}") GiB a ${TARGET_GIB} GiB?"; then
    warn "omitido por decisión del usuario"
    return 0
  fi

  local viejo_uuid=""
  viejo_uuid=$(as_root blkid -s UUID -o value "${SWAP_DEV}" 2>/dev/null || true)
  as_root swapoff "${SWAP_DEV}"
  verificar "swap desactivado" bash -c "! grep -q '^${SWAP_ACTUAL} ' /proc/swaps" || return 1
  as_root lvresize -L "${TARGET_GIB}G" "${SWAP_DEV}"
  if [[ -n "${viejo_uuid}" ]]; then
    as_root mkswap -U "${viejo_uuid}" "${SWAP_DEV}"
  else
    as_root mkswap "${SWAP_DEV}"
  fi
  as_root swapon -a
  verificar "swap reactivado" grep -q "^${SWAP_ACTUAL} " /proc/swaps || return 1

  read -r SWAP_ACTUAL _ SWAP_TOTAL_KIB SWAP_USADO_KIB _ < <(awk 'NR==2' /proc/swaps)
  if ((SWAP_TOTAL_KIB >= RAM_KIB)); then
    ok "swap nuevo: $(kib_a_gib_techo "${SWAP_TOTAL_KIB}") GiB, alcanza para hibernar"
  else
    error "el swap sigue por debajo de la RAM después del resize"
    return 1
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Fase 4: suspend-then-hibernate (opcional)
# ---------------------------------------------------------------------------
fase_sleep_conf() {
  cabecera "4/5 suspend-then-hibernate (opcional)"

  if grep -qE '^\s*HibernateDelaySec=' /etc/systemd/sleep.conf 2>/dev/null; then
    ok "/etc/systemd/sleep.conf ya define HibernateDelaySec"
    return 0
  fi
  info "sin esto, 'systemctl suspend-then-hibernate' usa el default (2 h)."
  if [[ "${MODE}" != "apply" ]]; then
    info "(check) se preguntaría: ¿fijar HibernateDelaySec=30min en /etc/systemd/sleep.conf?"
    return 0
  fi
  if ! confirm "¿Fijar HibernateDelaySec=30min en /etc/systemd/sleep.conf?"; then
    warn "omitido por decisión del usuario"
    return 0
  fi
  as_root cp -a /etc/systemd/sleep.conf "/etc/systemd/sleep.conf${BACKUP_SUFFIX}" 2>/dev/null || true
  printf '\n[Sleep]\nHibernateDelaySec=30min\n' | as_root tee -a /etc/systemd/sleep.conf >/dev/null
  verificar "sleep.conf define HibernateDelaySec" grep -qE '^\s*HibernateDelaySec=30min' /etc/systemd/sleep.conf || return 1
  return 0
}

# ---------------------------------------------------------------------------
# Fase 5: verificación en vivo
# ---------------------------------------------------------------------------
fase_verificacion() {
  cabecera "5/5 Verificación en vivo"
  local fallos=0

  if [[ "$(cat /proc/cmdline)" == *"resume="* ]]; then
    ok "cmdline trae resume= (ya aplicado)"
  else
    warn "el cmdline NO trae resume= todavía: hace falta reiniciar"
    fallos=$((fallos + 1))
  fi

  if [[ "$(cat /sys/power/resume)" != "0:0" ]]; then
    ok "/sys/power/resume = $(cat /sys/power/resume)"
  else
    warn "/sys/power/resume = 0:0: el kernel no sabe de dónde restaurar"
    fallos=$((fallos + 1))
  fi

  if ((SWAP_TOTAL_KIB >= RAM_KIB)); then
    ok "swap ($(kib_a_gib_techo "${SWAP_TOTAL_KIB}") GiB) >= RAM ($(kib_a_gib_techo "${RAM_KIB}") GiB)"
  else
    warn "swap ($(kib_a_gib_techo "${SWAP_TOTAL_KIB}") GiB) < RAM ($(kib_a_gib_techo "${RAM_KIB}") GiB)"
    fallos=$((fallos + 1))
  fi

  echo
  if ((fallos == 0)); then
    ok "todo listo. Probá: sudo systemctl hibernate"
    info "Después del resume, revisá: journalctl -b | grep -i hibernat"
  else
    warn "${fallos} requisito(s) sin cumplir. Ver docs/referencia/hibernacion-opensuse-lvm.md"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# Principal
# ---------------------------------------------------------------------------
case "${MODE}" in
  verify)
    fase_estado
    fase_verificacion
    ;;
  check)
    fase_estado
    fase_resume_param
    fase_swap
    fase_sleep_conf
    fase_verificacion
    echo
    info "Modo check: no se cambió nada. Para aplicar paso por paso: $0 --apply"
    ;;
  apply)
    fase_estado
    fase_resume_param
    fase_swap
    fase_sleep_conf
    fase_verificacion
    echo
    info "Si se aplicó algo, reiniciá y volvé a correr: $0 --verify"
    ;;
esac
