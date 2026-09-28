# nvim nativo: configuración declarativa + set de plugins reducido

## Objetivo
1. CREAR `config/nvim/` como configuración **declarativa** de Neovim, tomando
   `~/.config/nvim/init.vim` (vim-bootstrap, 644 líneas) como **referencia de
   inventario** —qué teclas, qué colores, qué opciones se quieren conservar— y no
   como artefacto a copiar.
2. REDUCIR el set de plugins de 45 a un conjunto reducido **sin plugins muertos**,
   aplicando el criterio de selección del usuario (ver abajo).
3. CREAR `scripts/09-setup-nvim.sh` — instalador idempotente que clona el gestor
   de plugins y resuelve el estado mutable fuera de `config/nvim/`.
4. EXPONER el paso como componente en el menú de `install.sh`.
5. DECLARAR en `packages/dev-*.txt` los paquetes del sistema que la configuración
   necesita y hoy no están instalados.
6. DOCUMENTAR la organización en `docs/organizacion-nvim.md`, al estilo de
   `docs/organizacion-sway.md`.

## Problema
- `~/.config/nvim/init.vim` **carga sin un solo error** (`nvim --headless` sale con
  exit 0, `:messages` vacío) y aun así **una parte grande está muerta en
  silencio**. El arranque limpio no es evidencia de funcionamiento.
- **`has('python3') == 0` en Neovim 0.12.5**: el provider de Python 3 fue eliminado.
  Esto mata, de forma estructural, a UltiSnips
  (`plugged/ultisnips/plugin/UltiSnips.vim:51` → `if !has('python3') | finish`),
  jedi-vim y vim-lua-inspect. **Ningún paquete del sistema lo revierte.**
- **vim-go aborta sin Go**: `plugged/vim-go/plugin/go.vim:80` →
  `if go#path#Default() == ""`. Con `go#path#Default()` vacío no define **ningún**
  comando `:Go*` (`GoBuild`, `GoTest`, `GoFmt`, `GoDef` verificados ausentes). La
  variable `g:go_loaded_install` queda en 1.
- **rust.vim exige Syntastic** (`plugged/rust.vim/plugin/rust.vim:15-21` hace
  `finish` salvo que exista `g:syntastic_extra_filetypes`) y Syntastic **no está**
  en la lista `Plug`. Syntastic está archivado desde 2021. Instalar Rust no lo revive.
- **fzf está declarado dos veces** (`init.vim:54-59` y `init.vim:155-156`). Se
  cargan dos copias de `fzf.vim`; la de `~/.fzf` va primera, setea
  `g:loaded_fzf_vim`, y la de `plugged/fzf.vim` hace `finish`
  (`plugged/fzf.vim/plugin/fzf.vim:24-26`). Resultado verificado: **`:Fzf` no
  existe**, solo `:Snippets`.
- **vimproc nunca compiló**: no existe el binario, así que todo lo que dependa de él
  queda sincrónico. Es innecesario en Neovim.
- `local_init.vim` y `local_bundles.vim` no existen: no se carga ninguna
  personalización del usuario.
- **La configuración no está en el repo.** No hay nada de nvim en el árbol; hoy es
  efímera.

## Por qué
El objetivo declarado del usuario es doble: (a) una base similar a la de
vim-bootstrap, y (b) que la configuración **"perdure en el tiempo"**, es decir, que
repararse en el futuro con pocos ajustes —arreglar URLs o reemplazar plugins— en lugar de
rehacerla.

El objetivo (b) es el que restringe las decisiones, y la lista de plugins de
vim-bootstrap es su peor enemigo. Esa lista es de **2017**, cuando Neovim no tenía
`vim.diagnostic`, ni `vim.lsp.config`, ni `vim.system`, ni treesitter. El plugin
existe hoy en la mayoría de los casos **porque Neovim todavía no lo traía**. Mantener
la lista implica mantener alrededor de plugins que Neovim ya no necesita.

El patrón de despliegue ya está resuelto por precedentes del propio repo: `zsh`
usó `08-setup-zsh.sh` y una configuración declarativa (`zsh-nativo.md`), y `sway`
partió su config en 22 módulos por features (`organizacion-sway.md`). Neovim 0.12
usa además el **mismo split XDG que zsh**, lo que hace la analogía exacta:
config declarativa en `~/.config/`, estado mutable en `~/.local/share/`.

