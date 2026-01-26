#!/system/bin/sh

# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

CONFIG_FILE="/data/ProjectRaco/raco.txt"

sed -i 's/^STATE=.*/STATE=/' "$CONFIG_FILE"

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

# Ayunda Rusdi

# AmeRender
if grep -q "INCLUDE_ZETAMIN=1" "$CONFIG_FILE"; then
    sh /data/adb/modules/ProjectRaco/Scripts/Zetamin.sh
fi

############################
# Facur.sh
# @Koneko_dev
# Heavily modified to accomodate old devices
############################

settings put global kernel_cpu_thread_reader "num_buckets=0,collected_uids=system,minimum_total_cpu_usage_millis=600000" >/dev/null 2>&1
settings put global battery_stats_constants "battery_level_collection_delay_ms=1800000,proc_state_cpu_times_read_delay_ms=3600000000,read_binary_cpu_time=1,kernel_uid_readers_throttle_time=2000,track_cpu_active_cluster_time=false,external_stats_collection_rate_limit_ms=60000,max_history_files=1,max_history_buffer_kb=64" >/dev/null 2>&1

settings put system device_idle_constants "inactive_to=60000,sensing_to=0,locating_to=0,motion_inactive_to=0,idle_after_inactive_to=300000,min_time_to_alarm=600000" >/dev/null 2>&1

settings put global job_scheduler_constants "job_scheduler_quota_controller_constants=rate_limiting_window_ms=90000,max_job_count_active=60,max_session_count_active=60" >/dev/null 2>&1

settings put global activity_manager_constants "max_cached_processes=32,background_settle_time=60000,fgs_start_deny_exposure_time=10000" >/dev/null 2>&1
device_config put activity_manager proactive_kills_enabled false >/dev/null 2>&1

atrace --async_stop >/dev/null 2>&1
cmd window tracing stop >/dev/null 2>&1
echo 0 > /sys/kernel/tracing/tracing_on 2>/dev/null
echo 0 > /sys/kernel/debug/tracing/tracing_on 2>/dev/null

for queue in /sys/block/*/queue/scheduler; do
    echo "none" > "$queue" 2>/dev/null
done

echo 1 > /sys/module/workqueue/parameters/power_efficient 2>/dev/null

echo 60 > /proc/sys/vm/swappiness 2>/dev/null
echo 10 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null

echo 256 > /proc/sys/kernel/random/read_wakeup_threshold 2>/dev/null
echo 128 > /proc/sys/kernel/random/write_wakeup_threshold 2>/dev/null

############################
# End of Facur.sh
############################

send_notif "Project Raco" "Project Raco - オンライン" "TagRaco" "/data/local/tmp/logo.png"

# --- Project Raco Plugin Loader ---
PLUGIN_TXT="/data/ProjectRaco/Plugin.txt"
PLUGIN_DIR="/data/ProjectRaco/Plugins"

if [ -f "$PLUGIN_TXT" ]; then
    # Read Plugin.txt line by line (format: PluginID=1)
    while IFS='=' read -r plugin_id enabled || [ -n "$plugin_id" ]; do
        # Clean up whitespace/newlines just in case
        plugin_id=$(echo "$plugin_id" | tr -d '[:space:]')
        enabled=$(echo "$enabled" | tr -d '[:space:]')

        # If plugin is enabled (1), execute its service.sh
        if [ "$enabled" = "1" ]; then
            plugin_service="$PLUGIN_DIR/$plugin_id/service.sh"
            if [ -f "$plugin_service" ]; then
                chmod +x "$plugin_service"
                # Run in background (&) to ensure it doesn't block the main script loop
                sh "$plugin_service" &
            fi
        fi
    done < "$PLUGIN_TXT"
fi
# ----------------------------------

# Revert CPU governor to default after configured duration, only if INCLUDE_SANDEV=1
if grep -q "INCLUDE_SANDEV=1" "$CONFIG_FILE"; then
    SANDEV_DUR=$(grep '^SANDEV_DUR=' "$CONFIG_FILE" | cut -d'=' -f2)
    sleep "$SANDEV_DUR"
    
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

# HamadaAI
