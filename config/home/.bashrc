# ~/.bashrc

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