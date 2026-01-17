tweak() {
    if [ -e "$2" ]; then
        chmod 644 "$2" >/dev/null 2>&1
        echo "$1" > "$2" 2>/dev/null
        chmod 444 "$2" >/dev/null 2>&1
    fi
}

###################################
# Star Tweak (@Koneko_dev)
# Version amba 2.0 
###################################

star_kill() {
    # Clean process cache like idle zygote children
    cmd activity idle-maintenance
    am kill-all >/dev/null 2>&1
    sync
    # Clean logs & traces that might hold wakelocks
    logcat -c
    dumpsys batterystats --reset
}

star_battery_restore() {
    cmd power set-mode 0
    cmd power thermalservice override-status 0
    settings delete global battery_saver_constants
}

star_battery_saver() {
    cmd power set-mode 1
    cmd power thermalservice override-status 3
    settings put global battery_saver_constants advertise_is_enabled=true,animation_disabled=true,launch_boost_disabled=true,vibration_disabled=true
}

star_db_perf() {
    atrace --async_stop >/dev/null 2>&1 || true
    cmd looper_stats reset >/dev/null 2>&1 || true
    cmd looper_stats disable >/dev/null 2>&1 || true

    for prop in debug.debuggerd.wait_for_debugger debug.debuggerd.wait_for_gdb; do
        setprop $prop false
    done
    setprop debug.debuggerd.disable 1

    for opt in --reset --disable --disable-detailed-tracking; do
        dumpsys binder_calls_stats $opt 
    done
    for opt in --clear --stop-testing; do
        dumpsys procstats $opt   
    done

    for flag in ab-logging-disable dwb-logging-disable dmd-logging-disable; do
        cmd display $flag 
    done

    logcat -G 64K 
    logcat -c
    
    # Ensure powersave is off (Logic from CPU_DBPerformance)
    cmd power set-mode 0 
    cmd power thermalservice override-status 0 
    settings delete global battery_saver_constants
    sync
}

star_db_balance() {
    atrace --async_stop 1>/dev/null
    cmd looper_stats reset;cmd looper_stats disable
    for app in $(pm list packages | cut -d: -f2); do pm log-visibility --disable $app; done &
    for a in --reset --disable --disable-detailed-tracking;do dumpsys binder_calls_stats $a;done
    for b in --clear --stop-testing; do dumpsys procstats $b;done
    for c in ab-logging-disable dwb-logging-disable dmd-logging-disable; do cmd display $c;done
    for f in $(dumpsys window | grep "^  Proto:" | sed 's/^  Proto: //' | tr ' ' '\n'; dumpsys window | grep "^  Logcat:" | sed 's/^  Logcat: //' | tr ' ' '\n'); do wm logging disable "$f"; wm logging disable-text "$f"; done
}

###################################
# CORIN PROFILES
###################################

corin_perf() {
    # FreakZy Storage
    tweak "deadline" "$deviceio/queue/scheduler"
    tweak 1 "$queue/rq_affinity"

    # GPU Tweaks
    tweak "performance" "/sys/class/devfreq/mtk-dvfsrc-devfreq/governor"
    tweak "performance" "/sys/class/devfreq/13000000.mali/governor"
    tweak "0" "/proc/trans_scheduler/enable"
    tweak "1" "/proc/game_state"
    tweak "always_on" "/sys/class/misc/mali0/device/power_policy"
    tweak "enable" "/proc/gpufreqv2/aging_mode"

    # Settings
    settings put secure high_priority 1
    settings put secure low_priority 0
    cmd power set-adaptive-power-saver-enabled false
    cmd power set-fixed-performance-mode-enabled true
    cmd looper_stats disable

    # Merged STAR Logic
    star_battery_restore &
    star_db_perf &
}

corin_balanced() {
    # FreakZy Storage
    tweak "deadline" "$deviceio/queue/scheduler"
    tweak 1 "$queue/rq_affinity"

    # GPU Tweaks
    tweak "simple_ondemand" "/sys/class/devfreq/mtk-dvfsrc-devfreq/governor"
    tweak "simple_ondemand" "/sys/class/devfreq/13000000.mali/governor"
    tweak "1" "/proc/trans_scheduler/enable"
    tweak "0" "/proc/game_state"
    tweak "coarse_demand" "/sys/class/misc/mali0/device/power_policy"
    tweak "enable" "/proc/gpufreqv2/aging_mode"

    # Settings
    settings put secure high_priority 1
    settings put secure low_priority 0
    cmd power set-adaptive-power-saver-enabled false
    cmd power set-fixed-performance-mode-enabled false
    cmd looper_stats enable

    # Revert to Default Skia Backend
    setprop debug.hwui.renderer none

    # Merged STAR Logic
    star_battery_restore &
    star_db_balance &
}

corin_powersave() {
    # FreakZy Storage
    tweak "deadline" "$deviceio/queue/scheduler"
    tweak 2 "$queue/rq_affinity"

    # GPU Tweaks
    tweak "powersave" "/sys/class/devfreq/mtk-dvfsrc-devfreq/governor"
    tweak "powersave" "/sys/class/devfreq/13000000.mali/governor"
    tweak "1" "/proc/trans_scheduler/enable"
    tweak "0" "/proc/game_state"
    tweak "coarse_demand" "/sys/class/misc/mali0/device/power_policy"
    tweak "enable" "/proc/gpufreqv2/aging_mode"

    # Settings
    settings put secure high_priority 0
    settings put secure low_priority 1
    cmd power set-adaptive-power-saver-enabled true
    cmd power set-fixed-performance-mode-enabled false
    cmd looper_stats enable

    # Revert to Default Skia Backend
    setprop debug.hwui.renderer none

    # Merged STAR Logic
    star_battery_saver &
}