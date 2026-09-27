# ~/.zshrc — configuración de zsh (zsh nativo, sin Oh My Zsh)
#
# Este archivo es la fuente de verdad. scripts/04-setup-dotfiles.sh lo COPIA a
# $HOME con "cp -a": no es un symlink, no hay enlace con este repo. Los
# cambios hechos directamente en ~/.zshrc se pisan en la próxima aplicación de
# dotfiles, así que hay que editar SIEMPRE este archivo.

# ---------------------------------------------------------------------------
# Editor
# ---------------------------------------------------------------------------
export EDITOR="nvim"
export VISUAL="nvim"

# ---------------------------------------------------------------------------
# Historial
# ---------------------------------------------------------------------------
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=100000   # órdenes vivas en memoria
SAVEHIST=100000   # órdenes persistidas en HISTFILE

# SHARE_HISTORY ya implica APPEND_HISTORY e INC_APPEND_HISTORY: declarar los
# tres sería redundante. SHARE_HISTORY es la opción moderna porque comparte el
# historial entre todas las sesiones de terminal abiertas.
setopt SHARE_HISTORY
# Sólo descarta duplicados consecutivos (el último gana).
setopt HIST_IGNORE_DUPS
# No persiste duplicados en el archivo de historial.
setopt HIST_SAVE_NO_DUPS
# No guarda las órdenes que empiezan con un espacio (úsalo para comandos
# sensibles que no quieres en el historial).
setopt HIST_IGNORE_SPACE
# Quita espacios redundantes antes de guardar la orden.
setopt HIST_REDUCE_BLANKS
# Muestra la orden ya expandida y pide confirmar antes de ejecutarla.
setopt HIST_VERIFY

# HIST_IGNORE_ALL_DUPS queda desactivado a propósito:
# setopt HIST_IGNORE_ALL_DUPS
# Borra del archivo de historial los duplicados antiguos de forma permanente y
# degrada la búsqueda en sesiones largas de un power user (perdés los comandos
# repetidos que querés recuperar). HIST_IGNORE_DUPS + HIST_SAVE_NO_DUPS cubren
# el caso común sin destruir el historial.

# ---------------------------------------------------------------------------
# Opciones generales
# ---------------------------------------------------------------------------
setopt auto_cd

# ---------------------------------------------------------------------------
# Autocompletado
# ---------------------------------------------------------------------------
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
# El 2>/dev/null evita que un directorio de cache no escribible rompa el
# arranque del shell: compinit avisa y sigue funcionando sin dump.
mkdir -p "${ZSH_CACHE_DIR}" 2>/dev/null

autoload -Uz compinit
compinit -d "${ZSH_CACHE_DIR}/zcompdump"

# Menú navegable con flechas y tabulador.
zstyle ':completion:*' menu select
# Reglas de coincidencia, en orden de preferencia: ignorar mayúsculas, buscar
# por segmentos en rutas y en nombres con punto, guion o guion bajo, y
# tolerar el prefijo ya escrito al final.
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*' \
  'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
# Nombre de grupo vacío: cada entrada muestra su propia descripción.
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'

# ---------------------------------------------------------------------------
# Keybinds
# ---------------------------------------------------------------------------
# "-e" restaura los atajos de emacs por defecto. Tiene que ir PRIMERO: bindkey
# reemplaza el widget de la tecla que toca, y el resto de la sección necesita
# una base conocida y reproducible.
bindkey -e

# Búsqueda incremental en el historial: se escribe un fragmento y las flechas
# recorren sólo las órdenes que empiezan por él.
#
# foot, xterm y alacritty envían "\eOA" y "\eOB" cuando la terminal está en
# modo aplicación de cursor (infocmp foot -> kcuu1=\EOA). Bindear únicamente
# "\e[A" es un no-op silencioso: el widget queda registrado pero la tecla real
# nunca lo dispara. Por eso se declaran las dos variantes.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '\e[A'  up-line-or-beginning-search
bindkey '\eOA' up-line-or-beginning-search
bindkey '\e[B'  down-line-or-beginning-search
bindkey '\eOB' down-line-or-beginning-search