## Criterio de selección de plugins
Restricción del usuario, en tres reglas. Se aplica plugin por plugin y el resultado
es explícito:

1. Se instala un plugin **sólo si no hay alternativa** para obtener esa
   funcionalidad.
2. Se instala un plugin **sólo si mejora la usabilidad** para el usuario.
3. **Un plugin que hace lo que Neovim ya hace por defecto es candidato a ser
   desestimado.**

El criterio 3 es el que más reduce el set, y es correcto: se verificó qué hay
nativo en 0.12.5 antes de aplicar el veredicto (ver *Decisiones técnicas
verificadas*).

## Inventario de los 45 plugins y veredicto
`K` conservar · `R` reemplazar · `D` descartar (lo cubre nativo u otro plugin)

| Plugin vim-bootstrap | Veredicto | Destino | Razón |
| --- | --- | --- | --- |
| nerdtree | R | neo-tree.nvim | Sin árbol nativo. neo-tree es el sucesor mantenido y además cubre tabs → elimina nerdtree-tabs. |
| nerdtree-tabs | D | — | neo-tree integra el soporte de tabs. |
| commentary | **R** | mini.comment | **VERIFICADO: no hay operador de comentarios nativo.** No aplica criterio 3; se cambia por maintained. |
| fugitive | K | — | Sin cliente git nativo. |
| airline + airline-themes | R | lualine | Hay statusline nativo, pero lualine es netamente superior en UX; airline está en maintenance. |
| gitgutter | R | gitsigns | Sin equivalente nativo, pero gitgutter tiene fallback síncrono que congela la UI; gitsigns es async nativo. |
| grep.vim | D | — | `:grep` + quickfix son nativos de Vim. |
| CSApprox | D | — | Neovim 0.12 es truecolor; repo sin actividad desde 2012. |
| delimitMate | R | nvim-autopairs | Sin equivalente nativo; nvim-autopairs es mantenido y más rápido. |
| tagbar | D | — | LSP nativo (`vim.lsp.buf.references`) + `:h tagfunc` cubren el caso; además exigiría ctags. |
| ale | R | nvim-lint + conform.nvim | `vim.diagnostic` es nativo y ALE está en maintenance con su LSP deprecado. **No se pierden linters: se ganan.** |
| indentLine | D | `fillchars+=vert:` | **VERIFICADO**: `set fillchars+=vert:┆` funciona en 0.12.5; `listchars+=vert:` falla con E474. |
| vim-bootstrap-updater | D | — | Artefacto de vim-bootstrap. |
| rhubarb | D | — | Sólo `:GBrowse`. |
| badwolf | K | — | Coherente con `14e80cb`, que ya aplicó badwolf a waybar. |
| fzf (declarado ×2) | R | telescope + fzf-lua | Corregir el doble `Plug`; telescope integra `vim.ui.select` nativo. |
| fzf.vim | R | telescope.nvim | `vim.ui.select` nativo verificado. |
| vimproc.vim | D | `vim.system` | **VERIFICADO**: `vim.system` y `vim.uv` existen en 0.12.5. |
| vim-misc (xolox) | D | — | Utilería sin uso real en la config. |
| vim-session | D | `:mksession`/`:source` | Nativo de Vim. |
| ultisnips | R | LuaSnip | **MUERTO** por `has('python3')==0`. |
| vim-snippets | D | luasnip-snippets | Supersedido por LuaSnip. |
| vim-go | R | nvim-go | Fork mantenido; vim-go aborta sin Go. |
| vim-css3-syntax | D | nvim-treesitter | Treesitter nativo. |
| vim-coloresque | D | — | Sin actividad desde 2020. |
| vim-haml | D | — | Sin actividad. |
| emmet-vim | K | — | Sin equivalente nativo; alta utilidad web. |
| vim-javascript-syntax | D | nvim-treesitter | Treesitter nativo. |
| vim-lua-ftplugin | D | — | Neovim ya trae ftplugin de Lua. |
| vim-lua-inspect | D | LSP de Lua | `has('lua')==0`; el provider de Lua de Vim no aplica. |
| phpactor | R | phpactor (servidor) + LSP nativo | Se conserva el **servidor**, se descarta el **plugin vim**: el LSP lo pone Neovim. Falta `composer install`. |
| vim-php-cs-fixer | D | conform.nvim | conform.nvim es el formateador universal. |
| jedi-vim | D | pyright/ruff + LSP nativo | **MUERTO** por `has('python3')==0`. |
| requirements.txt.vim | D | conform.nvim | Formateador declarativo. |
| vim-racer | D | rust-analyzer | Deprecado upstream; el clon local no tiene `plugin/`. |
| rust.vim | D | rust-analyzer + LSP nativo | **MUERTO**: exige Syntastic, que no está en la lista. |
| async.vim | D | `vim.system` | Neovim es async-nativo. |
| vim-lsp | D | `vim.lsp.config` / `vim.lsp.enable` | **VERIFICADO**: ambos existen en 0.12.5. |
| asyncomplete.vim | D | nvim-cmp | Abandonado en 2021. |
| asyncomplete-lsp.vim | D | nvim-cmp + LSP nativo | Abandonado en 2021. |
| vim-svelte-plugin | D | LSP de Svelte | Repo sin `plugin/`; abandonado. |
| typescript-vim | D | nvim-treesitter | Treesitter nativo. |
| yats.vim | D | ts_ls/vtsls + LSP nativo | La sintaxis la da treesitter. |
| posva/vim-vue | D | nvim-treesitter | Treesitter nativo. |
| vim-vue-plugin | D | — | Sin actividad desde 2023. |

