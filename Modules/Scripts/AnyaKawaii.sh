#!/system/bin/sh
#
# AnyaKawaii - Restore/Enable Thermal

w() { echo "$2" > "$1" 2>/dev/null; }
c() { chmod "$2" "$1" 2>/dev/null; }

# 1. Unmount (Critical first step)
umount /vendor/bin/hw/thermal-hal-2-0 2>/dev/null
umount /vendor/bin/thermald 2>/dev/null

(
    # [BLOCK 1] Restore Permissions
    find /sys/devices/virtual/thermal/thermal_zone*/ \
         /sys/firmware/devicetree/base/soc/*/ \
         -name '*temp*' -o -name '*trip_point_*' -o -name '*type*' -o -name '*thermal*' | while read -r file; do
        if [ -d "$file" ]; then c "$file" 755; else c "$file" 644; fi
    done
    
    c "/sys/devices/virtual/hwmon/hwmon*" 755
    c "/sys/devices/virtual/hwmon/hwmon*/*" 644
    
    # Re-enable Thermal Modes
    for thermmode in /sys/devices/virtual/thermal/thermal_zone*/mode; do
        w "$thermmode" "enabled"
    done
) &

(
    # [BLOCK 2] Restore CPU/GPU Controls
    for cpu in /sys/devices/system/cpu/cpu*/core_ctl/enable; do w "$cpu" "1"; done
    
    find /sys/ -name enabled 2>/dev/null | grep 'msm_thermal' | while read -r m; do
        w "$m" "Y"; w "$m" "1"
    done

    for kgsl in /sys/class/kgsl/kgsl-3d0; do
        [ -d "$kgsl" ] && w "$kgsl/throttling" "1" && w "$kgsl/thermal_pwrlevel" "1"
    done
) &

wait

# 3. Restart Services (Sequential is safer here to avoid race conditions during init)
cmd thermalservice override-status 1 2>/dev/null
cmd thermalservice reset 2>/dev/null

for svc in $(getprop | grep -E 'init.svc(\.vendor)?\.thermal' | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]'); do
    resetprop -n "init.svc.$svc" "stopped"
    start "$svc"
done

# 4. Final Spoof/Status
getprop | grep 'thermal' | cut -d '[' -f2 | cut -d ']' -f1 | while read -r prop; do
    if [ -n "$prop" ]; then
      resetprop -n "$prop" "running"
    fi
done