# Home/End en las tres variantes que usan los terminales actuales: modo
# aplicación de cursor (\eOH / \eOF), modo normal CSI (\e[H / \e[F) y la
# variante antigua de xterm (\e[1~ / \e[4~).
bindkey '\e[H'  beginning-of-line
bindkey '\eOH'  beginning-of-line
bindkey '\e[1~' beginning-of-line
bindkey '\e[F'  end-of-line
bindkey '\eOF'  end-of-line
bindkey '\e[4~' end-of-line

# ---------------------------------------------------------------------------
# fzf
# ---------------------------------------------------------------------------
# fzf trae su propia integración (fzf --zsh): búsqueda inversa con Ctrl-R y
# widget de ficheros. Se carga después de la sección de keybinds para que su
# tabla de atajos se aplique sobre una base ya definida.
# La guarda es obligatoria: en una máquina sin fzf el shell tiene que arrancar
# igual, sólo que sin la búsqueda incremental del historial.
if (( $+commands[fzf] )); then
  source <(fzf --zsh)
fi

# ---------------------------------------------------------------------------
# Plugins opcionales
# ---------------------------------------------------------------------------
# Los instala scripts/08-setup-zsh.sh en el directorio de datos del usuario.
#
# El orden de carga es estricto: cada plugin envuelve los widgets de ZLE del
# anterior. Por eso estos bloques usan "if ... fi" y NO "[[ ... ]] && source":
# con "&&" el estado de salida del sourceo queda como último estado del shell y
# rompe scripts que encadenan condiciones.
ZSH_PLUGINS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/zsh/plugins"

# Sugerencias en línea mientras se escribe (comportamiento tipo fish).
if [[ -r "${ZSH_PLUGINS_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=242'
  source "${ZSH_PLUGINS_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
# Sistema de archivos
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias c='clear'

# Búsqueda y paquetes (openSUSE usa zypper)
alias grep='grep --color=auto'
alias update='sudo zypper dup'
alias installpkg='sudo zypper in'
alias searchpkg='zypper se'

# Git: 'ga' va SIN punto a propósito. "git add ." mete de más cualquier archivo
# sin trackear (.env, claves privadas, notas). Para eso está 'gaa'.
alias ga='git add'
alias gaa='git add --all'
alias gst='git status'
alias gco='git checkout'
alias gcam='git commit --all --message'
# OJO con 'gcam': el mensaje va como argumento pelado, SIN "-m".
#   bien:  gcam "fix: mensaje"
#   mal:   gcam -m "fix: mensaje"   ->  git commit --all --message -m "..."
#           que git lee como mensaje="-m" y "fix: mensaje" como rutaspec.

# ---------------------------------------------------------------------------
# Prompt
# ---------------------------------------------------------------------------
PROMPT='%F{cyan}%n@%m%f %F{green}%~%f %# '

# ---------------------------------------------------------------------------
# zsh-syntax-highlighting — tiene que ser el ÚLTIMO sourceo del archivo
# ---------------------------------------------------------------------------
# Este plugin envuelve los widgets de ZLE definidos antes que él (los binds de
# flechas, los de fzf y los del plugin de sugerencias) para resaltarlos. Si se
# carga antes de tiempo, el resaltado queda incompleto sin ningún aviso.
#
# Por eso va literalmente al final, y no "al final de su bloque": aunque hoy los
# aliases y el prompt de arriba no definan widgets, cualquier línea que se agregue
# debajo rompería el resaltado en silencio. La guarda mantiene el arranque del
# shell aunque el plugin no esté instalado.
if [[ -r "${ZSH_PLUGINS_DIR}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
  source "${ZSH_PLUGINS_DIR}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi
