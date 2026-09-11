# Drive sync facts as key=value lines, one source for `_drive_line` and the `sys` grid.
# Reads the last-run summary written by rclone-bisync-gdrive.sh, makes one systemctl call, and asks
# logind whether the service's suspend inhibitor is held (systemd-inhibit --list, a few ms).
function _drive_facts
    set -l state ~/.local/state/drive
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
    set -l word (_drive_rel $age)' ago'
    switch $st
        case 0
            test $age -gt 7200; and set color yellow
        case offline
            set color yellow; set word offline
        case unknown
            set color yellow; set word never
        case '*'
            set color red; set word failed
    end
    test $svc_state = activating; and begin; set color blue; set word syncing; end

    # the service wraps its run in systemd-inhibit --who=rclone-bisync --mode=block
    set -l inhibit 0
    systemd-inhibit --list --no-legend --no-pager --mode=block 2>/dev/null | string match -q 'rclone-bisync *'; and set inhibit 1

    # the timer fires 30 min after the service last started, whoever started it
    set -l next -
    if test $start -gt 0
        set -l left (math $start + 1800 - $now)
        test $left -lt 0; and set left 0
        set next (_drive_rel $left)
    end

    echo "state=$st"
    echo "color=$color"
    echo "word=$word"
    echo "next=$next"
    echo "timer=$timer_state"
    echo "watch=$watch_state"
    echo "conflicts=$nconf"
    echo "failed=$failed"
    echo "skipped=$skipped"
    echo "error=$error"
    echo "inhibit=$inhibit"
end
