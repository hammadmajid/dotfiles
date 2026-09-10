# One-line Drive sync summary for `drive status`, plus attention lines when something is off.
function _drive_line
    set -l f (_drive_facts)
    set -l state; set -l color; set -l word; set -l next; set -l timer; set -l watch; set -l conflicts; set -l failed; set -l skipped; set -l error
    for kv in $f
        set -l p (string split -m1 = $kv)
        set $p[1] $p[2]
    end
    set -l dim (set_color --dim)
    set -l n (set_color normal)

    set -l icon '󱋌'
    switch $color
        case red; set icon '󰧠'
        case yellow; set icon '󰨹'
        case blue; set icon '󱋖'
    end
    set -l timer_color green; test $timer = active; or set timer_color red
    set -l watch_color green; test $watch = active; or set watch_color red
    set -l conf_color green; test $conflicts -gt 0; and set conf_color yellow

    printf '%s%s %s%s' (set_color $color) $icon $word $n
    printf '  %s󰔛 %snext %s%s' (set_color $timer_color) $dim (set_color $timer_color) $next
    printf '  %s󰛐 %swatch %s%s' (set_color $watch_color) $dim (set_color $watch_color) (test $watch = active; and echo on; or echo off)
    printf '  %s󰩌 %sconflicts %s%s%s\n' (set_color $conf_color) $dim (set_color $conf_color) $conflicts $n
    _drive_attention $failed $skipped $error
end
