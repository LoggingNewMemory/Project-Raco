#!/system/bin/sh

###################################
# Star Tweak (@Koneko_dev)
# Version amba 2.0 
# Note: 
###################################

set_hwui_sf() {
  setprop debug.sf.latch_unsignaled 1
  setprop debug.hwui.use_buffer_age false
  setprop debug.hwui.disable_vsync false
  setprop debug.sf.hw 1
}

animation() {
    cpu_total=$(awk '{sum+=$1} END{printf "%.0f", sum/1000000}' /sys/devices/system/cpu/cpu[0-9]*/cpufreq/cpuinfo_max_freq 2>/dev/null)
    [ -z "$cpu_total" ] && cpu_total=1000
    scale=$(awk -v t="$cpu_total" 'BEGIN {
        s = 1.6 / sqrt(t);
        if (s < 0.08) s = 0.08;
        if (s > 1.0) s = 1.0;
        if (t < 1200) s = 0.8;
        if (t >= 1200 && t < 1800) s = 0.6;
        if (t >= 1800 && t < 3000) s = 0.35;
        if (t >= 3000) s = 0.18;
        printf "%.2f", s;
    }')
    settings put global window_animation_scale $scale 
    settings put global transition_animation_scale $scale 
    settings put global animator_duration_scale $scale 
}

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
animation &
sleep 0.08
maincore &
sleep 0.08
short_preload &
sleep 0.08
toggle_off_powersave &
wait
sleep 0.5
sync