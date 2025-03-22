# Disable fish's default greeting
function fish_greeting
end

# Enviroment variables
set -Ux EDITOR hx # package: helix

# Aliases for commonly used commands
# ----------------------------------
#
# If you want to use the default ls run `\ls`
# Package: exa
alias ls="exa --icons --group-directories-first --all"
#
# Package: lazygit
alias gg="lazygit"
#
# Package: bottom
alias btm="btm --dot_marker"
#
# Best used when piping into this alias
# Package: xclip
alias copy="xclip -selection clipboard"
#
# Package: yazi
alias yy=yazi
#
# Package: zed
alias zz="zed ."

# exit
alias :q=exit
alias :wq=exit

#
alias cdd="cd ~/Code"
alias shx="sudo hx"
#
# history grep alias
alias hg="history | rg"
#
# GitHub Copilot
alias ai="gh copilot suggest -t"

# Shell integration
# ------------------
#
# To use regular cd run it using `\cd`
# Package: zoxide
zoxide init --cmd cd fish | source
#
# Package: starship
starship init fish | source
#
# Package: mise
mise activate fish | source
#
# Package: atuin
atuin init fish | source
# Package: Zellij
if status is-interactive
    eval (zellij setup --generate-auto-start fish | string collect)
end

# pnpm
set -gx PNPM_HOME "/home/bine/.local/share/pnpm"
if not string match -q -- $PNPM_HOME $PATH
    set -gx PATH "$PNPM_HOME" $PATH
end
# pnpm end

# Enable transient prompt for starship
# See: https://starship.rs/advanced-config/#transientprompt-and-transientrightprompt-in-fish
function starship_transient_prompt_func
    starship module character
end
starship init fish | source
enable_transience

# Enable 1Password CLI plugins
source /home/bine/.config/op/plugins.sh
