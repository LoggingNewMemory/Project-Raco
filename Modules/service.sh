#!/system/bin/sh

# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

CONFIG_FILE="/data/ProjectRaco/raco.txt"

# Define the function to change the CPU governor.
# It will only be called if INCLUDE_SANDEV is set to 1.
change_cpu_gov() {
  chmod 644 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
  echo "$1" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
  chmod 444 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
}

# Set CPU governor to performance only if INCLUDE_SANDEV=1
if grep -q "INCLUDE_SANDEV=1" "$CONFIG_FILE"; then
    change_cpu_gov performance
fi

# Mali Scheduler Tweaks By: MiAzami
mali_dir=$(ls -d /sys/devices/platform/soc/*mali*/scheduling 2>/dev/null | head -n 1)
mali1_dir=$(ls -d /sys/devices/platform/soc/*mali* 2>/dev/null | head -n 1)

tweak() {
    if [ -e "$1" ]; then
        echo "$2" > "$1"
    fi
}

if [ -n "$mali_dir" ]; then
    tweak "$mali_dir/serialize_jobs" "full"
fi

if [ -n "$mali1_dir" ]; then
    tweak "$mali1_dir/js_ctx_scheduling_mode" "1"
fi

tweak 0 /proc/sys/kernel/panic
tweak 0 /proc/sys/kernel/panic_on_oops
tweak 0 /proc/sys/kernel/panic_on_warn
tweak 0 /proc/sys/kernel/softlockup_panic

# Run AnyaMelfissa.sh only if both INCLUDE_ANYA and ANYA are set to 1
if grep -q "INCLUDE_ANYA=1" "$CONFIG_FILE" && grep -q "ANYA=1" "$CONFIG_FILE"; then
    sh /data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh
    su -lp 2000 -c "cmd notification post -S bigtext -t 'Anya Melfissa' -i file:///data/local/tmp/Anya.png -I file:///data/local/tmp/Anya.png TagAnya 'Good Day! Thermal Is Dead BTW'"
fi

# Run KoboKanaeru.sh if INCLUDE_KOBO=1
if grep -q "INCLUDE_KOBO=1" "$CONFIG_FILE"; then
    sh /data/adb/modules/ProjectRaco/Scripts/KoboKanaeru.sh
fi

# Run Zeta.sh if INCLUDE_ZETA=1
if grep -q "INCLUDE_ZETA=1" "$CONFIG_FILE"; then
    sh /data/adb/modules/ProjectRaco/Scripts/Zeta.sh
fi

# Ayunda Rusdi

# AmeRender
if grep -q "INCLUDE_AME=1" "$CONFIG_FILE"; then
    sh /data/adb/modules/ProjectRaco/Scripts/AmeRender.sh
fi

# Facur.sh
sh /data/adb/modules/ProjectRaco/Scripts/Facur.sh

# This script will be executed in late_start service mode
su -lp 2000 -c "cmd notification post -S bigtext -t 'Project Raco' -i file:///data/local/tmp/logo.png -I file:///data/local/tmp/logo.png TagRaco 'Project Raco - オンライン'"

# Revert CPU governor to default after 20 seconds, only if INCLUDE_SANDEV=1
if grep -q "INCLUDE_SANDEV=1" "$CONFIG_FILE"; then
    sleep 10
    
    DEFAULT_CPU_GOV=$(grep '^GOV=' "$CONFIG_FILE" | cut -d'=' -f2)

    if [ -z "$DEFAULT_CPU_GOV" ]; then
        if [ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ] && grep -q "schedhorizon" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
            DEFAULT_CPU_GOV="schedhorizon"
        else
            DEFAULT_CPU_GOV="schedutil"
        fi
    fi

    change_cpu_gov "$DEFAULT_CPU_GOV"
fi