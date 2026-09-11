function sys --description 'System and Drive sync report card as an aligned grid (sys -v for detail)'
    set -l verbose 0
    contains -- -v $argv; and set verbose 1

    # Everything below reads /proc, /sys and one small file; external commands are kept to a handful
    # so a new shell is not held up. Slow facts come from sys-sample.service via $XDG_RUNTIME_DIR/sys-sample.

    # ---- sampled values (written every minute by sys-sample.service) ----
    set -l cpu -; set -l rx 0; set -l tx 0; set -l updates -; set -l sample_age -1
    set -l net_type ''; set -l net_name offline; set -l failed_sys 0; set -l failed_usr 0
    set -l sample $XDG_RUNTIME_DIR/sys-sample
    test -n "$XDG_RUNTIME_DIR"; or set sample /run/user/(id -u)/sys-sample
    set -l now (date +%s)
    if test -r $sample
        while read -l k v
            switch $k
                case cpu; set cpu $v
                case rx; set rx $v
                case tx; set tx $v
                case updates; test -n "$v"; and set updates $v
                case net_type; set net_type $v
                case net_name; test -n "$v"; and set net_name $v
                case failed_sys; set failed_sys $v
                case failed_usr; set failed_usr $v
                case ts; set sample_age (math $now - $v)
            end
        end < (string replace = ' ' < $sample | psub)
    end
    set -l stale 0
    test $sample_age -lt 0 -o $sample_age -gt 180; and set stale 1

    set -l cells

    # ---- compute ----
    set -l cpu_color green
    test $cpu != -; and set cpu_color (_sys_level $cpu 70 90)
    set -a cells "$cpu_color"\t'󰻠'\tcpu\t"$cpu%"

    set -l mem_total 0; set -l mem_avail 0; set -l swap_total 0; set -l swap_free 0
    while read -l k v rest
        switch $k
            case MemTotal:; set mem_total $v
            case MemAvailable:; set mem_avail $v
            case SwapTotal:; set swap_total $v
            case SwapFree:; set swap_free $v; break
        end
    end < /proc/meminfo
    set -l mem_used (math $mem_total - $mem_avail)
    set -a cells (_sys_level (math -s0 $mem_used x 100 / $mem_total) 75 90)\t'󰍛'\tram\t(_sys_gb $mem_used)G

    set -l swap_used (math $swap_total - $swap_free)
    set -l swap_color green
    if test $swap_total -gt 0
        test $swap_used -gt 0; and set swap_color yellow
        test (math -s0 $swap_used x 100 / $swap_total) -ge 50; and set swap_color red
    end
    set -a cells "$swap_color"\t'󰓡'\tswap\t(_sys_gb $swap_used)G

    set -l temp -
    set -l temp_color green
    for h in /sys/class/hwmon/hwmon*
        read -l name < $h/name
        if test "$name" = coretemp
            read -l raw < $h/temp1_input
            set temp (math -s0 $raw / 1000)
            set temp_color (_sys_level $temp 75 90)
            break
        end
    end
    set -a cells "$temp_color"\t'󰔏'\ttemp\t"$temp°C"

    # ---- storage and network ----
    # one df call: root always; boot partitions only when getting full; external drives whenever mounted
    for line in (df --output=used,size,pcent,target -x tmpfs -x devtmpfs -x efivarfs 2>/dev/null | tail -n +2)
        set -l d (string split -n ' ' $line)
        set -l p (string trim -c % $d[3])
        set -l c (_sys_level $p 80 90)
        switch $d[4]
            case /
                set -a cells "$c"\t'󰋊'\tdisk\t(math -s0 $d[1] / 1048576)/(math -s0 $d[2] / 1048576)G
            case /boot /boot/efi
                test $p -ge 80; and set -a cells "$c"\t'󰋊'\t(string replace / '' $d[4])\t"$p%"
            case '/run/media/*'
                set -a cells "$c"\t'󰋊'\t(string split -r -m1 / $d[4])[2]\t"$p%"
        end
    end

    set -l net_icon '󰖩'; set -l net_label wifi; set -l net_color green
    if test "$net_type" = ethernet
        set net_icon '󰈀'; set net_label eth
    end
    test "$net_name" = offline; and set net_color red
    set -a cells "$net_color"\t$net_icon\t$net_label\t$net_name
    set -a cells green\t'󰌘'\tnet\t"↓"(_sys_rate $rx)" ↑"(_sys_rate $tx)

    # tailscale interface state
    set -l ts_color red; set -l ts_word down
    if test -r /sys/class/net/tailscale0/operstate
        read -l ts_state < /sys/class/net/tailscale0/operstate
        if test "$ts_state" = unknown -o "$ts_state" = up
            set ts_color green; set ts_word up
        end
    end
    set -a cells "$ts_color"\t'󰖂'\ttailscale\t$ts_word

    # ---- power and health ----
    set -l bat /sys/class/power_supply/BAT0
    if test -d $bat
        read -l cap < $bat/capacity
        read -l bstate < $bat/status
        set bstate (string lower $bstate)
        set -l bcolor green
        set -l bicon '󰁹'
        set -l bvalue "$cap%"
        switch $bstate
            case charging
                set bicon '󰂄'
                set bvalue "$cap% charging"
            case discharging
                test $cap -lt 80; and set bicon '󰁾'
                test $cap -lt 40; and set bicon '󰁻'
                test $cap -lt 30; and set bcolor yellow
                test $cap -lt 15; and set bcolor red
                if test -r $bat/charge_now -a -r $bat/current_now
                    read -l cur < $bat/current_now
                    read -l q < $bat/charge_now
                    test $cur -gt 0; and set bvalue "$cap% "(_sys_rel (math -s0 $q x 3600 / $cur))
                end
            case '*'
                set bvalue "$cap% plugged"
        end
        set -a cells "$bcolor"\t$bicon\tbat\t$bvalue
    else
        set -a cells green\t'󰚥'\tpower\tAC
    end

    set -l failed (math $failed_sys + $failed_usr)
    set -l fcolor green
    test $failed -gt 0; and set fcolor yellow
    set -a cells "$fcolor"\t'󰗖'\tfailed\t$failed

    set -l ucolor normal
    test "$updates" != - -a "$updates" != 0; and set ucolor yellow
    set -a cells "$ucolor"\t'󰏖'\tupdates\t$updates

    read -l up rest < /proc/uptime
    set -a cells normal\t'󰅐'\tup\t(_sys_rel (math -s0 $up))

    # ---- Drive sync ----
    set -l state; set -l color; set -l word; set -l next; set -l timer; set -l watch; set -l conflicts; set -l dfailed; set -l skipped; set -l error; set -l inhibit
    for kv in (_drive_facts)
        set -l p (string split -m1 = $kv)
        test $p[1] = failed; and set p[1] dfailed
        set $p[1] $p[2]
    end
    set -l sicon '󱋌'
    switch $color
        case red; set sicon '󰧠'
        case yellow; set sicon '󰨹'
        case blue; set sicon '󱋖'
    end
    set -a cells "$color"\t$sicon\tsync\t$word
    set -l timer_color green; test $timer = active; or begin; set timer_color red; set next off; end
    set -a cells "$timer_color"\t'󰔛'\tnext\t$next
    set -l watch_color green; set -l watch_word on
    test $watch = active; or begin; set watch_color red; set watch_word off; end
    set -a cells "$watch_color"\t'󰛐'\twatch\t$watch_word
    set -l conf_color green; test $conflicts -gt 0; and set conf_color yellow
    set -a cells "$conf_color"\t'󰩌'\tconflicts\t$conflicts

    _sys_grid $cells
    _drive_attention $dfailed $skipped $error $inhibit
    test $stale -eq 1; and printf '%s󰗖 sampler stale, run: drive watch%s\n' (set_color red) (set_color normal)

    # ---- verbose extras ----
    if test $verbose -eq 1
        echo
        set_color --dim; echo mounts; set_color normal
        df -h -x tmpfs -x devtmpfs -x efivarfs --output=target,used,size,pcent | sed 's/^/  /'
        set_color --dim; echo sensors; set_color normal
        for h in /sys/class/hwmon/hwmon*
            read -l name < $h/name
            for t in $h/temp*_input
                test -r $t; or continue
                set -l labelfile (string replace _input _label $t)
                set -l label (string replace -r '.*/' '' $t)
                test -r $labelfile; and read label < $labelfile
                read -l raw < $t
                printf '  %-14s %-16s %s°C\n' $name $label (math -s0 $raw / 1000)
            end
        end
        if test $failed -gt 0
            set_color --dim; echo 'failed units'; set_color normal
            systemctl --failed --no-legend --plain 2>/dev/null | sed 's/^/  /'
            systemctl --user --failed --no-legend --plain 2>/dev/null | sed 's/^/  user: /'
        end
        set_color --dim; echo drive; set_color normal
        drive status | tail -n +2 | sed 's/^/  /'
    end
