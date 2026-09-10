# One compact line describing Drive sync health, plus a second line when something needs attention.
# Shared by `drive status` and the `sys` report card. Reads the last-run summary written by
# rclone-bisync-gdrive.sh and makes a single systemctl call for unit states.
function _drive_line
    set -l state ~/.local/state/drive
    set -l cloud ''
    set -l ok ''
    set -l bad ''
    set -l warn ''
    set -l eye ''
    set -l clock ''
    set -l dim (set_color --dim)
    set -l n (set_color normal)

    set -l now (date +%s)
    set -l st unknown; set -l start 0; set -l end 0; set -l failed; set -l skipped; set -l error; set -l nconf 0
    if test -r $state/last-run
        while read -l k v
            switch $k
                case status; set st $v
                case start; set start $v
                case end; set end $v
                case failed; set failed $v
                case skipped; set skipped $v
                case error; set error $v
                case conflicts; set nconf $v
            end
        end < (string replace = ' ' < $state/last-run | psub)
    end

    set -l svc_state inactive; set -l watch_state inactive; set -l timer_state inactive
    set -l unit ''
    for line in (systemctl --user show -p Id,ActiveState rclone-bisync.service rclone-bisync.timer rclone-watch.service 2>/dev/null)
        set -l kv (string split -m1 = $line)
        switch $kv[1]
            case Id; set unit $kv[2]
            case ActiveState
                switch $unit
                    case rclone-bisync.service; set svc_state $kv[2]
                    case rclone-bisync.timer; set timer_state $kv[2]
                    case rclone-watch.service; set watch_state $kv[2]
                end
        end
    end

    set -l age (math $now - $end)
    set -l color green
    set -l icon $ok
    set -l word synced
    switch $st
        case 0
            test $age -gt 7200; and set color yellow
        case offline
            set color yellow; set icon $warn; set word offline
        case unknown
            set color yellow; set icon $warn; set word 'never ran'
        case '*'
            set color red; set icon $bad; set word failed
    end
    test $svc_state = activating; and begin; set color blue; set icon $clock; set word syncing; end

    # the timer fires 30 min after the service last started, whoever started it
    set -l nextstr -
    if test $start -gt 0
        set -l left (math $start + 1800 - $now)
        test $left -lt 0; and set left 0
        set nextstr (_drive_rel $left)
    end

    set -l watch_color green
    test $watch_state = active; or set watch_color red
    set -l timer_color green
    test $timer_state = active; or set timer_color red
    set -l conf_color green
    test $nconf -gt 0; and set conf_color yellow

    printf '%s%s %s %s%s' (set_color $color) $cloud $icon $word $n
    test $st = 0; and printf ' %s%s ago%s' $dim (_drive_rel $age) $n
    printf '  %s%s next %s%s' $dim $clock $nextstr $n
    printf '  %s%s watch%s' (set_color $watch_color) $eye $n
    printf '  %s%s timer%s' (set_color $timer_color) $clock $n
    printf '  %s%s %s conflicts%s\n' (set_color $conf_color) $warn $nconf $n

    if test -n "$failed"
        printf '   %sfailed: %s' (set_color red) $failed
        test -n "$error"; and printf ' · %s' $error
        printf '%s\n' $n
    end
    if test -n "$skipped"
        printf '   %sskipped (folder missing): %s%s\n' (set_color yellow) $skipped $n
    end
end