**Resultado: 45 → 16 familias de plugin, cero plugins muertos.** Supervivientes:
neo-tree, mini.comment, fugitive, lualine, gitsigns, badwolf, telescope, fzf-lua,
nvim-autopairs, LuaSnip + luasnip-snippets, nvim-go, emmet-vim, nvim-lint,
conform.nvim, mason.nvim, nvim-cmp, nvim-treesitter. Más `lazy.nvim` como gestor y
`phpactor` como servidor, no como plugin.

## Tareas
- [x] T1 — Crear `config/nvim/` con la estructura declarativa base (`init.lua` +
      `lua/config/{options,autocmds}.lua`). Verificado: `04-setup-dotfiles.sh`
      autodetecta `config/<app>/` por glob, `config/nvim/` entra sin cambios.
- [x] T2 — Sistema de plugins: bootstrap de `lazy.nvim` y declaración del set
      reducido en `lua/plugins/*.lua` (7 archivos: core, ui, git, editing,
      search, completion, lang). Verificado con arranque headless aislado en
      `/tmp/opencode/nvim-test`: 17 plugins, lockfile escrito, `exit 0`.
      Desviación documentada: `crispgm/nvim-go` (hrsh7th → 404, zchee →
      abandonado) no cumple los keymaps de UX del reference (sin coverage
      toggle/GoDecls/alternates); los keymaps se mapearon a los comandos reales
      del plugin y los faltantes quedan marcados.
- [x] T3 — Crear `scripts/09-setup-nvim.sh` (755) al patrón de
      `08-setup-zsh.sh`: idempotente, flag `--update`, `resumen()` final,
      destino en `${XDG_DATA_HOME:-~/.local/share}/nvim`. Adaptación:
      `PLUGINS` solo declara el gestor lazy.nvim (el set real vive en las
      specs Lua), y la acción es `nvim --headless "+Lazy! install"` (no
      `sync`, porque `sync` arranca con `clean()` que borra lo instalado).
- [x] T4 — Migrar los plugins vivos conservando la experiencia de vim-bootstrap
      (LSP + linters/formatters, snippets, árbol, git, fuzzy finder, auto-pairs,
      tema badwolf, emmet). **Decisión del usuario (2026-09-28): idiomas activos
      = HTML, JavaScript, Lua, PHP, Python, TypeScript, Svelte. Excluidos por
      ahora: Go, Vue, Rust.** Consecuencia: `nvim-go` se elimina del set (la
      desviación de keymaps documentada en S3 queda sin efecto mientras Go esté
      excluido; si Go vuelve, se reintroduce con su decisión de fork).
      **Completado 2026-09-28** (S4): LSP nativo + mason en
      `lua/config/lsp.lua`, linters/formatters en `lua/plugins/lang.lua`.
- [x] T5 — Tabla declarativa de soporte por lenguaje, con la función activable en
      una línea. **Lenguaje base por defecto: DECIDIDO (7 activos, ver T4).**
      **Completado 2026-09-28** (S4): `lua/config/langs.lua` es la fuente única;
      los archivos de plugins derivan todo de esa tabla.
