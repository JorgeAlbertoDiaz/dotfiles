#!/usr/bin/env bash
# Spec ejecutable de la paleta rust-light (odd/tasks/rust-light.md).
#
# Verifica S1-S7 sobre los archivos de tema CLARO del repo:
#   S2  todo color usado en el tema claro es una variable del tema rust de mdBook
#       (y los hsl() del CSS de referencia son los hex que usa el escritorio).
#   S3  el texto de herdr supera contraste AA (>= 4.5:1) contra el fondo que usa,
#       incluido el sidebar: es el bug que reportó el humano.
#   S4  los paneles son más oscuros que el documento (--bg) y su texto se lee.
#   S5  la barra de waybar y el centro de notificaciones usan --sidebar-bg.
#   S6  el texto de las superficies oscuras es --sidebar-fg, nunca blanco.
#   S7  cada componente que entra en el toggle tiene los dos temas completos, y
#       no quedan colores de la paleta anterior.
#
# No toca el sistema: lee los archivos del repo y hace la matemática de
# luminancia relativa WCAG 2.1 con awk. Sale 1 si algún paso falla.
set -uo pipefail

SPEC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$(dirname "${SPEC_DIR}")")"

pasos=0
fallos=0

pasa() { pasos=$((pasos + 1)); printf 'PASS  %s\n' "$1"; }
falla() { pasos=$((pasos + 1)); fallos=$((fallos + 1)); printf 'FAIL  %s\n' "$1"; }

# --- Paleta ---------------------------------------------------------------
# Roles estables del tema rust claro. Sólo estos hex pueden aparecer en los
# archivos de tema claro; el resto de las variables del CSS de mdBook son de
# búsqueda/blockquote y no tienen componente en el escritorio.
PALETA=" E1E1DB 262625 3B2E2A C8C9DB 505254 E69F67 45373A B38F6B 99908A C2C2BC
 B6B6AF FF8E00 D5D5CD B3A497 DADAD3 2B79A2 6E6B5E DEC2A2 D3A17A AA1721 8C391F
 737480 023B95 007700 8250DF 603700 "
# A una sola línea: las comparaciones de abajo buscan " HEX " con espacios.
PALETA=" $(echo ${PALETA}) "

# Paleta anterior del tema claro: si reaparece, alguien volvió a #pedir blanco.
VIEJOS=" D9D9D3 C1C1BB B4B4AC B7410E A6402A 7A5666 "

# --- Utilidades de extracción --------------------------------------------
# Hex con # de un archivo, normalizados a mayúsculas.
hexs() { grep -oiE '#[0-9a-f]{6}' "$1" 2>/dev/null | tr 'a-f' 'A-F' | sort -u; }

# rgb()/rgba() de un CSS convertidos a hex (swaync los usa por componentes).
rgbs() {
	awk '
		function hex2(n) { return sprintf("%02X", n) }
		{
			linea = tolower($0)
			while (match(linea, /rgba?\([[:space:]]*[0-9]+[[:space:]]*,[[:space:]]*[0-9]+[[:space:]]*,[[:space:]]*[0-9]+/)) {
				trozo = substr(linea, RSTART, RLENGTH)
				linea = substr(linea, RSTART + RLENGTH)
				gsub(/[^0-9,]/, "", trozo)
				split(trozo, p, ",")
				print hex2(p[1]) hex2(p[2]) hex2(p[3])
			}
		}' "$1" 2>/dev/null | sort -u
}

# Colores de wob: <rrggbb[aa]> SIN '#'. Se descarta el alfa.
wob_hexs() {
	grep -oE '\b[0-9A-Fa-f]{8}\b' "$1" 2>/dev/null | cut -c1-6 | tr 'a-f' 'A-F' | sort -u
}

# Propiedad de un bloque CSS. $1 archivo, $2 texto con el que EMPIEZA la línea
# del selector (comparación literal), $3 propiedad.
css_campo() {
	awk -v sel="$2" -v prop="$3" '
		dentro == 0 { if (index($0, sel) == 1) { dentro = 1; next } else next }
		/}/ { dentro = 0; next }
		tolower($0) ~ "^[[:space:]]*" prop ":" {
			sub(/^[^:]*:[[:space:]]*/, ""); sub(/;.*/, ""); gsub(/[[:space:]]/, ""); print; exit
		}' "$1" 2>/dev/null
}

