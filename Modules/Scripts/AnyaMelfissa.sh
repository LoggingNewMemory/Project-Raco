#!/system/bin/sh
#
# Telegram: @RiProG | Channel: @RiOpSo | Group: @RiOpSoDisc
# Optimized by Kanagawa Yamada (Parallel Processing + IO reduction)

# Helper: Fast write (skips existence check for speed)
w() { echo "$2" > "$1" 2>/dev/null; }

# Helper: Fast chmod
c() { chmod "$2" "$1" 2>/dev/null; }

# ----------------- PARALLEL EXECUTION BLOCKS -----------------

(
    # [BLOCK 1] GPU & KGSL Optimization
    for ZONE in /sys/class/thermal/thermal_zone*; do
        [ ! -f "$ZONE/type" ] && continue
        case "$(cat "$ZONE/type" 2>/dev/null)" in *gpu*|*ddr*)
            for TP in "$ZONE"/trip_point_*_temp; do w "$TP" 95000; done ;;
        esac
    done
    
    for gpufreq in /proc/gpufreq; do
        w "$gpufreq/gpufreq_power_limited" "0"
        for i in thermal oc low_batt_volume low_batt_volt; do
            w "$gpufreq/gpufreq_limited_${i}_ignore" "1"
        done
    done

    # KGSL Tweaks
    find /sys/class/kgsl/kgsl-3d0 -name 'throttling' -o -name 'max_gpuclk' -o -name 'force_clk_on' -o -name 'adreno_idler_active' -o -name 'thermal_pwrlevel' | while read -r f; do
        case "$f" in
            *throttling|*max_gpuclk|*thermal_pwrlevel) w "$f" "0" ;;
            *force_clk_on) w "$f" "1" ;;
            *adreno_idler_active) w "$f" "N" ;;
        esac
    done
) &

(
    # [BLOCK 2] Stop Processes & Services
    # Efficiently kill all thermal related processes
    pkill -9 -f thermal 2>/dev/null
    killall -9 thermald thermal-engine 2>/dev/null

    # Stop services via init
    for svc in $(getprop | grep -E 'init.svc(\.vendor)?\.thermal' | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]'); do
        stop "$svc"
        resetprop -n "init.svc.$svc" "stopped"
    done
    
    # Reset Props
    for prop in $(getprop | grep -E 'sys\..*thermal' | cut -d: -f1 | tr -d '[]'); do
        resetprop -n "$prop" "0"
    done
    
    # Disable thermal config props
    for prop in $(getprop | grep -E 'thermal_config|tran\.hbm\.thermal' | awk -F'[][]' '{print $2}'); do
        resetprop -n "$prop" "0"
    done
) &

(
    # [BLOCK 3] File System Permissions (Slowest part, running in BG)
    # Target specific paths to avoid full scan
    find /sys/devices/virtual/thermal/thermal_zone*/ \
         /sys/firmware/devicetree/base/soc/*/ \
         /sys/devices/virtual/hwmon/hwmon*/ \
         -name '*thermal*' -o -name '*temp*' -o -name '*trip_point_*' -o -name '*limit_info*' \
         | while read -r file; do
             c "$file" 000
         done

    for thermmode in /sys/devices/virtual/thermal/thermal_zone*/mode; do
        c "$thermmode" 644
        w "$thermmode" "disabled"
    done
) &

(
    # [BLOCK 4] CPU, Kernel & Misc
    # Core Control
    for cpu in /sys/devices/system/cpu/cpu*/core_ctl/enable; do
        c "$cpu" 666; w "$cpu" "0"; c "$cpu" 444
    done

    # MSM Thermal
    find /sys -name enabled 2>/dev/null | grep 'msm_thermal' | while read -r m; do
        w "$m" "N"; w "$m" "0"
    done

    # PPM & IO
    w "/proc/ppm/enabled" "1"
    for p in 2 3 4 6 7; do w "/proc/ppm/policy_status" "$p 0"; done
    for q in /sys/block/*/queue; do w "$q/iostats" "0"; w "$q/iosched/slice_idle" "0"; done
    
    # Logs & Debug
    for p in exception-trace sched_schedstats tracing_on log_ecn_error snapshot_crashdumper; do
        find /proc/sys /sys -name "$p" 2>/dev/null | while read -r f; do w "$f" "0"; done
    done
    
    # FPSGO & Bind Mounts
    w "/sys/kernel/fpsgo/fbt/thrm_enable" "0"
    w "/sys/kernel/fpsgo/fbt/thrm_temp_th" "95000"
    mount -o bind /dev/null /vendor/bin/hw/thermal-hal-2-0 2>/dev/null
    mount -o bind /dev/null /vendor/bin/thermald 2>/dev/null
    
    # Transsion specific
    resetprop -n -v debug.thermal.throttle.support no
    cmd thermalservice override-status 0 2>/dev/null
    
    # Clean Cache
    rm -f /data/vendor/thermal/config /data/vendor/thermal/*.dump
) &

# Wait for all background blocks to finish
wait

# ----------------- SPOOFING (Must run last) -----------------
# To Spoof Thermal Running in case some games need thermal
getprop | grep 'thermal' | cut -d '[' -f2 | cut -d ']' -f1 | while read -r prop; do
    if [ -n "$prop" ]; then
        resetprop -n "$prop" "running"
    fi
done

exit 0