- [x] T6 — Mover `keymaps` a `lua/config/keymaps.lua` preservando la ergonomía de
      vim-bootstrap (leader `,`, `F2`/`F3`/`F4`, `gc`, `q`/`w` de buffer, `C-h/j/k/l`).
      **Completado 2026-09-28** (S4): mapeos globales en `lua/config/keymaps.lua`;
      los de cada plugin viven en su spec. **F4 → `vim.lsp.buf.document_symbol()`
      CONFIRMADO por el usuario (2026-09-28)** — reemplazo de Tagbar; referencias
      quedan en `gr` (LSP on_attach).
- [x] T7 — Declarar los paquetes faltantes en `packages/dev-*.txt`. **Completado
      2026-09-28 (S5)**: declarados `php8-posix`, `php-cs-fixer` en
      `dev-php.txt` y `python313-flake8` en `dev-python.txt` (verificados
      existentes en Tumbleweed). phpactor via mason (ver S5), sin composer.
- [ ] T8 — Proteger el deploy: separar estado mutable de config declarativa y
      neutralizar el `rm -rf` de `aplicar_app()` sobre el directorio de plugins.
- [ ] T9 — Componente en el menú de `install.sh` + `README.md`.
- [ ] T10 — `docs/organizacion-nvim.md` y cierre con verificaciones.

## Work units y assessment RDD
RDD está `on` (decided by global), confirmado. Convención del repo: **merge directo a
`main`, sin PR** (repo personal), commits conventional en español, un work unit por
commit con sus tests y docs junto al comportamiento.

Presupuesto de entrega: se estima **~600–900 líneas autorales** (config Lua, script
de setup, paquetes, docs), por encima de las ~400 del umbral. Al no haber PR, el
corte se hace por work-unit commits y el candidato de revisión nativa es el slice
acumulado desde el último boundary revisado, con `review assess` por commit.

| Work unit | Tareas | Riesgo esperado |
| --- | --- | --- |
| W1 — Estructura y gestor de plugins | T1, T2, T3 | `executable_change` (script nuevo) |
| W2 —Funcionalidad | T4, T5, T6 | `executable_change` (muchos módulos Lua) |
| W3 — Sistema, paquetes y deploy | T7, T8, T9 | `executable_change` + toca `install.sh` |
| W4 — Documentación y cierre | T10 | pasivo |

## Alcance autorizado
- NUEVO `config/nvim/**`
- NUEVO `scripts/09-setup-nvim.sh` (755)
- EDITADO `packages/dev-core.txt`, `packages/dev-rust.txt`, y los `dev-*.txt` que
  resulten del mapeo de T5
- EDITADO `install.sh` (registro del componente)
- EDITADO `README.md`
- NUEVO `docs/organizacion-nvim.md`
- EDITADO este documento

Fuera de alcance (decidido NO tocar): `scripts/04-setup-dotfiles.sh`. Su
autodetección de `config/<app>/` ya cubre `config/nvim/` sin cambios. El riesgo del
`rm -rf` se mitiga **desde el lado de nvim** (T8), no modificando ese script.

## Decisiones técnicas verificadas en la máquina
Verificado ejecutando sobre el **Neovim 0.12.5** instalado, no de memoria:

- **`vim.system` = function**, **`vim.uv.spawn` = function** → cubren
  vimproc.vim y async.vim. Nadie compila nada.
- **`vim.diagnostic` = table** → cubre el diagnostado de ALE.
- **`vim.lsp.config` = table**, **`vim.lsp.enable` = function** → sustituyen
  vim-lsp con configuración declarativa nativa.
- **`vim.treesitter.get_parser` = function** → cubre la sintaxis de
  css3/javascript/typescript-vim/posva-vue.
- **`vim.ui.select` = function** → integración nativa de telescope.
- **`vim.snippet` = table** → confirma la dirección, aunque el motor de snippets
  con repositorio sigue siendo LuaSnip.
- **`has('nvim-0.9'..'0.12')` = 1 en los cuatro** → toda la línea de base asumida
  está disponible.
- **Indentline nativo: `set fillchars+=vert:┆` funciona; `set listchars+=vert:┆`
  falla con E474.** La vía correcta es `fillchars`, no `listchars`.
