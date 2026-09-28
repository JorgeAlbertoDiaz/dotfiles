# zsh nativo: configuración declarativa + instalador de plugins

## Objetivo
1. REESCRIBIR `config/home/.zshrc` como zsh **nativo** (sin Oh My Zsh) con
   historial compartido, compinit cacheado, búsqueda por flechas y fzf.
2. CREAR `scripts/08-setup-zsh.sh` — instalador idempotente de los dos plugins
   opcionales (`zsh-autosuggestions`, `zsh-syntax-highlighting`).
3. DECLARAR `fzf` en `packages/shell.txt` (hoy es una dependencia accidental).
4. EXPONER el paso como componente "Zsh (plugins)" en el menú de `install.sh`.

## Problema
- El `.zshrc` del repo tiene 22 líneas y **no define `HISTFILE`**. Sin él zsh usa
  `~/.zsh_history` con `HISTSIZE=30` / `SAVEHIST=30`: el historial real del
  usuario es de 30 líneas. Es un bug de producción, no una preferencia.
- `compinit` se corre en cada shell sin cache (`-d`), reconstruyendo `zcompdump`.
- **No hay separación entre configuración e instalación.** Todo vive en el
  `.zshrc`, que es la mitad declarativa del problema.
- `fzf` está instalado en la máquina pero **no figura en `packages/shell.txt`**:
  una máquina nueva que corre el repo queda sin `fzf`.
- La propuesta del usuario mezclaba dos configs incompatibles (zsh nativo **y**
  `source $ZSH/oh-my-zsh.sh`) y traía tres bugs verificados (ver abajo).

## Por qué
El usuario: "Quiero mejorar la configuración de .zshrc... estoy pensando en
separar toda la configuración e instalación de plugins de zsh en un .sh aparte
para instalarlo y configurarlo".

La intuición del `.sh` aparte es correcta, y por una razón que se verificó en el
código: **`scripts/04-setup-dotfiles.sh` no usa GNU stow, usa `cp -a`**
(línea 94 para `home/`). `~/.zshrc` es una **COPIA**, no un symlink: cualquier
edición local se pierde en silencio en la próxima corrida de 04. Separar la
instalación de la configuración es lo que permite que el `.zshrc` sea
declarativo y el `.sh` resuelva el estado mutable.

Sobre la base: se descartó Oh My Zsh a favor de zsh nativo (decisión del
usuario). Motivo: OMZ es estado **no trackeado** en `~/.oh-my-zsh` y el `.zshrc`
lo `source`a, así que una máquina que corra sólo `04-setup-dotfiles.sh` rompe el
shell. Eso contradice el propósito declarativo del repo. Además el ~90% de lo
pedido (historial, compinit, flechas, completion) es zsh nativo de todas formas.

## Tareas
- [x] T1 — Reescribir `config/home/.zshrc` → `efb21eb`
- [x] T2 — Crear `scripts/08-setup-zsh.sh` → `86e9466`
- [x] T3 — Agregar `fzf` a `packages/shell.txt` → `efb21eb`
- [x] T4 — Componente "Zsh (plugins)" en `install.sh` → `86e9466`
- [x] T5 — Actualizar `README.md` → `efb21eb` y `86e9466`
- [x] T6 — Verificación y cierre → este commit
- [x] T7 — `LS_COLORS` autosuficiente (`dircolors -b`) EN `.zshrc` → `e04c781`
- [x] T8 — `bashcompinit` para completions bash (zypper/wofi) → `e04c781`
- [x] T9 — Substring-search del historial en Ctrl+↑/↓ → `e04c781`
- [x] T10 — `ZSH_AUTOSUGGEST_STRATEGY=(history completion)` → `e04c781`
- [x] T11 — `WORDCHARS+=":@"` → `e04c781`
- [x] T12 — Recorte del completado de git (`compdef -d`) → `e04c781` (no-op verificado: ver abajo)
- [x] T13 — `04` simétrico: branch `home` honra `reset` y copia subdirectorios → `3c2609f`

## Work units y assessment RDD
RDD está `on` (decided by global). Los docs se commitearon junto a su cambio,
no en un commit aparte de "update docs".

