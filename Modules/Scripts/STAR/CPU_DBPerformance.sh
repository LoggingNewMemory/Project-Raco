#!/system/bin/sh

###################################
# Star Tweak (@Koneko_dev)
# Version amba 2.0 
###################################

maincore() {
    atrace --async_stop >/dev/null 2>&1 &
    cmd looper_stats reset >/dev/null 2>&1 &
    cmd looper_stats disable >/dev/null 2>&1 &

    setprop debug.debuggerd.wait_for_debugger false
    setprop debug.debuggerd.wait_for_gdb false
    setprop debug.debuggerd.disable 1

    for opt in --reset --disable --disable-detailed-tracking; do
        dumpsys binder_calls_stats $opt >/dev/null 2>&1 &
    done

    for opt in --clear --stop-testing; do
        dumpsys procstats $opt >/dev/null 2>&1 &
    done

    for flag in ab-logging-disable dwb-logging-disable dmd-logging-disable; do
        cmd display $flag >/dev/null 2>&1 &
    done

    logcat -G 64K >/dev/null 2>&1
    logcat -c
}

toggle_off_powersave() {
    cmd power set-mode 0
    cmd power set-adaptive-power-saver-enabled false
    cmd power thermalservice override-status 0
    settings delete global battery_saver_constants
}

maincore
toggle_off_powersave
sync