" ============================================================================
" REFERENCIA PODADA — NO SE EJECUTA
" ============================================================================
" Origen: ~/.config/nvim/init.vim — vim-bootstrap 2026-09-27 14:36:22
"
" Esto NO es la configuración activa ni una configuración que se pueda correr.
" Es la extracción de lo que SOBREVIVE al veredicto de plugins documentado en
" odd/tasks/nvim-nativo.md (45 -> 16 familias de plugin, cero muertos), para
" que la migración (T4) preserve fielmente la experiencia: ajustes, teclas,
" autocmds, tema y perfil por lenguaje.
"
" Convenciones de podado:
"   - Ajustes base, visuales, autocmds y mappings: se conservan tal cual.
"   - Plugin descartado: su bloque de config se elimina y se marca con
"     __DESCARTADO__ seguido del destino (nativo de Neovim u otro plugin).
"   - El manifiesto de supervivencia va al final, comentado, NUNCA ejecutable.
"
" Veredicto completo por plugin: odd/tasks/nvim-nativo.md (tabla 45 -> N).

"*****************************************************************************
"" Base setup — CONSERVADO
"*****************************************************************************
set encoding=utf-8
set fileencoding=utf-8
set fileencodings=utf-8

set backspace=indent,eol,start

set tabstop=4
set softtabstop=0
set shiftwidth=4
set expandtab

let mapleader=','

set hidden

set hlsearch
set incsearch
set ignorecase
set smartcase

set fileformats=unix,dos,mac

if exists('$SHELL')
    set shell=$SHELL
else
    set shell=/bin/sh
endif

" session management __DESCARTADO__ (vim-session eliminado; nativo :mksession/:source)

"*****************************************************************************
"" Visual Settings — CONSERVADOS
"" CSApprox __DESCARTADO__: Neovim 0.12 es truecolor, CSApprox (2012) no aplica.
"" indentLine __DESCARTADO__: verificado — 'set fillchars+=vert:┆' funciona;
"" 'set listchars+=vert:┆' falla con E474. El carácter ┆ y el concealcursor
"" se conservan como intención para el reemplazo nativo.
"*****************************************************************************
syntax on
set ruler
set number

let no_buffers_menu=1
set background=dark
colorscheme badwolf

set wildmenu

set mouse=a

set mousemodel=popup
set t_Co=256

set gfn=Monospace\ 10

if has("gui_running")
  if has("gui_mac") || has("gui_macvim")
    set guifont=Menlo:h12
    set transparency=7
  endif
else
  let g:indentLine_concealcursor = ''
  let g:indentLine_char = '┆'
  let g:indentLine_faster = 1
endif

"" Disable the blinking cursor.
set gcr=a:blinkon0

au TermEnter * setlocal scrolloff=0
au TermLeave * setlocal scrolloff=3

"" Status bar
set laststatus=2

"" Use modeline overrides
set modeline
set modelines=10

set title
set titleold="Terminal"
set titlestring=%F

set statusline=%F%m%r%h%w%=(%{&ff}/%Y)\ (line\ %l\/%L,\ col\ %c)\

" Search mappings: These will make it so that going to the next one in a
" search will center on the line it's found in.
nnoremap n nzzzv
nnoremap N Nzzzv

