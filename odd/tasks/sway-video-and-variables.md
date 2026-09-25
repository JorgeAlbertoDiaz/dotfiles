# Sway: cablear grabador de video + centralizar variables

## Objetivo
1. CABLEAR `swpy-recorder.sh`: moverlo al repositorio y darle bindings reales de toggle.
2. UNIFICAR variables: que `features/variables-colors.conf` sea el único origen de verdad.

**Ambos cumplidos.** Estado final verificado en la sesión viva.

## Problema
- `swpy-recorder.sh` existía solo en `/home/jorge/.config/sway/scripts/` (fuera del repo,
  se perdía en el próximo deploy) y **cero configs lo referenciaban**: feature muerto.
- El script original NO tenía semántica de toggle: `wf-recorder` corría en foreground y
  bloqueaba; no había forma de detener la grabación.
- `features/variables-colors.conf` estaba commiteado pero **no lo incluía nadie**
  (`config/sway/config:27` incluía `features/variables.conf`). 19 de sus 22 nombres
  estaban muertos.
- Duplicaban 6 variables con `variables.conf` con **valores idénticos** (sin divergencia).
- `sway-font.sh` resolvia el config ROOT, pero la línea `font pango:` vive en
  `features/appearance.conf`. Ambos greps fallaban y el script appendeaba un override
  al final del root: funcionaba por accidente y creaba una segunda fuente de verdad.

## Por qué
El usuario: "cambiamos varias combinaciones y al final cuando pensé que lo habíamos
resuelto volvimos al inicio". La causa estructural es que el estado real vivía
disperso: `variables.conf` + `appearance.conf` hardcodeado + un `variables-colors.conf`
inerte + un script de fuente apuntando al archivo equivocado. Centralizar es lo
correcto; el orden de migración era la decisión.

## Alcance autorizado (y ejecutado)
- `config/sway/scripts/swpy-recorder.sh` (nuevo en repo, 755)
- `config/sway/keybindings/media.conf` (2 bindings top-level)
- `config/sway/config` (incluir variables-colors)
- `config/sway/features/appearance.conf` (migración no-op a variables + comentario)
- `config/sway/features/variables.conf` (borrado, absorbido)
- `config/sway/scripts/sway-font.sh` (resolución + escaping)
- `docs/organizacion-sway.md`, `docs/diagramas/flujo-datos-sway.mmd` (diagramas)
- NO tocar `install.sh` ni `system.conf`

## Restricciones (verificadas empíricamente)
- Guiones en nombres de variable Sway SÍ son válidos: `sway -C` con `set $font-family`
  → exit 0. Control negativo (`this_is_not_a_real_command` → exit 1).
- **Sway NO hace word-split de una variable entrecomillada.** `set $c "#a #b #c"` +
  `client.focused $c` → `Invalid client.focused command (expected at least 3
  arguments, got 1)`, exit 1. Sin comillas expande bien. Las tres líneas
  `set $color-client-*` van SIN comillas **a propósito**.
- Convención de scripts: `exec ~/.config/sway/scripts/<kebab-case>.sh` + args posicionales.
- Toggle = bindsym top-level pelado, NO un mode. Precedente: `media.conf:17`.
- Trampa de casing: Sway normaliza `Shift+v` == `Shift+V`. Usar una sola variante.
- En `sed`, un replacement interpreta `&` como "el texto matcheado". Escapar `\` primero,
  luego `&`, luego el delimitador, en ese orden.

## Checklist

### T1 — Cablear el grabador — HECHO (`7dc2dd6`)
- [x] T1.1 `swpy-recorder.sh` en el repo, 755 — 131 líneas
- [x] T1.2 Toggle: `swpy-recorder.sh [full|area]`
- [x] T1.3 PID file + `kill -0` + check `/proc/PID/comm` (protege PID reciclado)
- [x] T1.4 `wf-recorder` en background
- [x] T1.5 Destino con `xdg-user-dir PICTURES` + fallback escalonado
- [x] T1.6 `set -euo pipefail`; sin `jq`; sin modo `window`

### T2 — Bindings — HECHO (`7dc2dd6`)
- [x] T2.1 `media.conf:22` `$mod+Shift+v` → full
- [x] T2.2 `media.conf:23` `$mod+Shift+a` → area
- [x] T2.3 Ambas LIBRES, 0 duplicados
- [x] T2.4 `bindsym` 104 → 106

### T3 — Variables — HECHO (`4ccd806`), opción A
- [x] T3.0 DECISIÓN DEL USUARIO: **opción A, siembra no-op**
- [x] T3.1 6 nombres de `variables.conf` absorbidos; `$term`→`$terminal`, `$menu`→`$launcher`
- [x] T3.2 Header corregido (documentaba 5 nombres fantasma)
- [x] T3.3 Typo `formati:` corregido
- [x] T3.4 `$mode-resize`/`$mode-launcher`/`$mode-screenshot` y `$screenshot_dir` fuera
- [x] T3.5 Un solo `include features/variables-colors.conf` en `config:27`
- [x] T3.6 **No-op probado token a token: 11 de 11 colores idénticos a HEAD**
- [x] T3.7 Paleta sembrada desde los hex live, agregando `$color-teal` / `$color-teal-light`
      (`#00a489` / `#35b9ab`), que los colores live usaban y la paleta no definía