- **`vim.system` etc. existen, pero `luaeval` falla bajo `-S` en este entorno**:
  hay que verificarlos con `nvim --headless --cmd 'lua …'`, no con `luaeval` en un
  `-S`. Un probe con `luaeval` devolvió ceros falsos y se descartó.
- **`v:patch` no existe** en 0.12 (abortó un probe). Para la versión usar
  `has('nvim-0.12')`.

## Paquetes del sistema (verificados en Tumbleweed)
| Paquete | Versión | Para qué | Estado |
| --- | --- | --- | --- |
| `ctags` | 5.8 | Exuberant ctags | Declarado en `dev-core.txt`, **no instalado** |
| ~~`go`~~ | 1.27 | gopls | **Excluido** — Go fuera del set activo (decisión 2026-09-28) |
| `python313-flake8` | 7.3.0 | linter Python | **Declarado 2026-09-28** (S5) en `dev-python.txt`, no instalado |
| `php-cs-fixer` | 3.13.0 | formateo PHP | **Declarado 2026-09-28** (S5) en `dev-php.txt`, no instalado |
| `php8-posix` | 8.5.10 | extensión POSIX requerida por phpactor | **Declarado 2026-09-28** (S5) en `dev-php.txt`, no instalado |
| ~~`rustup`~~ | 1.29 | rust-analyzer | **Excluido** — Rust fuera del set activo (decisión 2026-09-28) |

`gofmt` y `goimports` salen de la toolchain de Go, no de zypper. `ag`
(silver-searcher) **no está empaquetado** en Tumbleweed y no hace falta: ripgrep ya
está y la config cae sola.

phpactor **no está empaquetado** en Tumbleweed (verificado `zypper --no-refresh
search phpactor` → vacío): se instala vía composer (ver S5).

## Correcciones al propio análisis (registro)
Claims que iba a afirmar y resultaron falsos al verificar:
- **"Neovim 0.12 comenta nativamente con `gc`" → FALSO.** No existe
  `runtime/plugin/comment*` ni `gc` en `runtime/lua/vim/_editor.lua`. El `gc` que
  responde en esta máquina viene de `plugged/vim-commentary/plugin/commentary.vim:115`.
  **vim-commentary no es descartable por el criterio 3**; se reemplaza por
  maintained (mini.comment), no se elimina.
- **"El indentline nativo va en `listchars`" → FALSO**, da E474. Va en `fillchars`.
- **"`exists('*vim.system')` sirve para verificar" → FALSO.** Devuelve 0 para
  funciones de autoload. Hay que llamar la función o usar `has('nvim-0.x')`.

## Checks previstos
- `nvim --headless -c 'qall!'` → exit 0 y `:messages` sin errores.
- Conteo de plugins cargados y confirmación de que **ninguno de los 16 está en la
  lista de muertos**.
- `bash -n scripts/09-setup-nvim.sh` → exit 0.
- `shellcheck --severity=warning scripts/09-setup-nvim.sh` → 0 warnings.
- **Degradación**: arrancar sin `~/.local/share/nvim` (sin plugins) no debe romper.
- `git ls-files -s scripts/09-setup-nvim.sh` → `100755`.
- Verificar que `config/nvim/` **no** contiene `plugged/`, `autoload/`, `session/`
  ni estado mutable.

## Riesgos y deuda conocida
- **~`rustup`/paquete `rust`~**: **resuelto por decisión del usuario (2026-09-28)** —
  Rust queda **fuera** del set activo, así que no hay conflicto de toolchains ni
  necesidad de rust-analyzer por ahora. Si Rust vuelve al set, reaparece la
  disyuntiva rustup vs distro; es una línea en T5.
- **`aplicar_app()` en `scripts/04-setup-dotfiles.sh:104` hace `rm -rf` del destino
  si `reset=1`**, y en la línea 108 hace overlay con `cp -r`. Con `config/nvim/`
  presente, el camino `reset=1` **borraría los plugins ya instalados**. T8 lo
  mitiga desde el lado de nvim.
- **El estado mutable no puede vivir en `config/nvim/`**: si el repo versionara
  `plugged/` o `autoload/`, cada corrida de `04-setup-dotfiles.sh` lo pisaría.
  Neovim 0.12 ya separa `~/.config/nvim` (declarativo) de
  `~/.local/share/nvim` (plugins) y `~/.local/state/nvim` (shada). El repo debe ser
  dueño sólo de la primera.
