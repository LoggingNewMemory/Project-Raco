#!/system/bin/sh
#
# Telegram: @RiProG | Channel: @RiOpSo | Group: @RiOpSoDisc

# RiProG Thermal 2.6.1 (RTN 2.6.1 Low + UnSensor) - Converted to shell by Kanagawa Yamada

get_properties() {
    getprop | grep 'thermal' | cut -d '[' -f2 | cut -d ']' -f1
}

get_properties | while read -r prop; do
    if [ -n "$prop" ]; then
        status=$(getprop "$prop")
        if [ "$status" = "running" ] || [ "$status" = "restarting" ]; then
            service=${prop:9}
            setprop stopped "$service"
        fi
    fi
done

#################################
# Celestial Thermal
# By: Kazuyoo 
# Note: Remove Wait Boot Complete, Remove Notification
#################################

write_val() {
    local file="$1"
    local value="$2"
    if [ -e "$file" ]; then
        chmod +w "$file" 2>/dev/null
        echo "$value" > "$file"
    fi
}

lock_val() {
    for p in $2; do
        if [ -f "$p" ]; then
            chown root:root "$p"
            chmod 0666 "$p"
            echo "$1" >"$p"
            chmod 0444 "$p"
        fi
    done
}

mutate() {
    for p in $2; do
        if [ -f "$p" ]; then
            chmod 0666 "$p"
            echo "$1" >"$p"
        fi
    done
}

# ----------------- OPTIMIZATION SECTIONS -----------------
# Disable GPU frequency limits
disable_limit_gpu() {
  for ZONE in /sys/class/thermal/thermal_zone*; do TYPE=$(cat "$ZONE/type" 2>/dev/null); case "$TYPE" in *gpu*|*ddr*) for TP in "$ZONE"/trip_point_*_temp; do [ -f "$TP" ] && [ "$(cat "$TP")" -lt 90000 ] && echo 95000 > "$TP"; done ;; esac done
    
  for gpufreq in /proc/gpufreq; do if [ -d "$gpufreq" ]; then write_val "$gpufreq/gpufreq_power_limited" "0"; write_val "$gpufreq/gpufreq_limited_thermal_ignore" "1"; write_val "$gpufreq/gpufreq_limited_oc_ignore" "1"; write_val "$gpufreq/gpufreq_limited_low_batt_volume_ignore" "1"; write_val "$gpufreq/gpufreq_limited_low_batt_volt_ignore" "1"; fi done

  for kgsltemp in $(find /sys/devices/soc/*/kgsl/kgsl-3d0/ -name '*temp*'); do [ -e "$kgsltemp" ] && chmod -R 000 "$kgsltemp"; done

  for kgsl in /sys/class/kgsl/kgsl-3d0; do if [ -d "$kgsl" ]; then write_val "$kgsl/throttling" "0"; write_val "$kgsl/max_gpuclk" "0"; write_val "$kgsl/force_clk_on" "1"; write_val "$kgsl/adreno_idler_active" "N"; write_val "$kgsl/thermal_pwrlevel" "0"; fi done
}

# Stop thermal-related processes
stopped_thermal_process() {
  for pid in $(ps -A | grep -i 'thermal' | awk '{print $2}'); do [ -n "$pid" ] && su -c kill -9;kill -9 "$pid";done
  
  for pid in $(grep -l 'thermal' /proc/*/comm 2>/dev/null | awk -F'/' '{print $3}'); do [ -n "$pid" ] && su -c kill -9 "$pid";kill -9 "$pid";done

  for svc in $(getprop | grep -E 'init.svc(\.vendor)?\.thermal' | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]'); do pid=$(ps | grep "$svc" | awk '{print $2}'); [ -n "$pid" ] && su -c kill -9 "$pid"; kill -9 "$pid"; su -c stop "$svc";done

  for initfile in $(find /system/etc/init/ /system/vendor/etc/init/ -name '*thermal*'); do pid=$(ps | grep "$initfile" | awk '{print $2}'); [ -n "$pid" ] && su -c kill -9 "$pid";kill -9 "$pid";done
}

# Reset thermal-related properties
stopped_thermal_prop() {
  for prop in $(getprop | grep -E 'init\.svc\..*thermal' | cut -d: -f1 | tr -d '[]'); do val=$(getprop "$prop"); [ "$val" = "running" ] && resetprop -n "$prop" "restarting"; [ "$val" = "stopped" ] && resetprop -n "$prop" "stopped"; done

  for prop in $(getprop | grep -E 'sys\..*thermal' | cut -d: -f1 | tr -d '[]'); do val=$(getprop "$prop"); [ "$val" = "1" ] && resetprop -n "$prop" "0"; [ "$val" = "running" ] && resetprop -n "$prop" "stopped"; [ "$val" = "true" ] && resetprop -n "$prop" "false"; done

  for prop in $(getprop | grep 'init.svc_debug_pid.*thermal' | cut -d: -f1 | tr -d '[]'); do resetprop -n "$prop" ""; done
  
  for prop in $(getprop | grep -E 'thermal_config|tran\.hbm\.thermal' | awk -F'[][]' '{print $2}'); do resetprop -n "$prop" "0"; done
}

# Disable all thermal protections and monitoring
disable_thermal_protection() {
  find /sys/devices/virtual/thermal/thermal_zone*/ \
    -name '*temp*' -o -name '*trip_point_*' -o -name '*type*' | while read -r file; do chmod -R 000 "$file"; done

  find /sys/firmware/devicetree/base/soc/*/ \
    -name '*thermal*' -o -name '*temp*' -o -name '*limit_info*' -o -name '*name*' | while read -r file; do chmod -R 000 "$file"; done

  for hwmon in /sys/devices/virtual/hwmon/hwmon*; do
    [ -d "$hwmon" ] && chmod -R 000 "$hwmon"
  done

  for thermmode in /sys/devices/virtual/thermal/thermal_zone*/mode; do chmod -R 644 "$thermmode"; write_val "$thermmode" "disabled"; done
}