if exists("*fugitive#statusline")
  set statusline+=%{fugitive#statusline()}
endif

" vim-airline __DESCARTADO__ (reemplazo: lualine; la extensión de tabline y
" branch se conservan como intención de UX, no como config de airline).
let g:airline_theme = 'powerlineish'
let g:airline#extensions#branch#enabled = 1
let g:airline#extensions#ale#enabled = 1
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tagbar#enabled = 1
let g:airline_skip_empty_sections = 1

"*****************************************************************************
"" Abbreviations — CONSERVADAS
"*****************************************************************************
cnoreabbrev W! w!
cnoreabbrev Q! q!
cnoreabbrev Qall! qall!
cnoreabbrev Wq wq
cnoreabbrev Wa wa
cnoreabbrev wQ wq
cnoreabbrev WQ wq
cnoreabbrev W w
cnoreabbrev Q q
cnoreabbrev Qall qall

" NERDTree config __DESCARTADO__ (reemplazo: neo-tree.nvim; se conserva la
" intención: toggle con F3, reveal con F2, precedencia de favoritos y tamaño
" de ventana 50).
let g:NERDTreeChDirMode=2
let g:NERDTreeIgnore=['node_modules','\.rbc$', '\~$', '\.pyc$', '\.db$', '\.sqlite$', '__pycache__']
let g:NERDTreeSortOrder=['^__\.py$', '\/$', '*', '\.swp$', '\.bak$', '\~$']
let g:NERDTreeShowBookmarks=1
let g:nerdtree_tabs_focus_on_files=1
let g:NERDTreeMapOpenInTabSilent = '<RightMouse>'
let g:NERDTreeWinSize = 50
set wildignore+=*/tmp/*,*.so,*.swp,*.zip,*.pyc,*.db,*.sqlite,*node_modules/
nnoremap <silent> <F2> :NERDTreeFind<CR>
nnoremap <silent> <F3> :NERDTreeToggle<CR>

" grep.vim __DESCARTADO__ (nativo: :grep + quickfix; rg ya define grepprg).

" terminal emulation — CONSERVADO
nnoremap <silent> <leader>sh :terminal<CR>

"*****************************************************************************
"" Commands — CONSERVADOS
"*****************************************************************************
command! FixWhitespace :%s/\s\+$//e

"*****************************************************************************
"" Functions — CONSERVADAS
"*****************************************************************************
if !exists('*s:setupWrapping')
  function s:setupWrapping()
    set wrap
    set wm=2
    set textwidth=79
  endfunction
endif

"*****************************************************************************
"" Autocmd Rules — CONSERVADAS
"*****************************************************************************
augroup vimrc-sync-fromstart
  autocmd!
  autocmd BufEnter * :syntax sync maxlines=200
augroup END

augroup vimrc-remember-cursor-position
  autocmd!
  autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g`\"" | endif
augroup END

augroup vimrc-wrapping
  autocmd!
  autocmd BufRead,BufNewFile *.txt call s:setupWrapping()
augroup END

augroup vimrc-make-cmake
  autocmd!
  autocmd FileType make setlocal noexpandtab
  autocmd BufNewFile,BufRead CMakeLists.txt setlocal filetype=cmake
augroup END

set autoread

"*****************************************************************************
"" Mappings — CONSERVADOS (los de plugins descartados van marcados)
"*****************************************************************************

"" Split
noremap <Leader>h :<C-u>split<CR>
noremap <Leader>v :<C-u>vsplit<CR>

"" Git (fugitive sobrevive: se conserva fiel)
noremap <Leader>ga :Gwrite<CR>
noremap <Leader>gc :Git commit --verbose<CR>
noremap <Leader>gsh :Git push<CR>
noremap <Leader>gll :Git pull<CR>
noremap <Leader>gs :Git<CR>
noremap <Leader>gb :Git blame<CR>
noremap <Leader>gd :Gvdiffsplit<CR>
noremap <Leader>gr :GRemove<CR>

" session management __DESCARTADO__ (vim-session): <leader>so/ss/sd/sc

"" Tabs
nnoremap <Tab> gt
nnoremap <S-Tab> gT
nnoremap <silent> <S-t> :tabnew<CR>

"" Set working directory
nnoremap <leader>. :lcd %:p:h<CR>

"" Opens an edit command with the path of the currently edited file filled in
noremap <Leader>e :e <C-R>=expand("%:p:h") . "/" <CR>

"" Opens a tab edit command with the path of the currently edited file filled
noremap <Leader>te :tabe <C-R>=expand("%:p:h") . "/" <CR>

"" fzf.vim __DESCARTADO__ (reemplazo: telescope + fzf-lua; se conserva la
"" intención: buffers, archivos y historial con la misma pattern de rg).
set wildmode=list:longest,list:full
set wildignore+=*.o,*.obj,.git,*.rbc,*.pyc,__pycache__
let $FZF_DEFAULT_COMMAND =  "find * -path '*/\.*' -prune -o -path 'node_modules/**' -prune -o -path 'target/**' -prune -o -path 'dist/**' -prune -o  -type f -print -o -type l -print 2> /dev/null"

" The Silver Searcher __DESCARTADO__ (no empaquetado en Tumbleweed; rg cubre)

" ripgrep — CONSERVADO (rg ya instalado, 15.2.0)
if executable('rg')
  let $FZF_DEFAULT_COMMAND = 'rg --files --hidden --follow --glob "!.git/*"'
  set grepprg=rg\ --vimgrep
endif

cnoremap <C-P> <C-R>=expand("%:p:h") . "/" <CR>
nnoremap <silent> <leader>b :Buffers<CR>
nnoremap <silent> <leader>e :FZF -m<CR>
nmap <leader>y :History:<CR>

" snippets __DESCARTADO__ (UltiSnips muerto por has('python3')==0; reemplazo:
" LuaSnip; triggers tab/tab/c-b y edición en split como intención).

" ale __DESCARTADO__ (reemplazo: nvim-lint + conform.nvim + vim.diagnostic
" nativo; los linters declarados por lenguaje se migran en T5, no se pierden).

" Tagbar __DESCARTADO__ (F4; reemplazo: LSP nativo vim.lsp.buf.references)

" Disable visualbell — CONSERVADO
set noerrorbells visualbell t_vb=
if has('autocmd')
  autocmd GUIEnter * set visualbell t_vb=
endif

"" Copy/Paste/Cut — CONSERVADO
if has('unnamedplus')
  set clipboard=unnamed,unnamedplus
endif

noremap YY "+y<CR>
noremap <leader>p "+gP<CR>
noremap XX "+x<CR>

if has('macunix')
  " pbcopy for OSX copy/paste
  vmap <C-x> :!pbcopy<CR>
  vmap <C-c> :w !pbcopy<CR><CR>
endif

"" Buffer nav
noremap <leader>z :bp<CR>
noremap <leader>q :bp<CR>
noremap <leader>x :bn<CR>
noremap <leader>w :bn<CR>

"" Close buffer
noremap <leader>c :bd<CR>

"" Clean search (highlight)
nnoremap <silent> <leader><space> :noh<cr>

"" Switching windows
noremap <C-j> <C-w>j
noremap <C-k> <C-w>k
noremap <C-l> <C-w>l
noremap <C-h> <C-w>h

"" Vmap for maintain Visual Mode after shifting > and <
vmap < <gv
vmap > >gv

"" Move visual block
vnoremap J :m '>+1<CR>gv=gv
vnoremap K :m '<-2<CR>gv=gv

"" Open current line on GitHub __DESCARTADO__ (vim-rhubarb): <Leader>o

"*****************************************************************************
"" Custom configs por lenguaje
"*****************************************************************************

" go — CONSERVADO (reemplazo: nvim-go, fork mantenido; la experiencia se
" preserva: build/test por filetype, formateo con goimports, highlighting,
" alternados y declaración de símbolos).
function! s:build_go_files()
  let l:file = expand('%')
  if l:file =~# '^\f\+_test\.go$'
    call go#test#Test(0, 1)
  elseif l:file =~# '^\f\+\.go$'
    call go#cmd#Build(0)
  endif
endfunction

let g:go_list_type = "quickfix"
let g:go_fmt_command = "goimports"
let g:go_fmt_fail_silently = 1

let g:go_highlight_types = 1
let g:go_highlight_fields = 1
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_operators = 1
let g:go_highlight_build_constraints = 1
let g:go_highlight_structs = 1
let g:go_highlight_generate_tags = 1
let g:go_highlight_space_tab_error = 0
let g:go_highlight_array_whitespace_error = 0
let g:go_highlight_trailing_whitespace_error = 0
let g:go_highlight_extra_types = 1

autocmd BufNewFile,BufRead *.go setlocal noexpandtab tabstop=4 shiftwidth=4 softtabstop=4

augroup completion_preview_close
  autocmd!
  if v:version > 703 || v:version == 703 && has('patch598')
    autocmd CompleteDone * if !&previewwindow && &completeopt =~ 'preview' | silent! pclose | endif
  endif
augroup END

augroup go

  au!
  au Filetype go command! -bang A call go#alternate#Switch(<bang>0, 'edit')
  au Filetype go command! -bang AV call go#alternate#Switch(<bang>0, 'vsplit')
  au Filetype go command! -bang AS call go#alternate#Switch(<bang>0, 'split')
  au Filetype go command! -bang AT call go#alternate#Switch(<bang>0, 'tabe')

  au FileType go nmap <Leader>dd <Plug>(go-def-vertical)
  au FileType go nmap <Leader>dv <Plug>(go-doc-vertical)
  au FileType go nmap <Leader>db <Plug>(go-doc-browser)

  au FileType go nmap <leader>r  <Plug>(go-run)
  au FileType go nmap <leader>t  <Plug>(go-test)
  au FileType go nmap <Leader>gt <Plug>(go-coverage-toggle)
  au FileType go nmap <Leader>i <Plug>(go-info)
  au FileType go nmap <silent> <Leader>l <Plug>(go-metalinter)
  au FileType go nmap <C-g> :GoDecls<cr>
  au FileType go nmap <leader>dr :GoDeclsDir<cr>
  au FileType go imap <C-g> <esc>:<C-u>GoDecls<cr>
  au FileType go imap <leader>dr <esc>:<C-u>GoDeclsDir<cr>
  au FileType go nmap <leader>rb :<C-u>call <SID>build_go_files()<CR>

augroup END

" html — CONSERVADO (2 espacios)
autocmd Filetype html setlocal ts=2 sw=2 expandtab

" javascript — CONSERVADO (sintaxis la da treesitter; indentado se preserva)
let g:javascript_enable_domhtmlcss = 1

augroup vimrc-javascript
  autocmd!
  autocmd FileType javascript setl tabstop=4|setl shiftwidth=4|setl expandtab softtabstop=4
augroup END

" lua — el archivo original no declaraba nada (vacío)

" php — CONSERVADO como intención: el servidor phpactor sobrevive y el LSP lo
" pone Neovim (vim.lsp). Las acciones de navegación/refactor se mapean al LSP.
nmap <Leader>u :call phpactor#UseAdd()<CR>
nmap <Leader>mm :call phpactor#ContextMenu()<CR>
nmap <Leader>nn :call phpactor#Navigate()<CR>
nmap <Leader>oo :call phpactor#GotoDefinition()<CR>
nmap <Leader>oh :call phpactor#GotoDefinition('hsplit')<CR>
nmap <Leader>ov :call phpactor#GotoDefinition('vsplit')<CR>
nmap <Leader>ot :call phpactor#GotoDefinition('tabnew')<CR>
nmap <Leader>K :call phpactor#Hover()<CR>
nmap <Leader>tt :call phpactor#Transform()<CR>
nmap <Leader>cc :call phpactor#ClassNew()<CR>
nmap <silent><Leader>ee :call phpactor#ExtractExpression(v:false)<CR>
vmap <silent><Leader>ee :<C-U>call phpactor#ExtractExpression(v:true)<CR>
vmap <silent><Leader>em :<C-U>call phpactor#ExtractMethod()<CR>

" python — CONSERVADO (indentado y columna; jedi-vim __DESCARTADO__ por
" has('python3')==0; el destino es pyright/ruff + LSP nativo)
augroup vimrc-python
  autocmd!
  autocmd FileType python setlocal expandtab shiftwidth=4 tabstop=8 colorcolumn=79
      \ formatoptions+=croq softtabstop=4
      \ cinwords=if,elif,else,for,while,try,except,finally,def,class,with
augroup END

let g:jedi#popup_on_dot = 0
let g:jedi#goto_assignments_command = "<leader>g"
let g:jedi#goto_definitions_command = "<leader>d"
let g:jedi#documentation_command = "K"
let g:jedi#usages_command = "<leader>n"
let g:jedi#rename_command = "<leader>r"
let g:jedi#show_call_signatures = "0"
let g:jedi#completions_command = "<C-Space>"
let g:jedi#smart_auto_mappings = 0

" vim-airline virtualenv __DESCARTADO__ (junto a airline; intención: mostrar
" el virtualenv activo en la statusline)
let g:airline#extensions#virtualenv#enabled = 1

let python_highlight_all = 1

" rust — __DESCARTADO__ (vim-racer deprecado y rust.vim exige Syntastic;
" destino: rust-analyzer + LSP nativo. Las teclas gd/gs/gx eran def de racer;
" el LSP nativo las provee con la misma ergonomía sobre el símbolo bajo cursor)
au FileType rust nmap gd <Plug>(rust-def)
au FileType rust nmap gs <Plug>(rust-def-split)
au FileType rust nmap gx <Plug>(rust-def-vertical)
au FileType rust nmap <leader>gd <Plug>(rust-doc)

" typescript — __DESCARTADO__ (yats.vim; sintaxis la da treesitter, LSP nativo
" lo da ts_ls/vtsls)
let g:yats_host_keyword = 1

" svelte — __DESCARTADO__ (vim-svelte-plugin; destino: LSP svelte nativo)
let g:vim_svelte_plugin_load_full_syntax = 1

" vuejs — __DESCARTADO__ (posva/vim-vue y vim-vue-plugin; sintaxis treesitter,
" LSP vue)
let g:vue_disable_pre_processors=1
let g:vim_vue_plugin_load_full_syntax = 1

"============================================================================
" MANIFIESTO DE SUPERVIVENCIA (comentado — NO es una lista Plug ejecutable)
"============================================================================
" Reemplazo del gestor:  vim-plug -> lazy.nvim (bootstrap por
" scripts/09-setup-nvim.sh, patrón de 08-setup-zsh.sh)
"
" 45 plugins del init.vim original -> 16 familias, cero muertos:
"   CONSERVADOS  : badwolf (tema), fugitive (git), emmet-vim (web)
"   REEMPLAZADOS : nerdtree->neo-tree.nvim, commentary->mini.comment,
"                  airline->lualine, gitgutter->gitsigns,
"                  delimitMate->nvim-autopairs, ultisnips->LuaSnip(+snippets),
"                  vim-go->nvim-go, ale->nvim-lint+conform.nvim,
"                  fzf/fzf.vim->telescope+fzf-lua, phpactor (plugin)->phpactor
"                  (servidor + LSP nativo)
"   INFRA LSP    : mason.nvim (servidores), nvim-cmp (completado),
"                  nvim-treesitter (sintaxis/highlight)
"
" Descartados sin reemplazo y su motivo (detalle: odd/tasks/nvim-nativo.md):
"   nerdtree-tabs (neo-tree lo cubre), grep.vim (:grep nativo), CSApprox
"   (truecolor), tagbar (LSP nativo), indentLine (fillchars nativo),
"   vim-bootstrap-updater (artefacto del generador), rhubarb (solo GBrowse),
"   vimproc (vim.system nativo), vim-misc (inútil), vim-session (mksession
"   nativo), vim-snippets (luasnip), vim-css3/javascript/typescript-vim/yats/
"   posva-vue/vue-plugin (treesitter), vim-coloresque/haml (sin actividad),
"   vim-lua-ftplugin (nativo), vim-lua-inspect (provider lua), jedi-vim
"   (has('python3')==0), vim-php-cs-fixer (conform.nvim), requirements.txt.vim
"   (conform.nvim), vim-racer/rust.vim (rust-analyzer), async.vim (vim.system),
"   vim-lsp (vim.lsp.config nativo), asyncomplete(.lsp) (nvim-cmp),
"   vim-svelte-plugin (LSP svelte)
"
" REFERENCIA — archivo nunca ejecutado por Neovim.