- **Perder funcionalidad real al reducir.** El criterio 3 es correcto pero tiene
  costo: `tagbar` y `grep.vim` se van y no hay reemplazo 1:1. Hay que verificar
  usability con T6 antes de dar por cerrada T4.
- **Rama actual `feat/zsh-nativo`**: el trabajo de nvim **no** debe mezclarse con esa
  rama. Hace falta una rama propia antes del primer write de fuente.
- `lua-resty`-style dependencies de LuaSnip/treesitter/mason se descargan en
  runtime. Si el usuario queda sin red, el arranque debe degradar sin error.

## Próximo paso
**Decisión del usuario: NO se crea la rama todavía.** El trabajo se hace sobre
`feat/zsh-nativo` sin commitear y la rama `feat/nvim-nativo` se crea cuando la
configuración ya esté en el repo. Aclaración: `git checkout -b` arrastra los
archivos sin commitear, así que branchear más tarde **no** pone en riesgo la
referencia. El único actor que puede perderla es el `rm -rf` de
`aplicar_app()` (`scripts/04-setup-dotfiles.sh:104`), que se activa recién cuando
existe `config/nvim/`.

S1. ✅ **Copia de referencia PODADA creada** (decisión del usuario, en lugar de
    versionar el `init.vim` crudo de 2017). Vive en `docs/referencia/nvim-vim-bootstrap-init.vim`,
    **fuera de `config/nvim/`**: `aplicar_app()` copia `config/<app>/.` completo,
    así que dentro de `config/nvim/` viajaría a `~/.config/nvim/` como ruido
    desplegado.
    - Contenido: sólo lo que sobrevive del veredicto — ajustes base,
      autocmds, keymaps, tema y el set de plugins mantenido.
    - Los plugins descartados se conservan **como comentario de procedencia**,
      nunca como código ejecutable.
    - Encabezado que declara: qué es, de dónde sale, `45 → N` plugins, y que **no
      se ejecuta**.
    - No se versiona el crudo: el manifiesto de qué se descartó ya está en la
      tabla de veredictos de este documento, y versionar 644 líneas de 2017 suma
      ruido sin capacidad de auditoría adicional.
S2. ✅ **Auditoría del podado pasada**: multiset de directivas normalizadas
    Original(266) ⊇ Podado(199) — 67 eliminadas, **0 adiciones, 1 error corregido**
    (`nnoremap <leader>y` → `nmap <leader>y :History:<CR>`), ver
    `/tmp/opencode/poda_audit.py`. Mismo rigor que el split de sway.
S3. ✅ **T1–T3 completados** (estructura base `config/nvim/`, bootstrap lazy.nvim +
    `lua/plugins/*.lua` por dominio, `scripts/09-setup-nvim.sh`). Verificación
    real con arranque aislado (17 plugins, lockfile, `exit 0`) + spot check del
    orquestador (7/7 `luafile` OK, `bash -n` OK). Sin rama ni commits (decisión
    del usuario: la rama se crea cuando la config esté en el repo — el writer
    reportó haber commiteado el lockfile, pero el estado real de git muestra que
    NO hubo commit; el trabajo quedó untracked como se pidió).
    Pendientes: decisión de idiomas (T5/T7) y el reemplazo de los keymaps de
    UX que nvim-go no cumple (T4).

**T5 y T7 siguen bloqueados** por la decisión del conjunto de idiomas, que no es
urgente para arrancar.

## Pregunta abierta
- ~~**¿Qué conjunto de idiomas va activo por defecto?**~~ **Cerrada 2026-09-28**:
  idiomas activos = HTML, JavaScript, Lua, PHP, Python, TypeScript, Svelte (7);
  excluidos por ahora: Go, Vue, Rust (ver T4/T5).

## S4. T4–T6 completados (writer delegado + spot check del orquestador)

**Entregado 2026-09-28, todo en `config/nvim/`, sin commits (sigue la decisión del
usuario de no branchear/commitear todavía).**

- `lua/config/langs.lua` — tabla declarativa por lenguaje (ft/lsp/lint/fmt/ts) +
  helpers derivados (filetypes, parsers, server_filetypes, linters_by_ft,
  formatters_by_ft, all_packages). Nombres de linters/formatters/parsers/cmd
  **verificados contra la fuente del plugin instalado**, no contra un lockfile:
  nvim-lint `lua/lint/linters/*.lua`, conform `lua/conform/formatters/*.lua`,
  nvim-treesitter `lua/nvim-treesitter/parsers.lua`, nvim-lspconfig `lsp/*.lua`,
  índice de mason-registry. Todos los paquetes mason **instalados** en la
  verificación (evento `package:install:success` + `is_installed()`), no sólo
  nombrados.