### T4 — `sway-font.sh` — HECHO (`2cddd80`)
- [x] T4.1 Resuelve el archivo dueño de la línea `font pango:` caminando los includes
- [x] T4.2 Edita variables si la línea delega; reescribe in-place si es literal
- [x] T4.3 Nunca appendea al root; falla en voz alta si falta o es ambigua
- [x] T4.4 `escapar_sed()` — sin esto `R&D Mono` corrompía la config en silencio
- [x] T4.5 `tamano_actual()` consistente (antes devolvía vacío → tamaño siempre 10)
- [x] T4.6 Comentario obsoleto de `appearance.conf:4` corregido

### T5 — Grabador: selección de output — HECHO (`8255601`)
- [x] T5.1 `-o <salida>` explícito (2 monitores activos; pedía stdin y moría)
- [x] T5.2 `full` usa la salida enfocada
- [x] T5.3 `area` deriva la salida del `rect` de la selección, NO del foco
- [x] T5.4 `-g-` (sintaxis de grim) → `-g "x,y WxH"`, con validación
- [x] T5.5 Contenedor `.mkv` (utvideo rechaza MP4 → archivo de 0 bytes)
- [x] T5.6 Sin salida activa → error claro, exit 1, sin pidfile

## Criterios de aceptación — todos cumplidos
- El repo contiene el script, ejecutable, y 2 bindings que lo invocan
- Ningún path de script referenciado existe solo en el runtime
- `sway -C -c config/sway/config` → exit 0
- `grep -rh bindsym config/sway | wc -l` → 106
- 0 duplicados en ámbito default
- Grabación real producida end-to-end desde la versión desplegada

## Checks aplicables
```bash
bash -n config/sway/scripts/swpy-recorder.sh
sway -C -c config/sway/config          # exit 0 esperado
grep -rh bindsym config/sway | wc -l   # 106 esperado
grep -rn "swpy-recorder" config/sway   # 2 refs esperadas
```
`shellcheck` NO disponible en esta máquina.
`jq` SÍ está instalado (1.8.2) — una premisa del brief era falsa.

## Decisión resuelta (ya no bloquea)
Migrar `appearance.conf` a `$color-client-*` era la decisión pendiente. El usuario
eligió **opción A: siembra no-op**, poblando el módulo de variables con los hex live.
Resultado: la abstracción arranca desde la verdad y la adopción es indolora. Prueba:
expansión de las 11 tokens idéntica a HEAD, calculada de forma independiente por el
padre, no por el worker.

## Ruta por tarea
| Tarea | Ruta | Trigger |
|---|---|---|
| T1 | delegada (writer) | 2+ archivos no triviales |
| T2 | delegada (writer) | mismo writer, mismo work-unit |
| T3 | delegada (writer) | 10 archivos |
| T4 | delegada (writer) | mismo archivo, cambio de contrato |
| T5 | delegada (writer) | mismo archivo, bug de ejecución |

## Entrega
- Feature branch: `feature/fix/install-sh-selection-nvidia`
- 4 work-unit commits: `7dc2dd6`, `4ccd806`, `2cddd80`, `8255601`
- 400 líneas de presupuesto: 1 PR, sin chaining

## Progreso — TODO CERRADO
- [x] Auditoría de bindings (`temps/keybindings.md`, regenerado a 962 líneas)
- [x] Mapa de variables (97 bindings, 19 nombres muertos)
- [x] Verificación empírica del parser (`sway -C` + control negativo)
- [x] T1 + T2 → `7dc2dd6`
- [x] T3 → `4ccd806`
- [x] T4 → `2cddd80`
- [x] T5 → `8255601`
- [x] Despliegue a la sesión viva + `swaymsg reload` OK

