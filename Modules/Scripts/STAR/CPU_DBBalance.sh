###################################
# Star Tweak (@Koneko_dev)
# Version amba 2.0 
###################################

maincore() {
    atrace --async_stop >/dev/null 2>&1 &
    cmd looper_stats reset >/dev/null 2>&1 &
    cmd looper_stats disable >/dev/null 2>&1 &

    pm list packages | cut -d: -f2 | while read app; do
        pm log-visibility --disable "$app" >/dev/null 2>&1 &
    done &

    for a in --reset --disable --disable-detailed-tracking; do
        dumpsys binder_calls_stats $a >/dev/null 2>&1 &
    done

    for b in --clear --stop-testing; do
        dumpsys procstats $b >/dev/null 2>&1 &
    done

    for c in ab-logging-disable dwb-logging-disable dmd-logging-disable; do
        cmd display $c >/dev/null 2>&1 &
    done

    dumpsys window | grep -E "^  (Proto|Logcat):" | cut -d: -f2 | tr -d ' ' | while read f; do
        wm logging disable "$f" >/dev/null 2>&1 &
        wm logging disable-text "$f" >/dev/null 2>&1 &
    done &
}

maincore