| Commit | Unidad | `review assess` (base `main`) |
| --- | --- | --- |
| `efb21eb` | `.zshrc` + `shell.txt` + nota de copia | **medium** (`executable_change`) |
| `86e9466` | `08-setup-zsh.sh` + wiring en `install.sh` + docs | deferred (mismo slice) |
| `e04c781` | `.zshrc`: LS_COLORS, bashcompinit, substring, autosuggest, WORDCHARS, git trim | **high** (acumulado) |
| `3c2609f` | `04`: `home` simétrico (reset + subdirectorios) | high (acumulado) |

`medium` se difiere por protocolo: el candidato es el PR slice (los commits
acumulados desde el último boundary revisado), no el commit individual. El
STATUS preflight corre al cerrar la feature, con `--base-ref main`.

El assessment del slice acumulado (base `main`, `--committed-only`, 7 archivos,
609 líneas) da **high**: `executable_mode` en `08-setup-zsh.sh`, `process_boundary`
y `shell_source` en `install.sh`. El protocolo pediría correr el preflight STATUS
de inmediato, pero la review nativa NO puede ejecutarse en este plan
(ver "La review nativa no se completó" en Riesgos): el usuario ya decidió
enviar sin review nativa y ese lineage quedó documentado. Este cierre mantiene
esa decisión: se registra el tier, no se reabre el ciclo de consentimiento, la
entrega queda bajo política ordinaria del repo.

Presupuesto de entrega: 185 líneas autorales tras `efb21eb`, 329 tras `86e9466`.
Por debajo de las ~400 del presupuesto; no aplica `ask-on-risk`.


## Alcance autorizado
- REESCRITO `config/home/.zshrc`
- NUEVO `scripts/08-setup-zsh.sh` (755)
- EDITADO `packages/shell.txt`
- EDITADO `install.sh` (array `COMPONENTES` + `run_component()`)
- EDITADO `README.md` (árbol, componentes, `chmod`, notas)
- EDITADO este documento

Fuera de alcance (decidido NO tocar): `scripts/04-setup-dotfiles.sh`. Sus
opciones de menú y `DEPENDENCIAS_CONFIG` son de config de apps, no de shell;
`fzf` se resuelve vía `packages/shell.txt`, que es su lugar natural.

## Decisiones técnicas verificadas en la máquina
- **`infocmp foot` → `kcuu1=\EOA`** (igual que `xterm-256color` y `alacritty`).
  La flecha arriba en modo aplicación de cursor es `\eOA`, NO `\e[A`. Hay que
  bindear **ambas**; bindear sólo `\e[A` es un no-op silencioso.
- **`fzf 0.74.4` expone `fzf --zsh`**: integración nativa de shell, sin
  hand-rolling de keybinds. Se usa `source <(fzf --zsh)` guardado por
  `(( $+commands[fzf] ))`.
- **zsh 5.9**. Ninguno de los dos plugins viene en el sistema → hay que clonar.
- **`SHARE_HISTORY` ya implica `APPEND_HISTORY` e `INC_APPEND_HISTORY`**:
  poner los tres es redundante.
- **Ningún número `08-` existe**: la serie es 00, 00, 01, 02, 02b, 04, 05, 06, 07.
- Los plugins se instalan en `${XDG_DATA_HOME:-~/.local/share}/zsh/plugins/`,
  fuera del repo: es código de terceros, no contenido declarativo.
- Orden de sourcing obligatorio: `compinit` → flechas → fzf → autosuggestions →
  **syntax-highlighting último de todos** (exige ser el último que define ZLE).

## Bugs corregidos de paso
1. **Historial de 30 líneas** — no había `HISTFILE`/`HISTSIZE`/`SAVEHIST`.
2. **`bindkey "^[[A"` inoperante en foot** — falta la forma `\eOA` (y simétrica
   en abajo, Home y End).
3. **`alias update='sudo apt update && sudo apt upgrade -y'`** de la propuesta
   rompe la máquina: es openSUSE Tumbleweed, no hay `apt`. El repo ya usa
   `zypper` en `config/home/.zshrc:11` y en todos los scripts.
4. **`alias ga="git add ."`** — con el plugin `git` de OMZ encima, duplicaba
   aliases (`ga`, `gc`, `gp`, `gl`, `gst` ya los define OMZ). Se adoptan `ga`
   (sin punto) y `gaa` (con `--all`), que es el diseño deliberado de OMZ:
   `git add .` es el camino corto a stagear un `.env` por accidente.