## Evidencia de verificación (padre, readback + spot check)
| Check | Resultado |
|---|---|
| `bash -n swpy-recorder.sh` | exit 0 |
| `sway -C -c config/sway/config` | exit 0 (solo ruido pre-existente de Nvidia) |
| `grep -rh bindsym \| wc -l` | 106 |
| No-op de color (independiente del worker) | 11/11 tokens idénticos a HEAD |
| A/B de variable con/sin comillas | exit 1 vs exit 0 — confirma el word-split |
| `sway-font.sh` con familia hostil `R&D\|Mono\X` | línea exacta, root 72→72 bytes, `appearance.conf` byte-idéntico |
| Grabación `full` end-to-end (desplegada) | 8,6 MB Matroska, pidfile `comm=wf-recorder`, toggle OK |
| MP4 vs MKV | MP4 → 0 bytes; MKV → válido |
| PID reciclado (`comm=sleep`) | ignorado correctamente |
| `swaymsg` caído / sin salida / JSON inválido | error claro, sin pidfile |

## Blocker de entorno — RESUELTO
`wf-recorder` fallaba con `symbol lookup error: /lib64/libavformat.so.62: undefined
symbol: rist_peer_config_defaults_set_versioned`. Era un desajuste de empaquetado de
Tumbleweed: `libavformat62-8.1.2-5.1` llama una API de librist 0.4+ pero el sistema
tenía `librist4-0.2.11`, y `libavformat` no declara `librist` en NEEDED. Las seis libs
de FFmpeg eran del mismo build, así que no era un upgrade parcial.
Dos hipótesis fallidas que NO reintentar: "el símbolo existe" (era `U`, undefined, no
`T`) y "LD_PRELOAD de librist" (librist no lo exporta).
**Resuelto con `sudo zypper refresh && sudo zypper update`.**

## Lecciones de proceso
- **Transcribir tokens del provider a mano los corrompe.** Escribí un `--target-evidence`
  a mano y falló (`base_tree is not a Git tree hash`). Los tokens se extraen
  programáticamente del JSON, nunca se retypen.
- **Un binario que no arranca esconde los bugs de atrás.** El desajuste de librist
  enmascaraba la falta de `-o`, el `.mp4` inválido y el `-g-` mal formada. `wf-recorder
  --version` tampoco era prueba: el símbolo resuelve al arrancar y el bug siguiente
  aparece al grabar. Sólo el end-to-end prueba.
- **`--version` no es un smoke test.** Verificar el camino real de ejecución.
- **Los workers corrigieron al padre tres veces**: el spec de comillas (error de parseo),
  la premisa de `sway-font.sh` (nunca tocaba `appearance.conf`) y el default de "output
  enfocado" para `area` (el foco sigue a la ventana, no al puntero). En los tres casos
  reportaron la contradicción con evidencia en vez de cumplir la spec, y en los tres
  tenían razón. Cuando un worker se opone al brief, hay que verificar antes de insistir.
- **`jq` SÍ estaba instalado.** No asumir ausencia de herramientas; verificar.
- `cp -r` en `aplicar_app()` no borra archivos obsoletos del destino: el despliegue de
  sway necesita el path de reset.

## Deuda conocida / notas
- `utvideo` es lossless: **7–25 MB/s a 1080p**, un clip de 60s pasa de 1 GB. Es el default
  de openSUSE y este ffmpeg no trae x264 ni ningún encoder chico. Archivos compactos
  requieren un ffmpeg nuevo; no se agregó esa dependencia.
- `screenshots.conf` usa `grim` pelado y escribe en el cwd. No se unificó con el destino
  del grabador: fuera de alcance.
- `screenshot-menu.sh` y `sway-layout-menu.sh` NO existen en el repo, pero **nada en
  `config/sway` los referencia**. Requisito muerto, no pendiente.
- `shellcheck` no instalado; los scripts se validan con `bash -n` + pruebas en sandbox.
- Se generaron 217 MB de grabaciones de prueba; borradas. 0 archivos, 0 procesos.

## Review (RDD on)
Dos candidatos, ambos `high` (scripts 755, shell, process boundary), ambos **declined**
por el usuario. Alcance: sólo cada candidato. Sin registro de review. El switch sigue on.
- `7dc2dd6` → lineage `review-e4e9914f0efad2a6`, declined
- `4ccd806` → lineage `review-f34d6819626e9054`, declined

**Próximo paso: ninguno.** La feature está completa y verificada en la sesión viva.
