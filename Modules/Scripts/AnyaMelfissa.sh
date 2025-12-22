#!/system/bin/sh
# ----------------- HELPER FUNCTIONS -----------------

write_val() {
    [ -e "$1" ] && echo "$2" > "$1" 2>/dev/null
}

# ----------------- ASYNC MODULES -----------------

# Module 1: Process Killer (Priority)
kill_thermal_services() {
    # Direct kill for common thermal binaries
    killall -9 thermald thermal-hal-2-0 android.hardware.thermal@2.0-service 2>/dev/null
    
    # Aggressive sweep using pgrep (faster than ps | grep)
    pgrep -f "thermal" | xargs -r kill -9 2>/dev/null
    
    # Stop init services via property triggers
    getprop | grep -E 'init.svc.*thermal' | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]' | while read -r svc; do
        stop "$svc"
        setprop ctl.stop "$svc"
    done
}

# Module 2: Filesystem & Permissions (Heavy I/O)
disable_fs_protections() {
    # Batch permission removal (Much faster than loops)
    find /sys/devices/virtual/thermal/thermal_zone*/ \
        /sys/firmware/devicetree/base/soc/*/ \
        /sys/devices/virtual/hwmon/hwmon*/ \
        \( -name '*temp*' -o -name '*trip_point_*' -o -name '*type*' -o -name '*limit_info*' \) \
        -exec chmod 000 {} + 2>/dev/null

    # Disable Thermal Zones Mode
    for mode in /sys/devices/virtual/thermal/thermal_zone*/mode; do
        write_val "$mode" "disabled"
        chmod 644 "$mode" 2>/dev/null
    done
    
    # Bind mount blocks
    mount -o bind /dev/null /vendor/bin/hw/thermal-hal-2-0 2>/dev/null
    mount -o bind /dev/null /vendor/bin/thermald 2>/dev/null
    
    # Delete Cache
    rm -f /data/vendor/thermal/config /data/vendor/thermal/*.dump 2>/dev/null
}

# Module 3: CPU & Scheduler Tweaks
disable_cpu_limits() {
    # Core Control & MSM Thermal
    for cpu in /sys/devices/system/cpu/cpu*/core_ctl/enable; do
        write_val "$cpu" "0"
        chmod 444 "$cpu" 2>/dev/null
    done

    find /sys/ -name enabled | grep 'msm_thermal' | while read -r msm; do
        write_val "$msm" "N"
        write_val "$msm" "0"
    done

    # PPM Policy
    write_val "/proc/ppm/enabled" "1"
    for policy in 2 3 4 6 7; do
        write_val "/proc/ppm/policy_status" "$policy 0"
    done

    # Disable Logging/Debug/Panic
    write_val "/proc/sys/kernel/sched_boost" "0"
    write_val "/proc/sys/kernel/panic" "0"
    write_val "/proc/sys/kernel/panic_on_oops" "0"
    
    # Disable specific modules
    write_val "/sys/module/workqueue/parameters/power_efficient" "N"
    write_val "/sys/module/workqueue/parameters/disable_numa" "N"
    
    # FPSGO & MTK
    write_val "/sys/kernel/fpsgo/fbt/thrm_enable" "0"
    write_val "/sys/kernel/eara_thermal/enable" "0"
}

# Module 4: GPU Optimization
disable_gpu_limits() {
    # Trip Points
    for ZONE in /sys/class/thermal/thermal_zone*; do 
        read -r TYPE < "$ZONE/type" 2>/dev/null
        case "$TYPE" in 
            *gpu*|*ddr*) 
                for TP in "$ZONE"/trip_point_*_temp; do 
                    [ -f "$TP" ] && echo 95000 > "$TP" 2>/dev/null
                done 
            ;; 
        esac 
    done

    # KGSL & GPU Freq
    for kgsl in /sys/class/kgsl/kgsl-3d0; do
        if [ -d "$kgsl" ]; then
            write_val "$kgsl/throttling" "0"
            write_val "$kgsl/max_gpuclk" "0"
            write_val "$kgsl/force_clk_on" "1"
            write_val "$kgsl/thermal_pwrlevel" "0"
        fi
    done
    
    # Generic GPU Freq limits
    local GPUFREQ=/proc/gpufreq
    if [ -d "$GPUFREQ" ]; then
        write_val "$GPUFREQ/gpufreq_power_limited" "0"
        write_val "$GPUFREQ/gpufreq_limited_thermal_ignore" "1"
    fi
}

# Module 5: Property Spoofing (The MUST Have)
spoof_running_status() {
    # 1. Reset specific thermal props
    for prop in $(getprop | grep -E 'sys\..*thermal|thermal_config' | cut -d: -f1 | tr -d '[]'); do
        resetprop -n "$prop" "0"
    done
    
    # 2. Disable Transsion/Infinix specific debug throttle
    if resetprop debug.thermal.throttle.support | grep -q 'yes'; then
        resetprop -n -v debug.thermal.throttle.support no
    fi

    # 3. THE RUNNING SPOOF (Critical)
    # Forces system to believe thermal services are running to prevent bootloops or crashes
    getprop | grep 'thermal' | cut -d '[' -f2 | cut -d ']' -f1 | while read -r prop; do
        if [ -n "$prop" ]; then
            resetprop -n "$prop" "running"
        fi
    done
}

# ----------------- MAIN EXECUTION -----------------

main() {
    # 1. Kill services immediately (Synchronous to free resources)
    kill_thermal_services
    cmd thermalservice override-status 0 2>/dev/null

    # 2. Execute Heavy Tasks in Parallel
    (disable_fs_protections) &
    (disable_cpu_limits) &
    (disable_gpu_limits) &

    # 3. Wait for all background jobs to finish
    wait

    # 4. Apply Spoofing (Last step to overwrite any status changes)
    spoof_running_status
}

# Execute
main
exit 0