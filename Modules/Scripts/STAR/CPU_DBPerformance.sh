#!/system/bin/sh

###################################
# Star Tweak (@Koneko_dev)
# Version amba 2.0 
# Note: Remove set_hwui_sf because crash SF in Arona
###################################

maincore() {
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
}

short_preload() {
    vmt() { cat "$1" >/dev/null 2>&1; }
    for lib in /system/lib*/libsurfaceflinger.so /system/lib*/libhwui.so /system/lib*/libGLES* /system/lib*/libEGL.so /system/lib*/libui.so /system/lib*/libgui.so /system/lib*/libinputflinger.so; do
        [ -f "$lib" ] && vmt "$lib" &
    done
}

toggle_off_powersave() {
    cmd power set-mode 0 
    cmd power set-adaptive-power-saver-enabled false 
    cmd power thermalservice override-status 0 
    settings delete global battery_saver_constants 
}

set_hwui_sf
maincore &
sleep 0.08
short_preload &
sleep 0.08
toggle_off_powersave &
wait
sleep 0.5
sync