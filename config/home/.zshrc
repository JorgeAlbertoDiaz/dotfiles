# ~/.zshrc

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

# Autocompletado y billenas (Zsh estándar)
autoload -Uz compinit
compinit
setopt auto_cd
setopt hist_ignore_all_dups

# Prompt básico
PROMPT='%F{cyan}%n@%m%f %F{green}%~%f %# '