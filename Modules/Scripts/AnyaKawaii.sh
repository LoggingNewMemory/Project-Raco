#!/system/bin/sh
#
# AnyaKawaii - Restore/Enable Thermal
# Reverses the actions of AnyaMelfissa to re-enable thermal throttling and management.

# Helper function to write values safely
write_val() {
    local file="$1"
    local value="$2"
    if [ -e "$file" ]; then
        chmod 644 "$file" 2>/dev/null
        echo "$value" > "$file"
    fi
}

# 1. Unmount blocked binaries (CRITICAL)
umount /vendor/bin/hw/thermal-hal-2-0 2>/dev/null
umount /vendor/bin/thermald 2>/dev/null

# 2. Restore Permissions (Reverse chmod 000)
restore_perms() {
    find "$1" -name '*temp*' -o -name '*trip_point_*' -o -name '*type*' -o -name '*thermal*' | while read -r file; do
        if [ -d "$file" ]; then
            chmod 755 "$file"
        else
            chmod 644 "$file"
        fi
    done
}

restore_perms "/sys/devices/virtual/thermal/thermal_zone*/"
restore_perms "/sys/firmware/devicetree/base/soc/*/"
chmod -R 755 /sys/devices/virtual/hwmon/hwmon* 2>/dev/null
chmod -R 644 /sys/devices/virtual/hwmon/hwmon*/* 2>/dev/null

# 3. Re-enable Thermal Modes
for thermmode in /sys/devices/virtual/thermal/thermal_zone*/mode; do
    write_val "$thermmode" "enabled"
done

# 4. Re-enable Kernel & CPU Thermal Controls
# Re-enable core_ctl (Hotplugging)
for cpu in /sys/devices/system/cpu/cpu[0,4,7]/core_ctl; do
    write_val "$cpu/enable" "1"
done

# Re-enable MSM Thermal if present
find /sys/ -name enabled | grep 'msm_thermal' | while read -r msm_thermal_status; do
    write_val "$msm_thermal_status" "Y"
    write_val "$msm_thermal_status" "1"
done

# Re-enable GPU Throttling/Governance
for kgsl in /sys/class/kgsl/kgsl-3d0; do
    if [ -d "$kgsl" ]; then
        write_val "$kgsl/throttling" "1"
        write_val "$kgsl/thermal_pwrlevel" "1" 
    fi
done

# 5. Restore Android Thermal Service
cmd thermalservice override-status 1 2>/dev/null
cmd thermalservice reset 2>/dev/null

# 6. Restart Thermal Services (The Real Fix)
get_thermal_services() {
    getprop | grep -E 'init.svc(\.vendor)?\.thermal' | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]'
}

for svc in $(get_thermal_services); do
    # Reset status and attempt start
    resetprop -n "init.svc.$svc" "stopped"
    start "$svc"
    setprop ctl.start "$svc"
done

# 7. Finalize Status
# Wait briefly for services to initialize, then force 'running' status
sleep 1
for svc in $(get_thermal_services); do
    resetprop -n "init.svc.$svc" "running"
done