# Disable CPU core control (hotplug) & MSM thermal & Other
other_disable_thermal() {
  for cpu in /sys/devices/system/cpu/cpu[0,4,7]/core_ctl; do chmod 666 "$cpu/enable"; write_val "$cpu/enable" "0"; chmod 444 "$cpu/enable"; done

  find /sys/ -name enabled | grep 'msm_thermal' | while IFS= read -r msm_thermal_status; do if [ "$(cat "$msm_thermal_status")" = 'Y' ]; then write_val "$msm_thermal_status" "N"; fi; if [ "$(cat "$msm_thermal_status")" = '1' ]; then write_val "$msm_thermal_status" "0"; fi done
  
  # Disable I/O statistics
  for queue in /sys/block/*/queue; do write_val "$queue/iostats" "0"; write_val "$queue/iosched/slice_idle" "0"; done
  
  # [2] PPM_POLICY_FORCE_LIMIT: enabled | [3] PPM_POLICY_PWR_THRO: enabled | [4] PPM_POLICY_THERMAL: enabled | [6] PPM_POLICY_HARD_USER_LIMIT: enabled | [7] PPM_POLICY_USER_LIMIT: enabled
  for policy in 2 3 4 6 7; do write_val "/proc/ppm/enabled" "1"; write_val "/proc/ppm/policy_status" "$policy 0"; done
  
  # Modify thermal config if exists
  for sthermal in $(find /sys/class/thermal/thermal_message/ -name 'sconfig'); do chmod 644 "$sthermal"; write_val "$sthermal" "10"; chmod 444 "$sthermal"; done
  
  # Disable Kernel Panic
  for KERNEL_PANIC in $(find /proc/sys/ /sys/ -name '*panic*'); do
    write_val "$KERNEL_PANIC" "0"
  done
  
  # Disable logs & debuggers (thx to @Bias_Khaliq)
  for exception_trace in $(find /proc/sys/ -name exception-trace); do
    write_val "$exception_trace" "0"
  done

  for sched_schedstats in $(find /proc/sys/ -name sched_schedstats); do
    write_val "$sched_schedstats" "0"
  done

  for printk in $(find /proc/sys/ -name printk); do
    write_val "$printk" "0 0 0 0"
  done

  for printk_devkmsg in $(find /proc/sys/ -name printk_devkmsg); do
    write_val "$printk_devkmsg" "off"
  done

  for tracing_on in $(find /proc/sys/ -name tracing_on); do
    write_val "$tracing_on" "0"
  done

  for log_ecn_error in $(find /sys/ -name log_ecn_error); do
    write_val "$log_ecn_error" "0"
  done

  for snapshot_crashdumper in $(find /sys/ -name snapshot_crashdumper); do
    write_val "$snapshot_crashdumper" "0"
  done

  # Disable CRC check
  for use_spi_crc in $(find /sys/module -name use_spi_crc); do
    write_val "$use_spi_crc" "0"
  done
  
  # disable power efficient from disable thermal G99 @UtsukushiDatta
  chmod 0644 "/sys/module/workqueue/parameters/power_efficient";write_val "/sys/module/workqueue/parameters/power_efficient" "N";chmod 0644 "/sys/module/workqueue/parameters/disable_numa";write_val "/sys/module/workqueue/parameters/disable_numa" "N"
  
  # FPSGO thermal
  write_val "/sys/kernel/fpsgo/fbt/thrm_enable" "0"; write_val "/sys/kernel/fpsgo/fbt/thrm_temp_th" "95000"; write_val "/sys/kernel/fpsgo/fbt/thrm_limit_cpu" "-1"; write_val "/sys/kernel/fpsgo/fbt/thrm_sub_cpu" "-1"
  
  # Exynos hotplug
  mutate "0" "/sys/power/cpuhotplug/enabled"; mutate "0" "/sys/devices/system/cpu/cpuhotplug/enabled"
  
  # Block binary executable by @Kurumi<3
  mount -o bind /dev/null /vendor/bin/hw/thermal-hal-2-0;mount -o bind /dev/null /vendor/bin/thermald
  
  # Disable scheduler boost
  write_val "/proc/sys/kernel/sched_boost" "0"
  
  # MTK-EARA
  lock_val "0" "/sys/kernel/eara_thermal/enable"
  
  # thermal throttle transsion
  if resetprop debug.thermal.throttle.support | grep -q 'yes'; then
    su -c "resetprop -n -v debug.thermal.throttle.support no"
  fi
  
  # Disable thermal service
  cmd thermalservice override-status 0
  
  # remove cache thermal
  rm -f "/data/vendor/thermal/config"; rm -f "/data/vendor/thermal/thermal.dump"; rm -f "/data/vendor/thermal/thermal_history.dump"
}

# ----------------- MAIN EXECUTION -----------------
main() {
  disable_limit_gpu
  stopped_thermal_process
  stopped_thermal_prop
  disable_thermal_protection
  other_disable_thermal

# To Spoof Thermal Running in case some games need thermal
  get_properties | while read -r prop; do
    if [ -n "$prop" ]; then
      resetprop -n "$prop" "running"
    fi
  done
}

# Always return success, even if the last write fails
sync && main && exit 0