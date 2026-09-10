# Red/yellow lines for failed or skipped pairs. Args: failed skipped error (any may be empty).
function _drive_attention
    set -l n (set_color normal)
    if test -n "$argv[1]"
        printf '%s󰧠 failed: %s' (set_color red) $argv[1]
        test -n "$argv[3]"; and printf ' · %s' $argv[3]
        printf '%s\n' $n
    end
    if test -n "$argv[2]"
        printf '%s󰨹 skipped, folder missing: %s%s\n' (set_color yellow) $argv[2] $n
    end
end
