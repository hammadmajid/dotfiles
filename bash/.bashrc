#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias grep='grep --color=auto'
PS1='[\u@\h \W]\$ '

alias hx=helix

# opencode
export PATH=/home/bine/.opencode/bin:$PATH

# Vite+ bin (https://viteplus.dev)
. "$HOME/.vite-plus/env"
export PATH="$PATH:$HOME/flutter/bin"
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/tools:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"


# Added by Antigravity CLI installer
export PATH="/home/bine/.local/bin:$PATH"
