# Sample .bashrc for SUSE Linux
# Copyright (c) SUSE Software Solutions Germany GmbH

# There are 3 different types of shells in bash: the login shell, normal shell
# and interactive shell. Login shells read ~/.profile and interactive shells
# read ~/.bashrc; in our setup, /etc/profile sources ~/.bashrc - thus all
# settings made here will also take effect in a login shell.
#
# NOTE: It is recommended to make language settings in ~/.profile rather than
# here, since multilingual X sessions would not work properly if LANG is over-
# ridden in every subshell.

test -s ~/.alias && . ~/.alias || true

# ---------------------------------------------------------------------------
# Entorno y PATH
# ---------------------------------------------------------------------------
# Mismas rutas que ~/.zshrc (que es el shell por defecto): si acá faltan, un
# bash interactivo se queda sin brew, pi y gentle-ai.
export PATH="${HOME}/.gentle-ai/bin:${HOME}/.pi/agent/bin:${HOME}/.local/bin:${HOME}/.opencode/bin:${PATH}"

# Homebrew: brew, gentle-ai y engram viven en /home/linuxbrew/.linuxbrew.
# La guarda mantiene el arranque del shell aunque brew no esté instalado.
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv bash)"
fi

export EDITOR="nvim"
export VISUAL="nvim"

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias grep='grep --color=auto'
alias update='sudo zypper dup'
alias installpkg='sudo zypper in'
alias searchpkg='zypper se'

case $- in
  *i*) ;;
    *) return ;;
esac

if [ -f /etc/bashrc ]; then
  source /etc/bashrc
fi