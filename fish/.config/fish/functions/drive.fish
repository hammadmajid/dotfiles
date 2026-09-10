function drive --description 'Google Drive sync (rclone bisync) control and status'
    set -l script ~/.config/rclone/rclone-bisync-gdrive.sh
    set -l log ~/.config/rclone/rclone-bisync.log
    set -l state ~/.local/state/drive
    set -l pairs (sed -nE 's/^\s+"([A-Za-z0-9_\/-]+)=[^"]+"$/\1/p' $script)
    set -l dirs
    for p in $pairs
        test -d ~/$p; and set -a dirs ~/$p
    end

    set -l cmd $argv[1]
    set -e argv[1]

    switch "$cmd"
        case sync pull push
            if test (count $argv) -gt 0
                if not contains -- $argv[1] $pairs
                    echo "unknown pair '$argv[1]'. Pairs: $pairs" >&2
                    return 1
                end
                if test (systemctl --user show -p ActiveState --value rclone-bisync.service) != inactive
                    echo "a full sync is already running; wait for it or run 'drive sync' to follow it" >&2
                    return 1
                end
                env DRIVE_PAIRS=$argv[1] $script
                _drive_line
                return
            end
            # start (or join) the service, then follow the log until its main process exits
            systemctl --user start --no-block rclone-bisync.service
            set -l pid 0
            for i in (seq 30)
                set pid (systemctl --user show -p MainPID --value rclone-bisync.service)
                test "$pid" != 0; and break
                sleep 0.1
            end
            if test "$pid" != 0
                tail -n0 -f --pid=$pid $log | grep --line-buffered -E '^(---|===|\[)|: (Copied|Deleted|Moved|Renamed)|ERROR|Bisync'
            end
            _drive_line
            test (systemctl --user show -p Result --value rclone-bisync.service) = success

        case status
            if contains -- --line $argv
                _drive_line
                return
            end
            _drive_line
            if test -f $state/last-run
                echo
                set_color --dim; echo "last run:"; set_color normal
                sed 's/^/  /' $state/last-run
            end
            for u in rclone-bisync.timer rclone-watch.service sys-sample.service
                printf '  %-22s %s\n' $u (systemctl --user is-active $u)
            end
            set -l conflicts (find $dirs -name '*.conflict*' 2>/dev/null)
            if test (count $conflicts) -gt 0
                echo
                set_color yellow; echo "conflict files:"; set_color normal
                string replace -- ~/ '  ' $conflicts
            end

        case conflicts
            set -l conflicts (find $dirs -name '*.conflict*' 2>/dev/null)
            if test (count $conflicts) -eq 0
                echo "no conflict files"
            else
                string replace -- ~/ '' $conflicts
            end

        case log
            if contains -- -f $argv
                tail -n 20 -f $log
            else
                tail -n (test (count $argv) -gt 0; and echo $argv[1]; or echo 40) $log
            end

        case resync
            set -l target all pairs
            set -l envpairs
            if test (count $argv) -gt 0
                if not contains -- $argv[1] $pairs
                    echo "unknown pair '$argv[1]'. Pairs: $pairs" >&2
                    return 1
                end
                set target $argv[1]
                set envpairs DRIVE_PAIRS=$argv[1]
            end
            set_color yellow
            echo "Re-baseline $target. Local side wins; files deleted on one side since the last run come back."
            set_color normal
            read -l -P 'Continue? [y/N] ' answer
            string match -qi y -- $answer; or return 1
            # keep the timer and watcher from starting a normal run in the middle of the resync
            systemctl --user stop rclone-bisync.timer rclone-watch.service
            env $envpairs $script --resync
            set -l rc $status
            systemctl --user start rclone-bisync.timer rclone-watch.service
            _drive_line
            return $rc

        case watch
            for u in rclone-watch.service rclone-bisync.timer sys-sample.service
                set -l st (systemctl --user is-active $u)
                if test $st != active
                    systemctl --user start $u
                    printf '  %-22s %s -> %s\n' $u $st (systemctl --user is-active $u)
                else
                    printf '  %-22s %s\n' $u $st
                end
            end
            systemctl --user list-timers rclone-bisync.timer --no-pager | sed -n 2p

        case skip
            mkdir -p $state
            touch $state/muted
            if test (count $argv) -eq 0
                echo "muted skip notifications:" (cat $state/muted)
                return
            end
            if not contains -- $argv[1] $pairs
                echo "unknown pair '$argv[1]'. Pairs: $pairs" >&2
                return 1
            end
            if grep -qxF -- $argv[1] $state/muted
                grep -vxF -- $argv[1] $state/muted > $state/muted.tmp; mv $state/muted.tmp $state/muted
                echo "unmuted $argv[1]"
            else
                echo $argv[1] >> $state/muted
                echo "muted $argv[1]"
            end

        case '*'
            echo "drive: Google Drive sync via rclone bisync"
            echo
            echo "  drive sync [pair]      run a sync now (pull/push are aliases; a pair limits it to one folder)"
            echo "  drive status           sync summary, unit states, conflict files"
            echo "  drive conflicts        list .conflict files"
            echo "  drive log [-f|N]       last N lines of the log, or follow it"
            echo "  drive resync [pair]    re-baseline (asks first)"
            echo "  drive watch            show and revive the watcher, timer and sampler"
            echo "  drive skip [pair]      list, or toggle, muted skip notifications"
            echo
            echo "  pairs: $pairs"
            test -z "$cmd"; or return 1
    end
end