5. **`compinit` sin cache** — ahora usa `-d` con un directorio XDG cache.
6. **`fzf` como dependencia no declarada** — ahora figura en `shell.txt`.
7. **`gc="git commit -m"` roto por diseño** — `gc -m "msg"` expande a
   `git commit -m -m msg`. Se usa `gcam` (`--all --message`) en su lugar.
8. **Aliases `apt` de la propuesta** — reemplazados por los `zypper` que ya
   tenía el repo, más `...` y `c`.

## Correcciones al propio análisis (registro)
Dos claims que iba a afirmar y resultaron falsos al verificar:
- `zsh-syntax-highlighting` **NO** está abandonado (último push 2026-02-08).
- El plugin `docker-compose` de OMZ **SÍ** existe y soporta Compose V2 desde
  2021 (PR #10248); lo que hace es *preferir* el binario v1 legacy si está
  presente, por eso es redundante junto al plugin `docker`.

## Checks ejecutados
- `zsh -n config/home/.zshrc` → exit 0.
- `bash -n scripts/08-setup-zsh.sh` → exit 0.
- `bash -n install.sh` → exit 0.
- `shellcheck --severity=warning 08-setup-zsh.sh` → **0 warnings**.
  `shellcheck` no está instalado en la máquina (está declarado en
  `dev-core.txt` pero el componente Dev Core no se instaló). Corrí el binario
  oficial en un contenedor de un solo uso, con root y `label=disable` acotados a
  un directorio temporal: `--root /tmp/opencode/podman-root --network=none`.
  No se modificó el sistema.
- `shellcheck --severity=style 08-setup-zsh.sh` → 2 hallazgos, ambos falsos
  positivos: `SC1091` (no sigue `common.sh`, arreglable con `-x`) y `SC2034`
  sobre `QUIET`, que sí lo usan `info`/`ok` de `common.sh` — el falso positivo
  nace de no haber seguido ese source.
- `zsh -c 'source ./config/home/.zshrc && print OK'` → `OK`.
- **Degradación**: `XDG_DATA_HOME=/nonexistent zsh -c 'source …'` → `OK`. Es la
  prueba que importa: el `.zshrc` arranca sin los plugins instalados.
- `PATH=/nonexistent` (sin `fzf`) → arranca igual.
- `env -u LS_COLORS zsh -c 'source …'` → `OK`; `zstyle list-colors` con
  `LS_COLORS` vacío no rompe el arranque.
- `bindkey | grep beginning-search` → 4 líneas: `^[[A`, `^[[OA` (arriba) y
  `^[[B`, `^[[OB` (abajo). La simetría es el fix del bug de `foot`.
- Orden de sourcing verificado: `fzf --zsh` (línea 116) → autosuggestions
  (133) → syntax-highlighting (182, último `source` del archivo).
- `git ls-files -s scripts/08-setup-zsh.sh` → `100755`, el modo ejecutable
  quedó en el índice (el `chmod +x scripts/*.sh` del README lo cubre en clones).
- `SC2034` sobre `REPO_DIR` (install.sh:28) y `BLUE` (common.sh:12): **preexistentes**,
  confirmados con `git show HEAD:`. No son regresión de este cambio.

## Bugs encontrados durante la implementación
1. **`local a=1 b=$a` deja `b` vacía.** En bash, `local` declara y limpia todos
   los nombres antes de asignar. `install_plugin` declaraba
   `local url name dest="${PLUGINS_DIR}/${name}"` y `dest` quedaba `"/"`. Lo
   detectó el writer ejecutando el script, no `bash -n`. Fijado declarando los
   nombres juntos y asignando en líneas separadas.
2. **`${entry%%:*}` truncaba las URLs.** `https://` se partía en el primer `:` y
   `git clone` moría con `fatal: repositorio 'https' no existe`. Cambiado el
   separador del array a `|`.
3. **`gcam` es un footgun de diseño heredado.** `gcam -m "msg"` expande a
   `git commit --all --message -m "msg"`, que git lee como mensaje `-m` y
   `"msg"` como rutaspec. Documentado en el `.zshrc` el uso correcto
   (`gcam "msg"`, sin `-m`) en vez de cambiar el alias.
4. **`syntax-highlighting` no quedaba truly-last.** El writer lo puso último de su
   bloque y lo justificó (los aliases y el prompt no definen widgets, lo cual es
   cierto). Equally cierto: "último de todo" es el default defensivo, porque
   cualquier línea futura debajo rompe el resaltado en silencio. Movido al
   final real del archivo.

## Nota sobre cambios ajenos (Waybar) y la topología de la rama
Durante la sesión aparecieron modificaciones en `config/waybar/config` y
`config/waybar/style.css` (mtime 12:06–12:07, a mitad de sesión; agregan módulos
`sway/mode`, `clock`, `tray`, `network`, `cpu`, `memory`, `disk`, `custom/power`
y reformatean a tabs). No son de este trabajo: no las toqué ni las revertí.

El usuario las commiteó después como `14e80cb`, encima de los commits de zsh y en
la misma rama. Se separaron al final de la sesión: Waybar quedó en `feat/waybar`
(`c78c5fc`) y esta rama conserva sólo el trabajo de zsh. El estado intermedio
mixed quedó preservado en `backup/mixed-936b5fc` por si hay que recuperar algo.

La review nativa (`lineage review-9e61d086febc011e`) **no quedó contaminada**:
congeló `candidate_tree 94d344fe` cuando el HEAD era `89d8884`, así que ese commit
de Waybar entró después del freeze y no forma parte del candidato revisado. Por
el mismo motivo, la separación de ramas posterior no altera ese candidato.

## Riesgos y deuda conocida
- **`git clone --depth 1` + `git pull --ff-only`.** Un clone superficial combinado
  con `pull` puede fallar en bordes (ramas divergentes, historia incompleta).
  Falla ruidosamente, que es el comportamiento buscado, pero un `pull` fallido
  deja el plugin en la versión anterior sin aviso más allá del error. Aceptable.
- **El resumen se silencia con `--quiet`.** `resumen()` usa `ok`, que
  `QUIET=1` suprime, así que en modo quiet desaparece el reporte final. Consistente
  con el contrato `QUIET` del repo, pero si algún día se quiere un resumen
  garantizado hay que usar `info` fuera del suppressor.
- **`HIST_VERIFY` cambia el flujo de todo comando recuperado del historial**
  (hay que confirmar con Enter). Es lo pedido, pero es un cambio de hábito:
  `↑ Enter` deja de ser instantáneo.
- **No hay test automatizado del `.zshrc`.** Los checks son de arranque real
  (`zsh -c 'source …'`) y de inspección de `bindkey`, no una suite. Para un
  archivo de shell interactivo es proporcional, pero una regresión en el orden
  de sourcing se detectaría tarde.
- **El `.zshrc` se COPIA, no se enlaza.** Cualquier edición local se pierde en
  silencio. Documentado en el header del archivo y en el README, pero sigue siendo
  la trampa estructural más probable del repo.
- `SC2034` preexistentes (`REPO_DIR`, `BLUE`) siguen sin limpiarse: fuera de
  alcance.
- **La review nativa no se completó.** El lineage `review-9e61d086febc011e`
  quedó en `collect`: los subagentes `review-risk`, `review-resilience`,
  `review-readability` y `review-reliability` fallaron con
  `OpenCode's free tier can only be used from within OpenCode`. Se descartó como
  causa el repo, el payload y `opencode.jsonc`: el subagente `general` despacha
  en la misma sesión, y los bloques de config de `review-*` y `general` sólo
  difieren en permisos. Es una restricción de plan/cuenta del proveedor, ajena a
  este código. El usuario decidió enviar sin review nativa, así que **el slice
  no tiene revisión**: la entrega queda bajo política ordinaria del repo y la
  transacción sigue abierta, sin burns de autoridad.

## Cierre de gaps (T7–T13)

Aprobado por el usuario con "Todo, más los opcionales". Todos los hechos
técnicos fueron verificados empíricamente antes de escribir código:

- **`LS_COLORS` vacío (verificado).** `/etc/zshrc` de openSUSE sólo lo define si
  existe `~/.dir_colors` o `/etc/DIR_COLORS`; no existe ninguno en esta máquina,
  así que `zstyle ':completion:*' list-colors` (línea 69 del `.zshrc`) quedaba
  vacío y el menú de completado sin colores. `dircolors -b` (sin base de datos)
  exporta su tabla por defecto — verificado. **Ojo de orden**: el bloque
  `dircolors` debe correr ANTES de la línea 69, porque el `zstyle` se evalúa en
  el momento de parseo y la primera definición gana.
- **`bashcompinit` es gratis** (0.45 ms por 10 corridas) y requiere `compinit`
  antes (su wrapper `complete` llama a `compdef`). Con el orden real del
  `.zshrc`, `source /usr/share/bash-completion/completions/zypper` no da errores
  y define `_zypper`. Las completions bash de zypper y wofi se cargan bajo
  demanda, en el primer TAB.
- **Substring-search disponible**: `up/down-line-or-history-incremental-
  pattern-search` existen en este zsh (5.9), expuestos como `builtin autoload
  -XU`; en `-f` no hay archivo que verificar con `[[ -f ]]`. Foot no expone
  Ctrl+↑ en terminfo (`infocmp foot` sin `kUP*`): se usa la convención xterm
  `\e[1;5A`/`\e[1;5B`, a confirmar con una tecla en la terminal real.
- **`ZSH_AUTOSUGGEST_STRATEGY=(history completion)`** es válida en
  autosuggestions ≥ 0.7, pero el plugin NO está instalado: la línea queda
  inerte hasta correr `08-setup-zsh.sh` (guarda del `.zshrc`).
- **`WORDCHARS` actual** `[*?_-.[]~=/&;!#$%^(){}<>]`; se AGREGAN `:` (tokens tipo
  PATH) y `@` (user@host) con `+=`, no se pisan.
- **Recorte de git**: `compdef -d git-<subcmd>` desactiva la completion de ese
  subcomando de verdad (verificado: `compdef | grep` baja a 0). Aplicar a una
  lista curada de subcomandos internos que nadie completa a mano.
- **`04` asimétrico (verificado)**: el branch `home` (líneas 88-98) hace
  `[[ -f ]] || continue` → saltea subdirectorios, y no mira el flag `reset`
  (línea 261 lo documenta como intencional, pero el mensaje de confirmación
  línea 263 promete reset también para `home` cuando está seleccionado). Fix:
  con `dotglob`+`nullglob`, copiar archivos y subdirectorios, y con
  `reset=1` borrar primero los destinos declarados por el repo (scoped, sin
  wildcards en `$HOME`). Actualizar el comentario de la línea 261.
- **Ojo 04 en testing**: NUNCA correr contra el `$HOME` real; usar
  `HOME=/tmp/opencode/04sandbox` y una copia del repo (`cp -a scripts config`)
  en `/tmp/opencode/04repo` para que `SCRIPT_DIR` y `CONFIG_DIR` apunten a la
  copia. Mirar que `scripts/04-setup-dotfiles.sh` siga en mode `100755`.

### Estado al cierre (verificado, commiteado)
- **T12 es no-op en esta máquina** (hallazgo del writer, corroborado por el
  orchestrator): `_comps` registra sólo `git` y `gitk`; no existen `_git-*` en
  el fpath de zsh 5.9 de openSUSE, y `_git` despacha subcomandos en runtime.
  `compdef -d git-<cmd>` sobre un nombre no registrado no hace nada. El bloque
  se mantiene por ser inofensivo y correcto en sistemas que sí registren
  subcomandos; **no acelera nada acá**. Si se quiere velocidad real de git
  habría que atacar la completion de archivos (checkout/diff/log), no este
  bloque.
- **Ctrl+↑/↓ pendiente de verificación humana**: los widgets están bindeados
  (`bindkey` muestra 2 binds) pero la secuencia `\e[1;5A`/`\e[1;5B` depende de
  que foot la emita. Probar una vez en terminal real.
- **T10 queda inerte**: `ZSH_AUTOSUGGEST_STRATEGY` se define dentro de la
  guarda, pero el plugin no está instalado — efectiva tras correr
  `08-setup-zsh.sh`.
- **Sandbox de 04 superó**: copia aditiva y reset recopiar archivos + un
  subdirectorio declarado; un archivo local no declarado sobrevive al reset
  (scoped, sin wildcards); modo `100755` intacto. Los dumps temporales de
  compinit/ZDOTDIR usados en la verificación se eliminaron; el repo quedó
  limpio (sin `.zcompdump` commiteado).
- **LS_COLORS real**: `zsh -ic` contra el `.zshrc` nuevo da tabla de `dircolors`
  y `zstyle -L list-colors` con 8 entradas (el orden parse-time funcionó).