- `lua/config/lsp.lua` — `vim.lsp.config` + `vim.lsp.enable` por servidor
  (filetypes derivados de langs.lua), `root_markers` (`.git`, `package.json`,
  `composer.json`, `pyproject.toml`, `.luarc.json`), `on_attach` con los keymaps
  LSP (gd, gr, `<leader>rn`, `<leader>ra`, `<leader>ld`, [d/]d, gK — `K` se deja
  al default de Neovim 0.12, `gd` conserva el de vim-racer). Instalador mason
  **manual** (`mason-registry.get_package` + `Package:install` + eventos
  `package:install:success/failed` + re-disparo de `FileType` para buffers
  abiertos antes de que el binario existiera). Sin nvim-lspconfig a propósito:
  los `cmd` se copiaron de su config (autoridad mantenida), largo comentario
  VERIFIED con los 7 servidores.
- `lua/plugins/lang.lua` — treesitter **rama `main`** (verificado: NO archivado,
  último commit 2026-09-27, `main` es rewrite para 0.12 y **no tiene
  `ensure_installed`** → `require('nvim-treesitter').install(missing):wait(...)`;
  `master` congelado). nvim-lint sin `setup()` (no existe; se asignan campos a
  módulo) + autocmd `BufWritePost` → `try_lint()`. conform.nvim con
  `formatters_by_ft` derivado, `format_on_save` con `lsp_format = "fallback"`, y
  **stylua con `--indent-type Spaces --indent-width 2 --column-width 100`** vía
  `conform.util.extend_args` (el repo es 2 espacios; sin eso formatearía todo con
  tabs). emmet-vim acotado a `ft = { "html", "css" }` (vue fuera).
- `lua/plugins/completion.lua` — fuentes de nvim-cmp **separadas** (los builtin
  se removieron en nvim-cmp actual, VERIFICADO: `sources` default vacío y
  `cmp.source` ya no trae `nvim_lsp`/`buffer`/`path`/`luasnip` → hay que
  declarar cmp-nvim-lsp/cmp-buffer/cmp-path/cmp_luasnip). Snippet expand con
  fallback seguro a `cmp.snippet.expand` cuando LuaSnip aún no está cargado.
- `lua/config/keymaps.lua` — todos los mapeos globales nativos (C-h/j/k/l,
  buffers, tabs, search zzv/zzzv, terminal `<leader>sh`, clipboard con guard
  `has("unnamedplus")`); cada decisión con su razonamiento inline. No se mapean
  las abreviaturas `cnoreabbrev W/Q/E` (riesgo de disparo accidental en `:s///`)
  ni `:FixWhitespace` (es comando, no keymap).

### Decisiones/deviaciones registradas por el writer (verificadas)
- **`mason.ensure_installed` NO existe en mason 2.3.1** (removido) → bucle manual
  (VERIFIED contra fuente commit 2a6940a).
- **lualine `options.section_a` ignorado** → `options.sections.lualine_a`; y
  `refresh.events = { GitSignsUpdate }` da E216 (evento no existe) → se usa el
  default. (Ajustes ya aplicados en `lua/plugins/ui.lua` durante T2/T4.)
- **No hay `gc` nativo** (confirmado de nuevo en S4): mini.comment trae sus
  propias expression mappings; un `keys` de spec los rompería (pierde la
  indirección operatorfunc que hace funcionar `10gc_`).
- **treesitter `main`**: el plan decía "archivado" — estaba mirando un punto
  anterior; re-verificado 2026-09-28 contra el repo real (NO archivado, commit
  2026-09-27). Se pincha `main` y se adapta el API.
- **phpactor**: el binario mason instala funciona con `phpactor language-server`,
  pero el **LSP de PHP queda bloqueado en T7** por la extensión PHP `posix`
  ausente (PHP 8.5.10 de Tumbleweed no la trae; `packages/dev-php.txt` no la
  lista). El writer lo marca como línea de T7: declarar `php8-posix`. Hasta
  entonces, phpactor arranca pero muere por la extensión faltante.
