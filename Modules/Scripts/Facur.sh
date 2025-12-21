############################
# Facur.sh
# @Koneko_dev
# This supposed to give a tweaks to kernel
# Targets generics devices, so might will be upraded later
############################

settings put global kernel_cpu_thread_reader "num_buckets=0,collected_uids=system,minimum_total_cpu_usage_millis=600000" >/dev/null 2>&1
settings put global battery_stats_constants "battery_level_collection_delay_ms=1800000,proc_state_cpu_times_read_delay_ms=3600000000,read_binary_cpu_time=1,kernel_uid_readers_throttle_time=2000,track_cpu_active_cluster_time=false,external_stats_collection_rate_limit_ms=60000,max_history_files=1,max_history_buffer_kb=64" >/dev/null 2>&1

cmd deviceidle enable all >/dev/null 2>&1
cmd deviceidle force-idle deep >/dev/null 2>&1
cmd deviceidle step deep >/dev/null 2>&1

settings put global job_scheduler_constants "job_scheduler_quota_controller_constants=rate_limiting_window_ms=90000,max_job_count_active=60,max_session_count_active=60" >/dev/null 2>&1

settings put system device_idle_constants "sensing_to=0,locating_to=0,motion_inactive_to=0,idle_pending_factor=2.0,idle_factor=2.0,inactive_to=60000,idle_pending_to=90000,max_idle_to=86400000,max_idle_pending_to=300000,idle_after_inactive_to=120000,location_accuracy=50.0,min_time_to_alarm=300000,idle_to=1800000,max_temp_app_whitelist_duration=30000" >/dev/null 2>&1

settings put global activity_manager_constants "full_pss_lowered_interval=7200000,kill_bg_restricted_cached_idle_settle_time=30000,power_check_max_cpu_4=0,power_check_max_cpu_1=0,power_check_max_cpu_2=0,kill_bg_restricted_cached_idle=true,full_pss_min_interval=7200000,power_check_max_cpu_3=0,system_exempt_power_restrictions_enabled=true" >/dev/null 2>&1
device_config put activity_manager proactive_kills_enabled false >/dev/null 2>&1
device_config put activity_manager low_swap_threshold_percent "0.2" >/dev/null 2>&1

atrace --async_stop >/dev/null 2>&1
cmd window tracing stop >/dev/null 2>&1
echo 0 > /sys/kernel/tracing/tracing_on 2>/dev/null
echo 0 > /sys/kernel/debug/tracing/tracing_on 2>/dev/null

for queue in /sys/block/*/queue/scheduler; do
    echo "noop" > "$queue" 2>/dev/null
done

echo 0 > /proc/sys/kernel/randomize_va_space 2>/dev/null
echo 1 > /sys/module/workqueue/parameters/power_efficient 2>/dev/null

echo 0 > /sys/module/lowmemorykiller/parameters/enable_lmk 2>/dev/null
echo 0 > /sys/module/lowmemorykiller/parameters/enable_adaptive_lmk 2>/dev/null

echo 512 > /proc/sys/kernel/random/read_wakeup_threshold 2>/dev/null
echo 256 > /proc/sys/kernel/random/write_wakeup_threshold 2>/dev/null