# Clave de un .toml: $1 archivo, $2 clave. Devuelve el valor sin comillas.
toml_campo() {
	awk -v k="$2" '
		$0 ~ "^[[:space:]]*" k "[[:space:]]*=" {
			sub(/^[^=]*=[[:space:]]*/, ""); gsub(/["[:space:]]/, ""); print; exit
		}' "$1" 2>/dev/null
}

# Tokens de un $color-client-* de sway: imprime "<background> <text>".
sway_cliente() {
	awk -v k="$2" '
		$1 == "set" && $2 == k { print $4, $5; exit }' "$1" 2>/dev/null
}

# Valor de una clave ini/swaylock: $1 archivo, $2 clave (devuelve 6 dígitos).
ini_campo() {
	awk -v k="$2" -F= '
		{ clave = $1; gsub(/[[:space:]]/, "", clave) }
		clave == k && NF >= 2 { v = $2; gsub(/[[:space:]]/, "", v); print substr(v, 1, 6); exit }' "$1" 2>/dev/null
}

# --- Matemática de contraste (WCAG 2.1) ----------------------------------
# contraste <fg> <bg> imprime el ratio con dos decimales.
contraste() {
	local fg="${1#\#}" bg="${2#\#}"
	awk -v fr=$((16#${fg:0:2})) -v fgc=$((16#${fg:2:2})) -v fb=$((16#${fg:4:2})) \
		-v br=$((16#${bg:0:2})) -v bgc=$((16#${bg:2:2})) -v bb=$((16#${bg:4:2})) '
		function lin(c) { c = c / 255; return (c <= 0.03928) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
		function lum(r, g, b) { return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) }
		BEGIN {
			lf = lum(fr, fgc, fb); lb = lum(br, bgc, bb)
			hi = (lf > lb) ? lf : lb; lo = (lf > lb) ? lb : lf
			printf "%.2f", (hi + 0.05) / (lo + 0.05)
		}'
}

# ge <a> <b>: cierto cuando a >= b (comparación numérica en awk).
ge() { awk -v a="$1" -v b="$2" 'BEGIN { exit !(a >= b) }'; }

# Luminancia relativa 0-1 de un hex.
lum() {
	local h="${1#\#}"
	awk -v r=$((16#${h:0:2})) -v g=$((16#${h:2:2})) -v b=$((16#${h:4:2})) '
		function lin(c) { c = c / 255; return (c <= 0.03928) ? c / 12.92 : ((c + 0.055) / 1.055) ^ 2.4 }
		BEGIN { printf "%.4f", 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b) }'
}

# assert_contraste <fg> <bg> <mínimo> <descripción>
assert_contraste() {
	local r; r="$(contraste "$1" "$2")"
	if ge "${r}" "$3"; then
		pasa "$4 (${1} sobre ${2} = ${r}:1)"
	else
		falla "$4 (${1} sobre ${2} = ${r}:1, mínimo ${3}:1)"
	fi
}

# assert_en_paleta <archivo> <hexs ya extraídos, uno por línea>
assert_en_paleta() {
	local archivo="$1" hex malos="" h
	while read -r h; do
		[[ -n "${h}" ]] || continue
		h="${h#\#}"
		[[ "${PALETA}" == *" ${h} "* ]] || malos="${malos} #${h}"
	done < <(hexs "${archivo}")
	while read -r h; do
		[[ -n "${h}" ]] || continue
		[[ "${PALETA}" == *" ${h} "* ]] || malos="${malos} ${h}(rgba)"
	done < <(rgbs "${archivo}")
	if [[ -z "${malos}" ]]; then
		pasa "todos los colores de ${archivo#"${REPO_ROOT}"/} son variables del tema rust"
	else
		falla "colores fuera de la paleta rust en ${archivo#"${REPO_ROOT}"/}:${malos}"
	fi
}

# --- Rutas ---------------------------------------------------------------
SWAY_LC="${REPO_ROOT}/config/sway/themes/light.conf"
WAYBAR="${REPO_ROOT}/config/waybar/themes/light.css"
SWAYNC="${REPO_ROOT}/config/swaync/themes/light.css"
WOFI="${REPO_ROOT}/config/wofi/themes/light.css"
WOB="${REPO_ROOT}/config/wob/themes/light.ini"
SWAYLOCK="${REPO_ROOT}/config/swaylock/themes/light.conf"
FOOT="${REPO_ROOT}/config/foot/foot.ini"
HEDR_LC="${REPO_ROOT}/config/herdr/themes/light.toml"
TMUX_LC="${REPO_ROOT}/config/tmux/themes/light.conf"

for f in "${SWAY_LC}" "${WAYBAR}" "${SWAYNC}" "${WOFI}" "${WOB}" "${SWAYLOCK}" \
	"${FOOT}" "${HEDR_LC}" "${TMUX_LC}"; do
	if [[ ! -f "${f}" ]]; then
		echo "ERROR: falta ${f}" >&2
		exit 2
	fi
done

# ---------------------------------------------------------------------------
# S2/S7 — cada color del tema claro es una variable del tema rust.
#
# foot queda afuera: su bloque ANSI son 16 colores derivados (el CSS de mdBook
# define 5), y el spec los valida abajo contra --bg/--fg y el contraste.
# ---------------------------------------------------------------------------
for f in "${SWAY_LC}" "${WAYBAR}" "${SWAYNC}" "${WOFI}" "${SWAYLOCK}" "${HEDR_LC}" "${TMUX_LC}"; do
	assert_en_paleta "${f}"
done

malos_wob=""
for h in $(wob_hexs "${WOB}"); do
	[[ "${PALETA}" == *" ${h} "* ]] || malos_wob="${malos_wob} ${h}"
done
if [[ -z "${malos_wob}" ]]; then
	pasa "todos los colores de wob/themes/light.ini son variables del tema rust"
else
	falla "colores fuera de la paleta rust en wob/themes/light.ini:${malos_wob}"
fi

# Los hsl() del CSS de referencia se materializan en estos hex (no son un
# requisito nuevo: es el mismo color escrito de otra forma).
for par in "60,9%,87%:E1E1DB" "60,5%,75%:C2C2BC" "60,5%,70%:B6B6AF" \
	"60,9%,82%:D5D5CD" "60,9%,84%:DADAD3"; do
	hsl="${par%%:*}" hex="${par##*:}"
	encontrado=0
	for f in "${SWAY_LC}" "${WAYBAR}" "${SWAYNC}" "${WOFI}" "${WOB}" "${SWAYLOCK}" "${HEDR_LC}" "${TMUX_LC}"; do
		if grep -qi "\#${hex,,}" "${f}" 2>/dev/null; then encontrado=1; break; fi
	done
	if [[ "${encontrado}" -eq 1 ]]; then
		pasa "hsl(${hsl}) está materializado como #${hex} en el tema claro"
	else
		falla "hsl(${hsl}) del CSS de rust no aparece como #${hex} en el tema claro"
	fi
done

# ---------------------------------------------------------------------------
# S7 — no quedan colores de la paleta anterior en el tema claro.
# ---------------------------------------------------------------------------
sobras=""
for v in ${VIEJOS}; do
	for f in "${SWAY_LC}" "${WAYBAR}" "${SWAYNC}" "${WOFI}" "${WOB}" "${SWAYLOCK}" "${FOOT}" "${HEDR_LC}" "${TMUX_LC}"; do
		if grep -qiF "#${v,,}" "${f}" 2>/dev/null || grep -qiE "\b${v,,}" "${f}" 2>/dev/null; then
			sobras="${sobras} ${v}@$(basename "${f}")"
		fi
	done
done
if [[ -z "${sobras}" ]]; then
	pasa "el tema claro no conserva colores de la paleta anterior"
else
	falla "colores de la paleta anterior en el tema claro:${sobras}"
fi

# ---------------------------------------------------------------------------
# S5 — barra y notificaciones con --sidebar-bg (#3B2E2A).
# ---------------------------------------------------------------------------
assert_igual() {
	if [[ "$1" == "$2" ]]; then pasa "$3"; else falla "$3 (real: '$1', esperado: '$2')"; fi
}

barra_bg="$(css_campo "${WAYBAR}" "window#waybar" "background-color")"
barra_fg="$(css_campo "${WAYBAR}" "window#waybar" "color")"
assert_igual "${barra_bg,,}" "#3b2e2a" "la barra de waybar usa --sidebar-bg"
assert_igual "${barra_fg,,}" "#c8c9db" "el texto de la barra usa --sidebar-fg"

cc_bg="$(css_campo "${SWAYNC}" ":root" "--cc-bg")"
if [[ "${cc_bg}" == "rgba(59,46,42"* ]]; then
	pasa "el centro de notificaciones usa --sidebar-bg (${cc_bg})"
else
	falla "el centro de notificaciones no usa --sidebar-bg (real: '${cc_bg}')"
fi
nc_fg="$(css_campo "${SWAYNC}" ":root" "--text-color")"
assert_igual "${nc_fg,,}" "#c8c9db" "el texto de notificaciones usa --sidebar-fg"

# ---------------------------------------------------------------------------
# S6 — nada de blanco puro: el texto de las superficies oscuras es --sidebar-fg
# o --sidebar-spacer, nunca #FFFFFF.
# ---------------------------------------------------------------------------
blancos=""
for f in "${WAYBAR}" "${SWAYNC}" "${WOFI}" "${WOB}" "${SWAYLOCK}" "${HEDR_LC}" "${TMUX_LC}"; do
	if grep -qiE '#ffffff' "${f}" 2>/dev/null; then blancos="${blancos} $(basename "${f}")"; fi
done
if [[ -z "${blancos}" ]]; then
	pasa "ninguna superficie oscura usa blanco puro"
else
	falla "blanco puro en:${blancos}"
fi

# ---------------------------------------------------------------------------
# S4 — los paneles son más oscuros que el documento (--bg #E1E1DB) y el
# sidebar de herdr deja de compartir fondo con el terminal.
# ---------------------------------------------------------------------------
l_doc="$(lum "#E1E1DB")"
for panel in 45373A C2C2BC B3A497 3B2E2A; do
	l="$(lum "#${panel}")"
	if awk -v p="${l}" -v d="${l_doc}" 'BEGIN { exit !(p < d) }'; then
		pasa "el panel #${panel} es más oscuro que el documento #E1E1DB (${l} < ${l_doc})"
	else
		falla "el panel #${panel} no es más oscuro que el documento #E1E1DB (${l} >= ${l_doc})"
	fi
done

herdr_sidebar="$(toml_campo "${HEDR_LC}" "sidebar_bg")"
herdr_text="$(toml_campo "${HEDR_LC}" "text")"
herdr_sub="$(toml_campo "${HEDR_LC}" "subtext0")"
if [[ -n "${herdr_sidebar}" ]]; then
	pasa "herdr fija sidebar_bg (${herdr_sidebar}): el sidebar no hereda el fondo del terminal"
else
	falla "herdr no fija sidebar_bg: el sidebar hereda el fondo del terminal"
fi

# ---------------------------------------------------------------------------
# S3 — todo texto se lee (>= 4.5:1) sobre el fondo en el que se dibuja, y los
# elementos gráficos (bordes, barras) llegan a 3:1.
# ---------------------------------------------------------------------------
chip_bg="$(css_campo "${WAYBAR}" "#workspaces, #mode" "background-color")"
assert_contraste "${barra_fg}" "${barra_bg}" 4.5 "texto de la barra de waybar"
assert_contraste "${barra_fg}" "${chip_bg}" 4.5 "texto de los chips de waybar"

ws_inactivo="$(css_campo "${WAYBAR}" "#workspaces button" "color")"
assert_contraste "${ws_inactivo}" "${barra_bg}" 4.5 "workspace inactivo de waybar"

ws_activo_bg="$(css_campo "${WAYBAR}" "#workspaces button.focused" "background-color")"
ws_activo_fg="$(css_campo "${WAYBAR}" "#workspaces button.focused" "color")"
assert_contraste "${ws_activo_fg}" "${ws_activo_bg}" 4.5 "workspace activo de waybar"

assert_contraste "${nc_fg}" "#3b2e2a" 4.5 "texto de notificaciones sobre el panel"

wofi_bg="$(css_campo "${WOFI}" "window" "background-color")"
wofi_fg="$(css_campo "${WOFI}" "window" "color")"
wofi_input_bg="$(css_campo "${WOFI}" "#input" "background-color")"
wofi_input_fg="$(css_campo "${WOFI}" "#input" "color")"
wofi_sel_bg="$(css_campo "${WOFI}" "#entry:selected" "background-color")"
wofi_sel_fg="$(css_campo "${WOFI}" "#entry:selected" "color")"
assert_contraste "${wofi_fg}" "${wofi_bg}" 4.5 "texto del launcher"
assert_contraste "${wofi_input_fg}" "${wofi_input_bg}" 4.5 "texto del input del launcher"
assert_contraste "${wofi_sel_fg}" "${wofi_sel_bg}" 4.5 "entrada seleccionada del launcher"

read -r sway_foco_bg sway_foco_fg <<<"$(sway_cliente "${SWAY_LC}" '$color-client-focused')"
read -r sway_libre_bg sway_libre_fg <<<"$(sway_cliente "${SWAY_LC}" '$color-client-unfocused')"
assert_contraste "${sway_foco_fg}" "${sway_foco_bg}" 4.5 "título de la ventana enfocada"
assert_contraste "${sway_libre_fg}" "${sway_libre_bg}" 4.5 "título de la ventana sin foco"

lock_bg="$(ini_campo "${SWAYLOCK}" "inside-color")"
lock_fg="$(ini_campo "${SWAYLOCK}" "text-color")"
assert_contraste "#${lock_fg}" "#${lock_bg}" 4.5 "texto de swaylock"

assert_contraste "${herdr_text}" "${herdr_sidebar}" 4.5 "texto de herdr sobre el sidebar"
assert_contraste "${herdr_sub}" "${herdr_sidebar}" 4.5 "texto secundario de herdr sobre el sidebar"

tmux_estilo="$(grep -m1 '^set -g status-style' "${TMUX_LC}")"
tmux_bg="$(grep -oE 'bg=#[0-9a-fA-F]{6}' <<<"${tmux_estilo}" | cut -d= -f2)"
tmux_fg="$(grep -oE 'fg=#[0-9a-fA-F]{6}' <<<"${tmux_estilo}" | cut -d= -f2)"
assert_contraste "${tmux_fg}" "${tmux_bg}" 4.5 "barra de estado de tmux"

wob_barra="$(ini_campo "${WOB}" "bar_color")"
wob_fondo="$(ini_campo "${WOB}" "background_color")"
assert_contraste "#${wob_barra}" "#${wob_fondo}" 3.0 "barra del OSD sobre su fondo"

# ---------------------------------------------------------------------------
# S7 — foot: el documento coincide con --bg/--fg y su selección se lee.
# ---------------------------------------------------------------------------
foot_bg="$(awk '/^\[colors-light\]/{d=1;next} /^\[/{d=0} d && /^background=/{print substr($0,12)}' "${FOOT}")"
foot_fg="$(awk '/^\[colors-light\]/{d=1;next} /^\[/{d=0} d && /^foreground=/{print substr($0,12)}' "${FOOT}")"
assert_igual "#${foot_bg,,}" "#e1e1db" "el fondo de foot claro es --bg"
assert_igual "#${foot_fg,,}" "#262625" "el texto de foot claro es --fg"

foot_sel_bg="$(awk '/^\[colors-light\]/{d=1;next} /^\[/{d=0} d && /^selection-background=/{print substr($0,22)}' "${FOOT}")"
assert_contraste "#${foot_fg}" "#${foot_sel_bg}" 4.5 "texto seleccionado en foot claro"

# ---------------------------------------------------------------------------
# S7 — cada componente del toggle tiene los dos temas completos.
# ---------------------------------------------------------------------------
for app in waybar swaync wofi wob swaylock herdr tmux; do
	dir="${REPO_ROOT}/config/${app}/themes"
	claro="$(find "${dir}" -maxdepth 1 -name 'light.*' -print -quit 2>/dev/null)"
	oscuro="$(find "${dir}" -maxdepth 1 -name 'dark.*' -print -quit 2>/dev/null)"
	if [[ -n "${claro}" && -n "${oscuro}" ]]; then
		pasa "${app} tiene light.* y dark.* para el toggle"
	else
		falla "${app} no tiene los dos temas (claro: '${claro}', oscuro: '${oscuro}')"
	fi
done

# ---------------------------------------------------------------------------
# Resumen.
# ---------------------------------------------------------------------------
printf '\n%s pasos, %s fallos\n' "${pasos}" "${fallos}"
[[ "${fallos}" -eq 0 ]] || exit 1
