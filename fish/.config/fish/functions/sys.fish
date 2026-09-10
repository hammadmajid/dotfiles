function sys --description 'Compact system and Drive sync report card (sys -v for detail)'
    set -l verbose 0
    contains -- -v $argv; and set verbose 1

    # Nerd Font glyphs
    set -l i_cpu ''
    set -l i_load '󰓅'
    set -l i_ram '󰍛'
    set -l i_swap '󰓡'
    set -l i_temp ''
    set -l i_up ''
    set -l i_disk '󰋊'
    set -l i_wifi ''
    set -l i_eth '󰈀'
    set -l i_ts '󰖟'
    set -l i_bat ''
    set -l i_plug ''
    set -l i_fail ''
    set -l i_upd ''

    set -l dim (set_color --dim)
    set -l n (set_color normal)

    # Everything below reads /proc, /sys and one small file; external commands are kept to a handful
    # so a new shell is not held up. Slow facts come from sys-sample.service via $XDG_RUNTIME_DIR/sys-sample.

    # ---- sampled values (written every minute by sys-sample.service) ----
    set -l cpu -; set -l rx 0; set -l tx 0; set -l updates -; set -l sample_age -1; set -l cores 1
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
                case cores; set cores $v
                case updates; test -n "$v"; and set updates $v
                case net_type; set net_type $v
                case net_name; test -n "$v"; and set net_name $v
                case failed_sys; set failed_sys $v
                case failed_usr; set failed_usr $v
                case ts; set sample_age (math $now - $v)
            end
        end < (string replace = ' ' < $sample | psub)
    end

    # ---- line 1: compute ----
    read -l load1 load5 load15 rest < /proc/loadavg
    set -l load_color (_sys_level $load1 (math $cores x 0.7) $cores)
    set -l cpu_color green
    test $cpu != -; and set cpu_color (_sys_level $cpu 70 90)

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
    set -l mem_color (_sys_level (math -s0 $mem_used x 100 / $mem_total) 75 90)
    set -l swap_used (math $swap_total - $swap_free)
    set -l swap_color green
    if test $swap_total -gt 0
        test $swap_used -gt 0; and set swap_color yellow
        test (math -s0 $swap_used x 100 / $swap_total) -ge 50; and set swap_color red
    end

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

    read -l up rest < /proc/uptime
    set -l uptime (_sys_rel (math -s0 $up))

    printf '%s%s %s%%%s %s%s %s %s %s%s  %s%s %s/%sG%s  %s%s %s/%sG%s  %s%s %s°C%s  %s%s %s%s\n' \
        (set_color $cpu_color) $i_cpu $cpu $n \
        (set_color $load_color) $i_load $load1 $load5 $load15 $n \
        (set_color $mem_color) $i_ram (_sys_gb $mem_used) (_sys_gb $mem_total) $n \
        (set_color $swap_color) $i_swap (_sys_gb $swap_used) (_sys_gb $swap_total) $n \
        (set_color $temp_color) $i_temp $temp $n \
        $dim $i_up $uptime $n

    # ---- line 2: storage and network ----
    # one df call: root always; boot partitions only when getting full; external drives whenever mounted
    for line in (df --output=used,size,pcent,target -x tmpfs -x devtmpfs -x efivarfs 2>/dev/null | tail -n +2)
        set -l d (string split -n ' ' $line)
        set -l p (string trim -c % $d[3])
        set -l c (_sys_level $p 80 90)
        switch $d[4]
            case /
                printf '%s%s %s/%sG %s%%%s' (set_color $c) $i_disk (_sys_gb $d[1]) (_sys_gb $d[2]) $p $n
            case /boot /boot/efi
                test $p -ge 80; and printf '  %s%s %s %s%%%s' (set_color $c) $i_disk $d[4] $p $n
            case '/run/media/*'
                printf '  %s%s %s %s/%sG %s%%%s' (set_color $c) $i_disk (string split -r -m1 / $d[4])[2] (_sys_gb $d[1]) (_sys_gb $d[2]) $p $n
        end
    end

    set -l net_icon $i_wifi; set -l net_color green
    test "$net_type" = ethernet; and set net_icon $i_eth
    test "$net_name" = offline; and set net_color red
    set -l ts_color red
    if test -r /sys/class/net/tailscale0/operstate
        read -l ts_state < /sys/class/net/tailscale0/operstate
        test "$ts_state" = unknown -o "$ts_state" = up; and set ts_color green
    end
    printf '  %s%s %s%s %s↓%s ↑%s%s  %s%s ts%s\n' \
        (set_color $net_color) $net_icon $net_name $n \
        $dim (_sys_rate $rx) (_sys_rate $tx) $n \
        (set_color $ts_color) $i_ts $n

    # ---- line 3: power and health ----
    set -l bat /sys/class/power_supply/BAT0
    if test -d $bat
        read -l cap < $bat/capacity
        read -l bstate < $bat/status
        set bstate (string lower $bstate)
        test "$bstate" = 'not charging'; and set bstate plugged
        set -l bcolor green
        set -l bicon $i_plug
        set -l remaining ''
        if test $bstate = discharging
            set bicon $i_bat
            test $cap -lt 30; and set bcolor yellow
            test $cap -lt 15; and set bcolor red
        end
        if test -r $bat/charge_now -a -r $bat/current_now
            read -l cur < $bat/current_now
            if test $cur -gt 0
                read -l q < $bat/charge_now
                read -l full < $bat/charge_full
                if test $bstate = discharging
                    set remaining (_sys_rel (math -s0 $q x 3600 / $cur))
                else if test $bstate = charging
                    set remaining (_sys_rel (math -s0 '('$full - $q')' x 3600 / $cur))
                end
            end
        end
        printf '%s%s %s%% %s%s' (set_color $bcolor) $bicon $cap $bstate $n
        test -n "$remaining"; and printf ' %s%s%s' $dim $remaining $n
    else
        printf '%s%s AC%s' (set_color green) $i_plug $n
    end

    set -l failed (math $failed_sys + $failed_usr)
    set -l fcolor green
    test $failed -gt 0; and set fcolor yellow
    printf '  %s%s %s failed%s' (set_color $fcolor) $i_fail $failed $n

    set -l ucolor $dim
    test "$updates" != - -a "$updates" != 0; and set ucolor (set_color yellow)
    printf '  %s%s %s updates%s' $ucolor $i_upd $updates $n
    if test $sample_age -lt 0 -o $sample_age -gt 180
        printf '  %s(sampler stale, run: drive watch)%s' (set_color red) $n
    end
    echo

    # ---- line 4 (and 5 when unhealthy): Drive sync ----
    _drive_line

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
