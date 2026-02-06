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
INCLUDE_SANDEV=$(grep '^INCLUDE_SANDEV=' "$CONFIG_FILE" | cut -d'=' -f2)

if [ "$INCLUDE_SANDEV" = "1" ]; then
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

##############################
# KamiGO (Open Source with Permission from kaminarich)
# Version: 1.1
##############################

INCLUDE_SOC=$(grep '^SOC=' "$CONFIG_FILE" | cut -d'=' -f2)

if [ "$INCLUDE_SOC" = "1" ]; then
    tweak "/sys/kernel/fpsgo/fbt/enable_ceiling" "0"
    tweak "/sys/kernel/fpsgo/fbt/limit_cfreq" "0"
    tweak "/sys/kernel/fpsgo/fbt/limit_rfreq" "0"
    tweak "/sys/kernel/fpsgo/fbt/limit_uclamp" "0"
    tweak "/sys/module/mtk_fpsgo/parameters/bhr" "1"
    tweak "/sys/module/mtk_fpsgo/parameters/bhr_opp" "15"
    tweak "/sys/kernel/fpsgo/fbt/rescue_enable" "1"
    tweak "/sys/kernel/fpsgo/fbt/ultra_rescue" "1"
    tweak "/sys/module/mtk_fpsgo/parameters/rescue_percent" "95"
    tweak "/sys/module/mtk_fpsgo/parameters/qr_enable" "1"
    tweak "/sys/kernel/fpsgo/fstb/fstb_self_ctrl_fps_enable" "0"
    tweak "/sys/kernel/fpsgo/fstb/margin_mode" "1"
    tweak "/sys/pnpmgr/fpsgo_boost/boost_mode" "1"
    tweak "/sys/kernel/fpsgo/fbt/boost_VIP" "1"
    tweak "/sys/kernel/fpsgo/fbt/boost_ta" "1"
fi

# Run AnyaMelfissa.sh only if both INCLUDE_ANYA and ANYA are set to 1
INCLUDE_ANYA=$(grep '^INCLUDE_ANYA=' "$CONFIG_FILE" | cut -d'=' -f2)
ANYA_VAL=$(grep '^ANYA=' "$CONFIG_FILE" | cut -d'=' -f2)

if [ "$INCLUDE_ANYA" = "1" ] && [ "$ANYA_VAL" = "1" ]; then
    sh /data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh
    send_notif "Anya Melfissa" "Good Day! Thermal Is Dead BTW" "TagAnya" "/data/local/tmp/Anya.png"
fi

# Run KoboKanaeru.sh if INCLUDE_KOBO=1
INCLUDE_KOBO=$(grep '^INCLUDE_KOBO=' "$CONFIG_FILE" | cut -d'=' -f2)

if [ "$INCLUDE_KOBO" = "1" ]; then
    sh /data/adb/modules/ProjectRaco/Scripts/KoboKanaeru.sh
fi

# Ayunda Rusdi

# AmeRender
INCLUDE_ZETAMIN=$(grep '^INCLUDE_ZETAMIN=' "$CONFIG_FILE" | cut -d'=' -f2)

if [ "$INCLUDE_ZETAMIN" = "1" ]; then
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

############################
# GHenna - Tweaks
# @Hirauki
# Tweaks Taken From service.sh and cherry picked
############################

# 1. Enhanced Universal Deep Sleep Optimization
optimize_deep_sleep() {
    # Clean up logs
    rm -f /storage/emulated/0/*.log 2>/dev/null
    rm -f /data/log/*.log 2>/dev/null
    rm -f /cache/*.log 2>/dev/null
    
    # Device Idle Configuration
    dumpsys deviceidle reset 2>/dev/null
    dumpsys deviceidle enable light 2>/dev/null
    dumpsys deviceidle enable deep 2>/dev/null
    dumpsys deviceidle force-idle 2>/dev/null
    
    # Aggressive Doze Constants
    settings put global device_idle_constants inactive_to=30000,motion_inactive_to=0,wait_for_unlock=true 2>/dev/null
    
    # Disable keep-alive mechanisms
    settings put global low_power_mode 1 2>/dev/null
    settings put global low_power_mode_trigger_level 20 2>/dev/null
    
    # Disable wakeup sources that prevent deep sleep
    for wakeup in /sys/class/wakeup/*/active_count; do
        if [ -d "$(dirname "$wakeup")" ]; then
             echo "disabled" > "$(dirname "$wakeup")/active_wakeup" 2>/dev/null
        fi
    done
    
    # Disable wakelocks for common wake sources
    echo "0" > /sys/power/wake_lock 2>/dev/null || true
    
    # Trim memory caches
    pm trim-caches 999999999 2>/dev/null
}
optimize_deep_sleep