- **Svelte**: el crash reportado en verificación fue artefacto del entorno de
  prueba (file-watcher caminando `/tmp` y chocando con un loop de symlinks en
  `/run/udev/watch`), no de la config; con un root de proyecto real funciona.
- **`loaders_store_source` NO es la causa** de "no hay snippets": el probe con
  `luasnip.get_snippets({ft=...})` devuelve 0 incluso cuando la expansión
  funciona. NO tocar ese flag por eso.

### Spot check del orquestador
7/7 `luafile` OK sobre los archivos nuevos/modificados en árbol XDG aislado +
`bash -n scripts/09-setup-nvim.sh` OK. `grep` confirmó que nvim-go ya no está en
`lang.lua` (sólo queda una mención de procedencia en comentario de langs.lua). El
writer también reportó que nvim-cmp elige `<Tab>`/`<S-Tab>` sobre el preset
completo de inserción (mantiene el trigger de UltiSnips).

### Pendiente de confirmación del usuario: F4 — **RESUELTO (2026-09-28)**
El plan decía F4 → reemplazo de Tagbar con `vim.lsp.buf.references()`, pero
**`references` no puede ser global**: `<leader>gr` es fugitive GRemove, y `gr`
plano ya es LSP references en `on_attach`. El usuario **confirmó
`F4 → vim.lsp.buf.document_symbol()`** (outline flotante, avisa si no hay
servidor). Aplicado en `keymaps.lua` (comentario actualizado).

## S5. T7 (paquetes) — completado; phpactor va por mason, no por composer

**2026-09-28.** Verificado contra los repos de Tumbleweed (`zypper --no-refresh
search/info`), no de memoria:

- `python313-flake8` **7.3.0** existe → declarado en `packages/dev-python.txt`.
- `php-cs-fixer` **3.13.0** existe → declarado en `packages/dev-php.txt`.
- `php8-posix` **8.5.10** existe → declarado en `packages/dev-php.txt`
  (desbloquea el LSP phpactor detectado en S4).
- **phpactor NO existe como paquete** en Tumbleweed (`zypper search phpactor`
  vacío), y **NO hace falta**: S4 verifica que mason lo instala como phar
  (mason-registry `phpactor` → `phpactor.phar` + wrapper bash). La única
  dependencia del sistema es la extensión **`posix`** → ya declarada como
  `php8-posix`. La vía "composer install" que asumía el inventario original
  quedó obsoleta al implementar la instalación por mason.
- Comprobación real: `phpactor --version` en el árbol de prueba falla con
  "[ERROR] The application requires the extension posix" — la extensión es el
  **único** blocker; instalado `php8-posix`, el LSP de PHP arranca.

Próximo paso: **branch `feat/nvim-nativo` creada 2026-09-28** con los commits de
W1, W2 y T7 (ver *Work units registradas* abajo); queda T8/T9/T10 sobre la rama
nueva, y el assessment RDD del slice acumulado contra `7fbbabe`.

## Work units registradas (2026-09-28, rama `feat/nvim-nativo`)
- `2a14384` — `feat(nvim): base declarativa con lazy.nvim y script de setup` (W1: T1–T3)
- `db2e8aa` — `feat(nvim): LSP nativo, tabla declarativa de idiomas y keymaps` (W2: T4–T6)
- `1e061c0` — `chore(packages): php8-posix, php-cs-fixer y flake8 para el LSP de nvim` (T7)
- `7f1200e` — `docs(nvim): referencia podada del init.vim y tracking ODD del cambio` (S1/S2 + este doc)
- El doc ODD y `docs/referencia/nvim-vim-bootstrap-init.vim` se commitean junto con este registro.

**Assessment RDD del slice (2026-09-28):** `gentle-ai review assess --base-ref 7fbbabe
--committed-only` → **risk high** (executable_mode + process_boundary + shell_source
en `scripts/09-setup-nvim.sh`). Preflight STATUS devolvió START de target fresco
(lineage `review-2955135d2b256e48`). **Consent del candidato: DECLINED por el
usuario** (`action: declined`, `consent: declined_this_candidate`), candidate-scoped,
no kill switch. Sin registro de revisión creado; la entrega sigue política ordinaria
del repo. Los T8–T10 siguientes (que no tocan `scripts/09`) preguntarán de nuevo según
su propio risk tier.
