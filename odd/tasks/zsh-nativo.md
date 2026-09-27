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

## Work units y assessment RDD
RDD está `on` (decided by global). Los docs se commitearon junto a su cambio,
no en un commit aparte de "update docs".

| Commit | Unidad | `review assess` (base `main`) |
| --- | --- | --- |
| `efb21eb` | `.zshrc` + `shell.txt` + nota de copia | **medium** (`executable_change`) |
| `86e9466` | `08-setup-zsh.sh` + wiring en `install.sh` + docs | deferred (mismo slice) |

`medium` se difiere por protocolo: el candidato es el PR slice (los commits
acumulados desde el último boundary revisado), no el commit individual. El
STATUS preflight corre al cerrar la feature, con `--base-ref main`.

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

## Nota sobre cambios ajenos en el working tree
Durante la sesión aparecieron modificaciones **no commiteadas** en
`config/waybar/config` y `config/waybar/style.css` (mtime 12:06–12:07, a mitad
de sesión; agregan módulos `sway/mode`, `clock`, `tray`, `network`, `cpu`,
`memory`, `disk`, `custom/power` y reformatean a tabs). No son de este trabajo y
no las toqué ni las revertí. Se reportan al usuario.

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