# 2. Enhanced GMS Doze Management
optimize_gms_doze() {
    su -c "pm set-inactive com.google.android.gms true" 2>/dev/null
    su -c "dumpsys deviceidle whitelist -com.google.android.gms" 2>/dev/null
    su -c "dumpsys deviceidle tempwhitelist -c com.google.android.gms" 2>/dev/null
}
optimize_gms_doze

# 3. Enhanced Tracing and Logging Optimization
disable_tracing_and_logging() {
    cmd accessibility stop-trace 2>/dev/null
    cmd input_method tracing stop 2>/dev/null
    cmd window tracing size 0 2>/dev/null
    cmd window tracing stop 2>/dev/null
    cmd statusbar tracing stop 2>/dev/null
    cmd memory_trace disable 2>/dev/null
    cmd animation tracing stop 2>/dev/null
    cmd package tracing stop 2>/dev/null
    cmd wm tracing stop 2>/dev/null
    cmd activity tracing stop 2>/dev/null
    cmd broadcast tracing disable 2>/dev/null
    atrace --async_stop >/dev/null 2>&1
    echo 0 > /sys/kernel/tracing/tracing_on 2>/dev/null
    echo 0 > /sys/kernel/debug/tracing/tracing_on 2>/dev/null
}
disable_tracing_and_logging

# 4. Aggressive Logcat Optimization
optimize_logcat() {
    logcat -c 2>/dev/null
    logcat -G 16K 2>/dev/null
    logcat -b all -G 16K 2>/dev/null
    logcat -b main -G 32K 2>/dev/null
    logcat -b system -G 16K 2>/dev/null
    logcat -b events -G 16K 2>/dev/null
    logcat -b crash -G 16K 2>/dev/null
    logcat -b kernel -G 16K 2>/dev/null
    
    setprop persist.sys.usb.config adb 2>/dev/null
    setprop ro.logd.size.stats 0 2>/dev/null
    setprop ro.logdumpd.enabled false 2>/dev/null
    
    echo "0" > /proc/sys/kernel/printk_ratelimit 2>/dev/null
    echo "0" > /proc/sys/kernel/sysctl_writes_strict 2>/dev/null
    
    if [ -d /sys/kernel/debug/tracing ]; then
        echo "0" > /sys/kernel/debug/tracing/tracing_on 2>/dev/null
        echo "nop" > /sys/kernel/debug/tracing/current_tracer 2>/dev/null
        echo "0" > /sys/kernel/debug/tracing/events/enable 2>/dev/null
    fi
    
    setprop debug.atrace.tags.enableflags 0 2>/dev/null
    setprop debug.force_rtl false 2>/dev/null
}
optimize_logcat

# 5. [BETA] Better Memory Management by Task Change
settings put global kernel_cpu_thread_reader "num_buckets=0,collected_uids=system,minimum_total_cpu_usage_millis=600000" >/dev/null 2>&1
settings put global battery_stats_constants "battery_level_collection_delay_ms=1800000,proc_state_cpu_times_read_delay_ms=3600000000,read_binary_cpu_time=1,kernel_uid_readers_throttle_time=2000,track_cpu_active_cluster_time=false,external_stats_collection_rate_limit_ms=60000,max_history_files=1,max_history_buffer_kb=64" >/dev/null 2>&1
settings put global job_scheduler_constants "job_scheduler_quota_controller_constants=rate_limiting_window_ms=90000,max_job_count_active=60,max_session_count_active=60" >/dev/null 2>&1
settings put global activity_manager_constants "max_cached_processes=32,background_settle_time=60000,fgs_start_deny_exposure_time=10000" >/dev/null 2>&1
device_config put activity_manager proactive_kills_enabled false >/dev/null 2>&1

