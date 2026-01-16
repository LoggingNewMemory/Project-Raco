#!/system/bin/sh

# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

CONFIG_FILE="/data/ProjectRaco/raco.txt"

if [ -f "$CONFIG_FILE" ]; then
    sed -i 's/^STATE=.*/STATE=/' "$CONFIG_FILE"
fi

LEGACY_NOTIF=$(grep '^LEGACY_NOTIF=' "$CONFIG_FILE" | cut -d'=' -f2)

send_notif() {
    local title="$1"
    local message="$2"
    local tag="$3"
    local icon_path="$4"

    if [ "$LEGACY_NOTIF" = "1" ]; then
        # Legacy Mode: No icons
        su -lp 2000 -c "cmd notification post -S bigtext -t '$title' '$tag' '$message'"
    else
        # Standard Mode: With icons
        su -lp 2000 -c "cmd notification post -S bigtext -t '$title' -i file://$icon_path -I file://$icon_path '$tag' '$message'"
    fi
}

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
    send_notif "Anya Melfissa" "Good Day! Thermal Is Dead BTW" "TagAnya" "/data/local/tmp/Anya.png"
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

# Cloudflare DNS
iptables -t nat -D OUTPUT -p udp --dport 53 -j DNAT --to-destination 1.1.1.1:53 2>/dev/null
iptables -t nat -D OUTPUT -p tcp --dport 53 -j DNAT --to-destination 1.1.1.1:53 2>/dev/null
iptables -t nat -A OUTPUT -p udp --dport 53 -j DNAT --to-destination 1.1.1.1:53
iptables -t nat -A OUTPUT -p tcp --dport 53 -j DNAT --to-destination 1.1.1.1:53

if settings get global private_dns_mode > /dev/null 2>&1; then
    settings put global private_dns_mode hostname
    settings put global private_dns_specifier 1dot1dot1dot1.cloudflare-dns.com
else
    setprop net.dns1 1.1.1.1
    setprop net.dns2 1.0.0.1
fi

send_notif "Project Raco" "Project Raco - オンライン" "TagRaco" "/data/local/tmp/logo.png"

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