end

# Print cells as an aligned grid. Each cell is "color<TAB>icon<TAB>label<TAB>value";
# icon and value take the colour, the label is dim. Column count follows the terminal width.
function _sys_grid
    set -l width 23
    set -l term $COLUMNS
    test -n "$term"; or set term 80
    set -l cols (math -s0 $term / $width)
    test $cols -lt 1; and set cols 1
    test $cols -gt 4; and set cols 4
    set -l n (set_color normal)
    set -l dim (set_color --dim)
    set -l i 0
    for cell in $argv
        set -l f (string split \t -- $cell)
        set i (math $i + 1)
        set -l value $f[4]
        # keep a long value (an SSID, say) inside its column
        set -l room (math $width - 3 - (string length -- $f[3]))
        test (string length --visible -- $value) -gt $room; and set value (string sub -l (math $room - 1) -- $value)…
        printf '%s%s %s%s %s%s%s' (set_color $f[1]) $f[2] $dim $f[3] (set_color $f[1]) $value $n
        if test (math $i % $cols) -eq 0
            echo
        else
            set -l pad (math $width - (string length --visible -- "$f[2] $f[3] $value"))
            test $pad -gt 0; and printf '%'$pad's' ''
        end
    end
    test (math $i % $cols) -ne 0; and echo
end

# green below warn, yellow below crit, red otherwise
function _sys_level --argument-names value warn crit
    if test $value -lt $warn
        echo green
    else if test $value -lt $crit
        echo yellow
    else
        echo red
    end
end

# kibibytes -> gibibytes with one decimal
function _sys_gb --argument-names kb
    math -s1 $kb / 1048576
end

# bytes per second -> compact rate
function _sys_rate --argument-names bps
    if test $bps -ge 1048576
        echo (math -s1 $bps / 1048576)M
    else if test $bps -ge 1024
        echo (math -s0 $bps / 1024)K
    else
        echo $bps"B"
    end
end

function _sys_rel --argument-names secs
    if test $secs -lt 3600
        echo (math -s0 $secs / 60)m
    else if test $secs -lt 86400
        echo (math -s0 $secs / 3600)h(math -s0 '('$secs % 3600')' / 60)m
    else
        echo (math -s0 $secs / 86400)d(math -s0 '('$secs % 86400')' / 3600)h
    end
end
