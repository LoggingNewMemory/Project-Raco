###################################
# Star Tweak (@Koneko_dev)
# Version amba 2.0 
# Note: No debug.hwui.target_cpu_time_percent, etc
###################################

maincore () {
    atrace --async_stop >/dev/null 2>&1
    cmd looper_stats reset >/dev/null 2>&1
    cmd looper_stats disable >/dev/null 2>&1
    
    # FIXED: Added >/dev/null 2>&1 to the background loop
    for app in $(pm list packages | cut -d: -f2); do 
        pm log-visibility --disable $app >/dev/null 2>&1
    done >/dev/null 2>&1 &

    for a in --reset --disable --disable-detailed-tracking; do 
        dumpsys binder_calls_stats $a >/dev/null 2>&1
    done
    
    for b in --clear --stop-testing; do 
        dumpsys procstats $b >/dev/null 2>&1
    done
    
    for c in ab-logging-disable dwb-logging-disable dmd-logging-disable; do 
        cmd display $c >/dev/null 2>&1
    done
    
    # Cleaned up complex nested loop for readability and redirection
    for f in $(dumpsys window | grep "^  Proto:" | sed 's/^  Proto: //' | tr ' ' '\n'; dumpsys window | grep "^  Logcat:" | sed 's/^  Logcat: //' | tr ' ' '\n'); do 
        wm logging disable "$f" >/dev/null 2>&1
        wm logging disable-text "$f" >/dev/null 2>&1
    done
}


#trigger action
maincore