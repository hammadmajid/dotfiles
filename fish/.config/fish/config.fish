# Disable fish's default greeting
function fish_greeting
end

# Enviroment variables
set -Ux EDITOR hx # package: helix

# Aliases for commonly used commands
# ----------------------------------
#
# To use the default ls run `\ls`
# Package: eza
alias ls="eza --icons --group-directories-first"
alias lsa="eza --icons --group-directories-first --all"
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
# Package: opencode
alias oc=opencode
#
# Package: zellij
alias zj=zellij
#
# exit
alias :q=exit
alias :wq=exit

#
alias cdd="cd ~/Code"
alias shx="sudo hx"
#
# history grep alias
alias hg="history | rg"

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
atuin init fish | sed "s/-k up/up/g" | source

# Enable transient prompt for starship
# See: https://starship.rs/advanced-config/#transientprompt-and-transientrightprompt-in-fish
function starship_transient_prompt_func
    starship module character
end
starship init fish | source
enable_transience

# pnpm
set -gx PNPM_HOME "/home/bine/.local/share/pnpm"
if not string match -q -- "$PNPM_HOME/bin" $PATH
    set -gx PATH "$PNPM_HOME/bin" $PATH
end
# pnpm end


# Added by Antigravity CLI installer
set -gx PATH "/home/bine/.local/bin" $PATH

# nub
set -gx PATH "$HOME/.nub/bin" $PATH
