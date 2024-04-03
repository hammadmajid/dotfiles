# Lines configured by zsh-newuser-install
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=5000
setopt autocd extendedglob notify
unsetopt beep
bindkey -v
# End of lines configured by zsh-newuser-install
# The following lines were added by compinstall
zstyle :compinstall filename '/home/hammad/.zshrc'

autoload -Uz compinit
compinit
# End of lines added by compinstall

alias hx="helix"
alias ls="exa --icons --group-directories-first"
alias gg="lazygit"

eval "$(starship init zsh)"
eval "$(zoxide init --cmd cd  zsh)"

