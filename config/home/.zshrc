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

# Palabras de Ctrl+W: agrega ":" (tokens tipo PATH) y "@" (user@host).
WORDCHARS+=":@"

# ---------------------------------------------------------------------------
# Colores
# ---------------------------------------------------------------------------
# /etc/zshrc de openSUSE define LS_COLORS solo si existe ~/.dir_colors o
# /etc/DIR_COLORS; no existe ninguno acá y el list-colors del completado
# quedaba sin colores. dircolors sin base exporta la tabla por defecto.
#
# Va antes de la sección de autocompletado a propósito: el zstyle de list-colors
# expande ${(s.:.)LS_COLORS} al momento del parseo y la primera definición
# gana, así que definir la tabla después dejaría el menú sin color igual.
if [[ -z ${LS_COLORS:-} ]] && (( $+commands[dircolors] )); then
  eval "$(dircolors -b)"
fi

# ---------------------------------------------------------------------------
# Autocompletado
# ---------------------------------------------------------------------------
ZSH_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
# El 2>/dev/null evita que un directorio de cache no escribible rompa el
# arranque del shell: compinit avisa y sigue funcionando sin dump.
mkdir -p "${ZSH_CACHE_DIR}" 2>/dev/null

autoload -Uz compinit
compinit -d "${ZSH_CACHE_DIR}/zcompdump"

# zypper y wofi solo traen completions de bash (rpm -ql zypper →
# /usr/share/bash-completion/completions/zypper). bashcompinit emula el
# dispatch bash para que completen en zsh. Cuesta ~0.5 ms; carga la
# completion en el primer TAB.
# Tiene que ir DESPUÉS de compinit: su wrapper de "complete" llama a compdef.
autoload -Uz bashcompinit
bashcompinit

# El completado de git es de los más lentos: se desactivan subcomandos
# internos que nadie completa a mano.
for _git_subcmd in archive daemon fast-export fast-import filter-branch fsck http-fetch http-push imap-send mailinfo merge-base notes receive-pack request-pull send-email shell show-index svn web--browse; do
  compdef -d "git-${_git_subcmd}" 2>/dev/null || true
done
unset _git_subcmd

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

# Substring-search del historial (acepta comodines): Ctrl+↑ / Ctrl+↓.
# Foot no expone la secuencia en terminfo; se usa la convención xterm.
autoload -Uz up-line-or-history-incremental-pattern-search down-line-or-history-incremental-pattern-search
zle -N up-line-or-history-incremental-pattern-search
zle -N down-line-or-history-incremental-pattern-search
bindkey '^[[1;5A' up-line-or-history-incremental-pattern-search
bindkey '^[[1;5B' down-line-or-history-incremental-pattern-search

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
  # Historial primero, completado como respaldo: la sugerencia sale sin tocar
  # el disco y aun así ofrece lo que no está en el historial.
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  source "${ZSH_PLUGINS_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# ---------------------------------------------------------------------------
# Aliases
# ---------------------------------------------------------------------------
# Sistema de archivos
# Color en ls: la tabla LS_COLORS ya se definió en la sección de colores.
alias ls='ls --color=auto'
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
# Prompt (con integración nativa de git via vcs_info)
# ---------------------------------------------------------------------------
# vcs_info muestra repo/rama y cambios pendientes dentro del prompt. Requiere
# PROMPT_SUBST para que ${vcs_info_msg_0_} se expanda en cada render.
setopt PROMPT_SUBST

autoload -Uz vcs_info
# Escaneo del estado sucio: * = cambios sin preparar, + = cambios preparados.
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' unstagedstr ' *'
zstyle ':vcs_info:*' stagedstr ' +'
# %r = repo, %b = rama, %u/%c = marcas de cambios.
zstyle ':vcs_info:git:*' formats ' [%F{cyan}%r%f:%F{magenta}%b%f%F{yellow}%u%c%f]'
# Formato durante merge/rebase (%a = acción en curso).
zstyle ':vcs_info:git:*' actionformats ' [%F{cyan}%r%f:%F{magenta}%b%f%F{red}|%a%f]'

# add-zsh-hook en vez de definir precmd() a mano: convive con otros hooks
# precmd (p. ej. el que registra la integración de fzf más abajo).
autoload -Uz add-zsh-hook
add-zsh-hook precmd vcs_info

# user@host + ruta + segmento git (solo dentro de un repo) + %/#.
PROMPT='%F{cyan}%n@%m%f %F{green}%~%f${vcs_info_msg_0_} %# '

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
