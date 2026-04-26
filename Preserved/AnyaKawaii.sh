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
    # 1. Unmount blocked binaries (Excluded 'hal')
    umount /vendor/bin/thermald 2>/dev/null
}

# Module 2: Hardware & Kernel Controls
restore_hardware() {
    # 1. Re-enable CPU Core Control
    for cpu in /sys/devices/system/cpu/cpu*/core_ctl/enable; do
        write_val "$cpu" "1"
    done

    # 2. Re-enable MSM Thermal
    find /sys/ -name enabled | grep 'msm_thermal' | while read -r msm; do
        write_val "$msm" "Y"
        write_val "$msm" "1"
    done

    # 3. Re-enable GPU Throttling
    for kgsl in /sys/class/kgsl/kgsl-3d0; do
        if [ -d "$kgsl" ]; then
            write_val "$kgsl/throttling" "1"
            write_val "$kgsl/thermal_pwrlevel" "1" 
        fi
    done
}

# ----------------- MAIN EXECUTION -----------------

main() {
    # 1. Run Restore Operations in Parallel
    (restore_filesystem) &
    (restore_hardware) &
    wait

    # 2. Restore Android Thermal Service Internal Status
    cmd thermalservice override-status 1 2>/dev/null
    cmd thermalservice reset 2>/dev/null

    # 3. Start Services
    # We attempt to start them genuinely first (Excluded 'hal')
    getprop | grep -E 'init.svc(\.vendor)?\.thermal' | grep -v "hal" | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]' | while read -r svc; do
        resetprop -n "init.svc.$svc" "stopped"
        start "$svc"
        setprop ctl.start "$svc"
    done

    # Excluded 'hal' from status reset
    getprop | grep 'thermal' | grep -v "hal" | cut -d '[' -f2 | cut -d ']' -f1 | while read -r prop; do
        if [ -n "$prop" ]; then
            resetprop -n "$prop" "running"
        fi
    done
}

# Execute
main
exit 0