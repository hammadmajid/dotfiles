function _drive_rel --argument-names secs
    test $secs -lt 0; and set secs (math -- -$secs)
    if test $secs -lt 60
        echo "$secs"s
    else if test $secs -lt 3600
        echo (math -s0 $secs / 60)m
    else if test $secs -lt 86400
        echo (math -s0 $secs / 3600)h (math -s0 '('$secs % 3600')' / 60)m
    else
        echo (math -s0 $secs / 86400)d (math -s0 '('$secs % 86400')' / 3600)h
    end
end
