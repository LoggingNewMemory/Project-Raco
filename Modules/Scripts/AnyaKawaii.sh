#!/system/bin/sh
#
# AnyaKawaii - Restore/Enable Thermal
# Optimized by Kanagawa Yamada
#
# Optimization: Parallel Restore + AnyaMelfissa "Broad Spoof" Logic

# ----------------- HELPER FUNCTIONS -----------------

write_val() {
    [ -e "$1" ] && echo "$2" > "$1" 2>/dev/null
}

# ----------------- ASYNC MODULES -----------------

# Module 1: Filesystem & Permissions
restore_filesystem() {
    # 1. Unmount blocked binaries
    umount /vendor/bin/hw/thermal-hal-2-0 2>/dev/null
    umount /vendor/bin/thermald 2>/dev/null

    # 2. Batch Restore Permissions (Files -> 644, Dirs -> 755)
    find /sys/devices/virtual/thermal/thermal_zone*/ \
         /sys/firmware/devicetree/base/soc/*/ \
         \( -name '*temp*' -o -name '*trip_point_*' -o -name '*type*' -o -name '*thermal*' \) \
         -type f -exec chmod 644 {} + 2>/dev/null

    find /sys/devices/virtual/thermal/thermal_zone*/ \
         -type d -exec chmod 755 {} + 2>/dev/null

    # 3. Restore Hwmon permissions
    chmod -R 755 /sys/devices/virtual/hwmon/hwmon* 2>/dev/null
    find /sys/devices/virtual/hwmon/hwmon* -type f -exec chmod 644 {} + 2>/dev/null
}

# Module 2: Hardware & Kernel Controls
restore_hardware() {
    # 1. Re-enable Thermal Modes
    for thermmode in /sys/devices/virtual/thermal/thermal_zone*/mode; do
        write_val "$thermmode" "enabled"
    done

    # 2. Re-enable CPU Core Control
    for cpu in /sys/devices/system/cpu/cpu*/core_ctl/enable; do
        write_val "$cpu" "1"
    done

    # 3. Re-enable MSM Thermal
    find /sys/ -name enabled | grep 'msm_thermal' | while read -r msm; do
        write_val "$msm" "Y"
        write_val "$msm" "1"
    done

    # 4. Re-enable GPU Throttling
    for kgsl in /sys/class/kgsl/kgsl-3d0; do
        if [ -d "$kgsl" ]; then
            write_val "$kgsl/throttling" "1"
            write_val "$kgsl/thermal_pwrlevel" "1" 
        fi
    done
}

# ----------------- MAIN EXECUTION -----------------

main() {
    # 1. Run Restore Operations in Parallel (FIXED: Redirected to /dev/null)
    (restore_filesystem) > /dev/null 2>&1 &
    (restore_hardware) > /dev/null 2>&1 &
    wait

    # 2. Restore Android Thermal Service Internal Status
    cmd thermalservice override-status 1 > /dev/null 2>&1
    cmd thermalservice reset > /dev/null 2>&1

    # 3. Start Services
    # We attempt to start them genuinely first
    getprop | grep -E 'init.svc(\.vendor)?\.thermal' | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]' | while read -r svc; do
        resetprop -n "init.svc.$svc" "stopped"
        start "$svc"
        setprop ctl.start "$svc"
    done > /dev/null 2>&1

    getprop | grep 'thermal' | cut -d '[' -f2 | cut -d ']' -f1 | while read -r prop; do
        if [ -n "$prop" ]; then
            resetprop -n "$prop" "running"
        fi
    done > /dev/null 2>&1
}

# Execute
main
exit 0