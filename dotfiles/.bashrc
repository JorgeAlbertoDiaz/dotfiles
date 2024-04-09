#    _               _
#   | |__   __ _ ___| |__  _ __ ___
#   | '_ \ / _` / __| '_ \| '__/ __|
#  _| |_) | (_| \__ \ | | | | | (__
# (_)_.__/ \__,_|___/_| |_|_|  \___|
# -----------------------------------------------------
# ~/.bashrc
# -----------------------------------------------------

# If not running interactively, don't do anything
# Si no se ejecuta interactivamente, no hace nada
[[ $- != *i* ]] && return
PS1='[\u@\h \W]\$ '

# Define el editor
export EDITOR=nvim

# -----------------------------------------------------
# ALIAS
# -----------------------------------------------------

alias c='clear'
alias nf='neofetch'
alias pf='pfetch'
alias ls='eza -a --icons'
alias ll='eza -al --icons'
alias lt='eza -a --tree --level=1 --icons'
alias shutdown='systemctl poweroff'
alias v='$EDITOR'
alias vim='$EDITOR'
alias ts='~/.config/scripts/snapshot.sh'
alias matrix='cmatrix'
alias wifi='nmtui'
# alias od='~/private/onedrive.sh'
alias rw='~/.config/waybar/reload.sh'
alias winclass="xprop | grep 'CLASS'"
alias dot="cd ~/dotfiles"
alias cleanup='~/.config/scripts/cleanup.sh'
alias gtkconfig='nwg-look'

# -----------------------------------------------------
# GIT
# -----------------------------------------------------

# alias gs="git status"
# alias ga="git add"
# alias gc="git commit -m"
# alias gp="git push"
# alias gpl="git pull"
# alias gst="git stash"
# alias gsp="git stash; git pull"
# alias gcheck="git checkout"
# alias gcredential="git config credential.helper store"

# -----------------------------------------------------
# SCRIPTS
# -----------------------------------------------------

alias gr='python ~/.config/scripts/growthrate.py'
alias ChatGPT='python ~/mychatgpt/mychatgpt.py'
alias chat='python ~/mychatgpt/mychatgpt.py'
alias ascii='~/.config/scripts/figlet.sh'

# -----------------------------------------------------
# VIRTUAL MACHINE
# -----------------------------------------------------

alias vm='~/private/launchvm.sh'
alias lg='~/.config/scripts/looking-glass.sh'

# -----------------------------------------------------
# RESOLUCIONES DE PANTALLAS
# -----------------------------------------------------

# Qtile
# alias res1='xrandr --output DisplayPort-0 --mode 2560x1440 --rate 120'
# alias res2='xrandr --output DisplayPort-0 --mode 1920x1080 --rate 120'

export PATH="/usr/lib/ccache/bin/:$PATH"

# -----------------------------------------------------
# INICIA STARSHIP
# -----------------------------------------------------
eval "$(starship init bash)"

# -----------------------------------------------------
# PYWAL
# -----------------------------------------------------
cat ~/.cache/wal/sequences

# -----------------------------------------------------
# PFETCH si estas en wm
# -----------------------------------------------------
echo ""
if [[ $(tty) == *"pts"* ]]; then
	pfetch
else
	if [ -f /bin/hyprctl ]; then
		echo "Inicia Hyprland con el comando Hyprland"
	fi
fi

# Solución al error: "signing failed: Inappropriate ioctl for device"
export GPG_TTY=$(tty)