change_task_affinity() {
    # $1:task_name $2:cpu_mask (hex format)
    local ps_ret
    ps_ret=$(ps -A 2>/dev/null || ps 2>/dev/null)
    for temp_pid in $(echo "$ps_ret" | grep -i -E "$1" | grep -v "PID" | awk '{print $1}'); do
        if [ -d "/proc/$temp_pid" ]; then
            for temp_tid in $(ls "/proc/$temp_pid/task/" 2>/dev/null); do
                taskset -p "$2" "$temp_tid" 2>/dev/null || echo "$temp_tid" > "/dev/cpuset/top-app/tasks" 2>/dev/null
            done
        fi
    done
}

change_task_nice() {
    # $1:task_name $2:nice(relative to 120)
    local ps_ret
    ps_ret=$(ps -A 2>/dev/null || ps 2>/dev/null)
    for temp_pid in $(echo "$ps_ret" | grep -i -E "$1" | grep -v "PID" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/" 2>/dev/null); do
            renice -n +40 -p "$temp_tid" 2>/dev/null
            renice -n -19 -p "$temp_tid" 2>/dev/null
            renice -n "$2" -p "$temp_tid" 2>/dev/null
        done
    done
}

optimize_memory_management_tasks() {
    change_task_nice "kswapd" "-2"
    change_task_affinity "kswapd" "7f"
    change_task_nice "oom_reaper" "-2"
    change_task_affinity "oom_reaper" "7f"
    change_task_nice "kcompactd" "-5" 2>/dev/null
    change_task_nice "kthreadd" "-5" 2>/dev/null
    change_task_nice "writeback" "-5" 2>/dev/null
}
optimize_memory_management_tasks

# 6. RCU, Kernel Optimization, Scheduler Tuning
echo "1" > /sys/kernel/rcu_normal 2>/dev/null
echo "0" > /sys/kernel/rcu_expedited 2>/dev/null
echo "1" > /proc/sys/kernel/timer_migration 2>/dev/null
echo "0" > /sys/devices/system/cpu/isolated 2>/dev/null
echo "120" > /proc/sys/kernel/hung_task_timeout_secs 2>/dev/null

[ -d /dev/stune/top-app ] && {
    echo "0" > /dev/stune/top-app/schedtune.boost 2>/dev/null
    echo "1" > /dev/stune/top-app/schedtune.prefer_idle 2>/dev/null
}

if [ -f /sys/kernel/debug/sched_features ]; then
    echo "NEXT_BUDDY" > /sys/kernel/debug/sched_features 2>/dev/null
    echo "TTWU_QUEUE" > /sys/kernel/debug/sched_features 2>/dev/null
    echo "ENERGY_AWARE" > /sys/kernel/debug/sched_features 2>/dev/null
fi

# 7. Scheduler Parameters Optimization
for dev in sda loop0 loop1 loop2 loop3 loop4 loop5 loop6 loop7 dm-0 mmcblk0 mmcblk1 mmcblk0rpmb; do
    if [ -e "/sys/block/${dev}/queue/iostats" ]; then echo "0" > "/sys/block/${dev}/queue/iostats" 2>/dev/null; fi
    if [ -e "/sys/block/${dev}/queue/scheduler" ]; then echo "none" > "/sys/block/${dev}/queue/scheduler" 2>/dev/null; fi
done

[ -f /proc/sys/kernel/sched_energy_aware ] && echo "1" > /proc/sys/kernel/sched_energy_aware 2>/dev/null
[ -f /proc/sys/kernel/sched_nr_migrate ] && echo "32" > /proc/sys/kernel/sched_nr_migrate 2>/dev/null
[ -f /proc/sys/kernel/sched_child_runs_first ] && echo "1" > /proc/sys/kernel/sched_child_runs_first 2>/dev/null
[ -f /proc/sys/kernel/sched_latency_ns ] && echo "4000000" > /proc/sys/kernel/sched_latency_ns 2>/dev/null
[ -f /proc/sys/kernel/sched_autogroup_enabled ] && echo "0" > /proc/sys/kernel/sched_autogroup_enabled 2>/dev/null
[ -f /proc/sys/kernel/sched_migration_cost_ns ] && echo "50000" > /proc/sys/kernel/sched_migration_cost_ns 2>/dev/null
[ -f /proc/sys/kernel/sched_min_granularity_ns ] && echo "1000000" > /proc/sys/kernel/sched_min_granularity_ns 2>/dev/null
[ -f /proc/sys/kernel/sched_wakeup_granularity_ns ] && echo "1500000" > /proc/sys/kernel/sched_wakeup_granularity_ns 2>/dev/null
echo 1 > /sys/module/workqueue/parameters/power_efficient 2>/dev/null

# 8. Module Parameters Optimization
optimize_module_params() {
    [ -f /sys/module/mmc_core/parameters/use_spi_crc ] && echo "0" > /sys/module/mmc_core/parameters/use_spi_crc 2>/dev/null
    [ -f /sys/module/cpufreq_bouncing/parameters/enable ] && echo "0" > /sys/module/cpufreq_bouncing/parameters/enable 2>/dev/null
    [ -f /sys/module/tcp_cubic/parameters/beta ] && echo "819" > /sys/module/tcp_cubic/parameters/beta 2>/dev/null
    [ -f /sys/module/tcp_cubic/parameters/fast_convergence ] && echo "1" > /sys/module/tcp_cubic/parameters/fast_convergence 2>/dev/null
    [ -f /sys/module/timer/parameters/sample_period ] && echo "1000000" > /sys/module/timer/parameters/sample_period 2>/dev/null
}
optimize_module_params

# 9. Kernel Logging Optimization
optimize_kernel_logging() {
    [ -f /proc/sys/kernel/printk ] && echo "0 0 0 0" > /proc/sys/kernel/printk 2>/dev/null
    [ -f /proc/sys/kernel/printk_devkmsg ] && echo "off" > /proc/sys/kernel/printk_devkmsg 2>/dev/null
    [ -f /sys/module/printk/parameters/pid ] && echo "0" > /sys/module/printk/parameters/pid 2>/dev/null
    [ -f /sys/module/printk/parameters/cpu ] && echo "0" > /sys/module/printk/parameters/cpu 2>/dev/null
    [ -f /sys/module/sync/parameters/fsync_enabled ] && echo "N" > /sys/module/sync/parameters/fsync_enabled 2>/dev/null
    [ -f /sys/module/printk/parameters/printk_ratelimit ] && echo "0" > /sys/module/printk/parameters/printk_ratelimit 2>/dev/null
}
optimize_kernel_logging

# 10. Upgrade Disable Kernel Panic
disable_panic_handling() {
    local p
    for p in /proc/sys/kernel/panic \
             /proc/sys/kernel/panic_on_oops \
             /proc/sys/kernel/panic_on_warn \
             /proc/sys/kernel/panic_on_rcu_stall \
             /sys/module/kernel/parameters/panic \
             /sys/module/kernel/parameters/panic_on_warn \
             /sys/module/kernel/parameters/pause_on_oops \
             /sys/module/kernel/panic_on_rcu_stall; do
        if [ -f "$p" ]; then echo "0" > "$p" 2>/dev/null; fi
    done

    # Pattern based
    for f in /proc/sys/kernel/*panic* /sys/module/*/parameters/*panic* /sys/module/*/parameters/*pause_on_oops*; do
        if [ -f "$f" ]; then echo "0" > "$f" 2>/dev/null; fi
    done
}
disable_panic_handling

# 11. Upgrade Optimization of Memory Cache
optimize_memory_cache() {
    [ -f /proc/sys/vm/drop_caches ] && echo "3" > /proc/sys/vm/drop_caches 2>/dev/null
    [ -f /proc/sys/vm/compact_memory ] && echo "1" > /proc/sys/vm/compact_memory 2>/dev/null
    [ -f /proc/sys/debug/exception-trace ] && echo "0" > /proc/sys/debug/exception-trace 2>/dev/null
    echo 80 > /proc/sys/vm/vfs_cache_pressure 2>/dev/null
    echo 60 > /proc/sys/vm/swappiness 2>/dev/null
}
optimize_memory_cache

# 12. Disable GPU Debug
disable_gpu_debug() {
    [ -f /sys/kernel/debug/dri/0/debug/enable ] && echo "0" > /sys/kernel/debug/dri/0/debug/enable 2>/dev/null
    [ -f /sys/module/spurious/parameters/noirqdebug ] && echo "1" > /sys/module/spurious/parameters/noirqdebug 2>/dev/null
    [ -f /sys/kernel/debug/gpu/enable ] && echo "0" > /sys/kernel/debug/gpu/enable 2>/dev/null
    [ -f /sys/kernel/debug/hwcomposer/disable_debug ] && echo "1" > /sys/kernel/debug/hwcomposer/disable_debug 2>/dev/null
    [ -f /sys/kernel/debug/gpumemdebug ] && echo "0" > /sys/kernel/debug/gpumemdebug 2>/dev/null
}
disable_gpu_debug

# 13. HWUI Performance
optimize_hwui() {
    setprop debug.sf.hw 1
    setprop debug.sf.latch_unsignaled 1
    setprop debug.hwui.drop_shadow_cache_size 6
    setprop debug.hwui.texture_cache_flushrate 0.4
    setprop ro.hwui.render_ahead_lines 2
    setprop ro.hwui.texture_cache_size 72
}
optimize_hwui

# 14. Upgrade LMK Tweaks
optimize_lmk() {
    [ -f /sys/module/lowmemorykiller/parameters/minfree ] && echo "1024,2048,4096,8192,12288,16384" > /sys/module/lowmemorykiller/parameters/minfree 2>/dev/null
    [ -f /sys/module/lowmemorykiller/parameters/cost ] && echo "32" > /sys/module/lowmemorykiller/parameters/cost 2>/dev/null
    echo 256 > /proc/sys/kernel/random/read_wakeup_threshold 2>/dev/null
    echo 128 > /proc/sys/kernel/random/write_wakeup_threshold 2>/dev/null
}
optimize_lmk

############################
# End of GHenna - Tweaks
############################

############################
# Yanz AIO Gaming 4.1
# @Xyanz_25
# Partial adding to avoid conflict
############################
yanz_universal() {
    # Entropy Tweaks
    tweak "64" "/proc/sys/kernel/random/read_wakeup/threshold"
    tweak "128" "/proc/sys/kernel/random/write_wakeup/threshold"
    tweak "128" "/proc/sys/kernel/random/read_wakeup_threshold"
    tweak "1024" "/proc/sys/kernel/random/write_wakeup_threshold"

    # Printk Tweaks
    if [ -w /proc/sys/kernel/printk ]; then
        echo "0 0 0 0" > /proc/sys/kernel/printk
    fi
    tweak "0" "/proc/sys/kernel/printk_devkmsg"
    tweak "0" "/sys/module/binder/parameters/debug_mask"
    tweak "0" "/sys/module/printk/parameters/cpu"
    tweak "1" "/sys/module/printk/parameters/console_suspend"
    tweak "1" "/sys/module/printk/parameters/ignore_loglevel"
    tweak "0" "/sys/module/printk/parameters/pid"
    tweak "0" "/sys/module/printk/parameters/time"
    tweak "0" "/sys/module/printk/parameters/printk_ratelimit"

    # Zram & VM Tweaks
    tweak "0" "/sys/module/lowmemorykiller/parameters/enable_adaptive_lmk"
    tweak "90" "/proc/sys/vm/overcommit_ratio"
    tweak "0" "/proc/sys/vm/extra_free_kbytes"
    tweak "3072" "/proc/sys/vm/min_free_kbytes"
    tweak "0" "/proc/sys/vm/oom_kill_allocating_task"
    
    # Dirty Ratio (Performance bias)
    tweak "30" "/proc/sys/vm/dirty_ratio"
    tweak "5" "/proc/sys/vm/dirty_background_ratio"
    tweak "3000" "/proc/sys/vm/dirty_writeback_centises"

    # Disable Fsync & Vsync related
    tweak "N" "/sys/module/sync/parameters/fsync_enabled"
    tweak "0" "/sys/kernel/debug/mdss_panel_fb0/intf0/mipi/hw_vsync_mode"
    tweak "0" "/sys/kernel/debug/mdss_panel_fb0/intf0/mipi/vsync_enable"
}
yanz_universal

############################
# End of Yanz AIO Gaming 4.1
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
if [ "$INCLUDE_SANDEV" = "1" ]; then
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

#Endfield Engine