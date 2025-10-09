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

###################################
# Carlotta Render (@Koneko_Dev)
# Version 1.0 
# Note: The purpose is different from Celestial Render
# This tweak surface flinger
###################################
refresh_rate="$(cmd display dump 2>/dev/null | grep -Eo 'fps=[0-9.]+' | cut -f2 -d= | awk '{printf "%.0f\n", $1}' | sort -nr | head -n1)"

if [ -z "$refresh_rate" ] || [ "$refresh_rate" -lt 1 ]; then
    refresh_rate="$(dumpsys display | grep -E 'mRefreshRate|frameRate' | grep -Eo '[0-9.]+' | head -n1 | awk '{printf "%.0f\n", $1}')"
fi

if [ -z "$refresh_rate" ] || [ "$refresh_rate" -lt 1 ]; then
    refresh_rate=60
fi

frame_duration_ns=$(echo "scale=25; 1000000000 / $refresh_rate" | bc)

if [ "$refresh_rate" -ge 120 ]; then
    app_phase_ratio=0.72      
    sf_phase_ratio=0.85       
    app_duration_ratio=0.58   
    sf_duration_ratio=0.32    
    
elif [ "$refresh_rate" -ge 90 ]; then
    app_phase_ratio=0.70
    sf_phase_ratio=0.82  
    app_duration_ratio=0.62
    sf_duration_ratio=0.30
    
elif [ "$refresh_rate" -ge 75 ]; then
    app_phase_ratio=0.68
    sf_phase_ratio=0.80
    app_duration_ratio=0.65
    sf_duration_ratio=0.28
    
else
    app_phase_ratio=0.65     
    sf_phase_ratio=0.75      
    app_duration_ratio=0.68  
    sf_duration_ratio=0.25    
fi

app_phase_offset_ns=$(echo "scale=0; (-$frame_duration_ns * $app_phase_ratio) / 1" | bc)
sf_phase_offset_ns=$(echo "scale=0; (-$frame_duration_ns * $sf_phase_ratio) / 1" | bc)

app_duration=$(echo "scale=0; ($frame_duration_ns * $app_duration_ratio) / 1" | bc)
sf_duration=$(echo "scale=0; ($frame_duration_ns * $sf_duration_ratio) / 1" | bc)

app_end_time=$(echo "scale=0; $app_phase_offset_ns + $app_duration" | bc)
sf_end_time=$(echo "scale=0; $sf_phase_offset_ns + $sf_duration" | bc)

min_margin=$(echo "scale=0; $frame_duration_ns * 0.08 / 1" | bc)
dead_time=$(echo "scale=0; -($app_end_time + $sf_phase_offset_ns)" | bc)

if [ $(echo "$dead_time < $min_margin" | bc) -eq 1 ]; then
    adjustment=$(echo "scale=0; $min_margin - $dead_time" | bc)
    app_duration=$(echo "scale=0; $app_duration - $adjustment" | bc)
fi

min_phase_duration=$(echo "scale=0; $frame_duration_ns * 0.12 / 1" | bc)
if [ $(echo "$app_duration < $min_phase_duration" | bc) -eq 1 ]; then
    app_duration=$min_phase_duration
fi
if [ $(echo "$sf_duration < $min_phase_duration" | bc) -eq 1 ]; then
    sf_duration=$min_phase_duration
fi

app_duration=$(printf "%.0f" "$app_duration")
sf_duration=$(printf "%.0f" "$sf_duration")
app_phase_offset_ns=$(printf "%.0f" "$app_phase_offset_ns")
sf_phase_offset_ns=$(printf "%.0f" "$sf_phase_offset_ns")

setprop debug.sf.early.app.duration "$app_duration"
setprop debug.sf.earlyGl.app.duration "$app_duration" 
setprop debug.sf.late.app.duration "$app_duration"

setprop debug.sf.early.sf.duration "$sf_duration"
setprop debug.sf.earlyGl.sf.duration "$sf_duration"
setprop debug.sf.late.sf.duration "$sf_duration"

setprop debug.sf.early_app_phase_offset_ns "$app_phase_offset_ns"
setprop debug.sf.high_fps_early_app_phase_offset_ns "$app_phase_offset_ns"
setprop debug.sf.high_fps_late_app_phase_offset_ns "$app_phase_offset_ns"
setprop debug.sf.early_phase_offset_ns "$sf_phase_offset_ns"
setprop debug.sf.high_fps_early_phase_offset_ns "$sf_phase_offset_ns"
setprop debug.sf.high_fps_late_sf_phase_offset_ns "$sf_phase_offset_ns"

if [ "$refresh_rate" -ge 120 ]; then
    threshold_ratio=0.28
elif [ "$refresh_rate" -ge 90 ]; then
    threshold_ratio=0.32
elif [ "$refresh_rate" -ge 75 ]; then
    threshold_ratio=0.35
else
    threshold_ratio=0.38
fi

phase_offset_threshold_ns=$(echo "scale=0; ($frame_duration_ns * $threshold_ratio) / 1" | bc)

max_threshold=$(echo "scale=0; $frame_duration_ns * 0.45 / 1" | bc)
min_threshold=$(echo "scale=0; $frame_duration_ns * 0.22 / 1" | bc)

if [ $(echo "$phase_offset_threshold_ns > $max_threshold" | bc) -eq 1 ]; then
    phase_offset_threshold_ns=$max_threshold
elif [ $(echo "$phase_offset_threshold_ns < $min_threshold" | bc) -eq 1 ]; then
    phase_offset_threshold_ns=$min_threshold  
fi

phase_offset_threshold_ns=$(printf "%.0f" "$phase_offset_threshold_ns")
setprop debug.sf.phase_offset_threshold_for_next_vsync_ns "$phase_offset_threshold_ns"

setprop debug.sf.enable_advanced_sf_phase_offset 1
setprop debug.sf.enable_cached_set_render_scheduling true
setprop debug.sf.enable_egl_image_tracker false
setprop debug.sf.enable_transaction_tracing false
setprop debug.sf.layer_caching_highlight false
setprop debug.sf.trace_hint_sessions false
setprop debug.sf.vsp_trace false
setprop debug.sf.layer_history_trace false
setprop debug.sf.kernel_idle_timer_update_overlay false
setprop debug.sf.enable_layer_caching 1
setprop debug.sf.predict_hwc_composition_strategy 1
setprop debug.sf.disable_client_composition_cache 0
setprop debug.sf.luma_sampling 0
setprop debug.sf.show_predicted_vsync false
setprop debug.sf.treat_170m_as_sRGB 0
setprop debug.sf.use_phase_offsets_as_durations 0
setprop debug.sf.enable_hwc_vds 0
setprop debug.vulkan.enable_callback false
setprop debug.renderengine.vulkan false
setprop debug.renderengine.backend skiaglthreaded
setprop debug.stagefright.renderengine.backend skiaglthreaded
setprop debug.hwui.initialize_gl_always true
setprop debug.hwui.early_preload_gl_context true

fps_int=$(printf "%.0f" "$refresh_rate")
if [ "$fps_int" -ge 120 ]; then
    timeout=42 
elif [ "$fps_int" -ge 90 ]; then
    timeout=67  
else
    timeout=133
fi

if [ "$timeout" -lt 16 ]; then 
   timeout=16
elif [ "$timeout" -gt 1000 ]; then
    timeout=1000
fi

setprop debug.sf.layer_caching_active_layer_timeout_ms $timeout

#####################################
# End of Carlotta Render
#####################################

###################################
# Celestial Render FlowX (@Kzuyoo)
# Version: 1.6G
# Note: Notification Disabled, Wait boot complete removed
# Purpose of this is the Render (GPU, etc)
###################################
#!/system/bin/sh
# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
# This will make sure your module will still work
# if Magisk change its mount point in the future
MODDIR=${0%/*}

# ----------------- VARIABLES -----------------
MALI_PATH="/proc/mali"
ps_ret="$(ps -Ao pid,args)"
GPUF_PATH="/proc/gpufreq"
GPUF_PATH2="/proc/gpufreqv2"
GED_PATH2="/sys/kernel/debug/ged/hal"
ADRENO_PATH="/sys/class/kgsl/kgsl-3d0"
GED_PATH="/sys/module/ged/parameters"
PVR_PATH2="/sys/kernel/debug/pvr/apphint"
PVR_PATH="/sys/module/pvrsrvkm/parameters"
PLATFORM_GPU_PATH="/sys/devices/platform/gpu"
ADRENO_PATH3="/sys/module/adreno_idler/parameters"
KERNEL_FPSGO_PATH="/sys/kernel/debug/fpsgo/common"
ADRENO_PATH2="/sys/kernel/debug/kgsl/kgsl-3d0/profiling"
GPUFREQ_TRACING_PATH="/sys/kernel/debug/tracing/events/mtk_events"
FPS=$(dumpsys display | grep -m1 "mDefaultPeak" | awk '{print int($2)}')

# ----------------- HELPER FUNCTIONS -----------------
log() {
    echo "$1"
}

mask_val() {
    touch /data/local/tmp/mount_mask
    for p in $2; do
      if [ -f "$p" ]; then
         umount "$p"
         chmod 644 "$p"
         echo "$1" >"$p"
         mount --bind /data/local/tmp/mount_mask "$p"
      fi
    done
}

write_val() {
    local file="$1"
    local value="$2"
    if [ -e "$file" ]; then
        chmod +w "$file" 2>/dev/null
        echo "$value" > "$file" && log "Write : $file → $value" || log "Failed to Write : $file"
    fi
}

change_task_cgroup() {
    # $1:task_name $2:cgroup_name $3:"cpuset"/"stune"
    local comm
    for temp_pid in $(echo "$ps_ret" | grep -i -E "$1" | grep -v "PID" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            echo "$temp_tid" >"/dev/$3/$2/tasks"
        done
    done
}

change_task_nice() {
    # $1:task_name $2:nice(relative to 120)
    for temp_pid in $(echo "$ps_ret" | grep -i -E "$1" | grep -v "PID" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            renice -n +40 -p "$temp_tid"
            renice -n -19 -p "$temp_tid"
            renice -n "$2" -p "$temp_tid"
        done
    done
}

# ----------------- OPTIMIZATION SECTIONS -----------------
optimize_gpu_temperature() {
    # Adjust GPU and DDR temperature thresholds ( @Bias_khaliq )
    for THERMAL in /sys/class/thermal/thermal_zone*/type; do
        if grep -E "gpu|ddr" "$THERMAL" > /dev/null; then
          for ZONE in "${THERMAL%/*}"/trip_point_*_temp; do
            CURRENT_TEMP=$(cat "$ZONE")
            if [ "$CURRENT_TEMP" -lt "90000" ]; then
              write_val "$ZONE" "95000"
            fi
          done
        fi
    done
        
    # Disable Temperature for Adreno
    for all_thermal in $(find /sys/devices/soc/*/kgsl/kgsl-3d0/ -name *temp*); do
        chmod 000 $all_thermal
    done
}

additional_gpu_settings() {
    # Optimize GPU parameters via GED driver
    if [ -d "$GED_PATH" ]; then
        write_val "$GED_PATH/gpu_cust_boost_freq" "2000000"
        write_val "$GED_PATH/gpu_cust_upbound_freq" "2000000"
        write_val "$GED_PATH/ged_smart_boost" "1000"
        write_val "$GED_PATH/gpu_bottom_freq" "800000"
        write_val "$GED_PATH/boost_upper_bound" "100"
        write_val "$GED_PATH/gx_dfps" "$FPS"
        write_val "$GED_PATH/g_gpu_timer_based_emu" "1"
        write_val "$GED_PATH/boost_gpu_enable" "1"
        write_val "$GED_PATH/ged_boost_enable" "1"
        write_val "$GED_PATH/enable_gpu_boost" "1"
        write_val "$GED_PATH/gx_game_mode" "1"
        write_val "$GED_PATH/gx_boost_on" "1"
        write_val "$GED_PATH/boost_amp" "1"
        write_val "$GED_PATH/gx_3D_benchmark_on" "1"
        write_val "$GED_PATH/is_GED_KPI_enabled" "1"
        write_val "$GED_PATH/gpu_dvfs_enable" "1"
        write_val "$GED_PATH/ged_monitor_3D_fence_disable" "0"
        write_val "$GED_PATH/ged_monitor_3D_fence_debug" "0"
        write_val "$GED_PATH/ged_log_perf_trace_enable" "0"
        write_val "$GED_PATH/ged_log_trace_enable" "0"
        write_val "$GED_PATH/gpu_bw_err_debug" "0"
        write_val "$GED_PATH/gx_frc_mode" "0"
        write_val "$GED_PATH/gpu_idle" "0"
        write_val "$GED_PATH/gpu_debug_enable" "0"
    else
        echo "Unknown $GED_PATH path. Skipping optimization."
    fi
    
    # Additional kernel-ged GPU optimizations
    if [ -d "$GED_PATH2" ]; then
         write_val "$GED_PATH2/gpu_boost_level" "2"
         # source https://cpu52.com/archives/314.html
         write_val "$GED_PATH2/custom_upbound_gpu_freq" "1"
    else
        echo "Unknown $GED_PATH2 path. Skipping optimization."
    fi
    
    # Additional GPU settings for MediaTek ( @Bias_khaliq )
    if [ -d "$PLATFORM_GPU_PATH" ]; then
         write_val "$PLATFORM_GPU_PATH/dvfs_enable" "1"
         write_val "$PLATFORM_GPU_PATH/gpu_busy" "1"
    else
        echo "Unknown $GED_PATH2 path. Skipping optimization."
    fi
}

optimize_gpu_frequency() {
    # Optimize GPU frequency configurations
    gpu_freq="$(cat $GPUF_PATH/gpufreq_opp_dump | grep -o 'freq = [0-9]*' | sed 's/freq = //' | sort -nr | head -n 1)"
        write_val "$GPUF_PATH/gpufreq_opp_freq" "$gpu_freq"
    if [ -d "$GPUF_PATH" ]; then
        for i in $(seq 0 8); do
            write_val "$GPUF_PATH/limit_table" "$i 0 0"
        done
        write_val "$GPUF_PATH/limit_table" "1 1 1"
        write_val "$GPUF_PATH/gpufreq_limited_thermal_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_limited_oc_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_limited_low_batt_volume_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_limited_low_batt_volt_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_fixed_freq_volt" "0"
        write_val "$GPUF_PATH/gpufreq_opp_stress_test" "0"
        write_val "$GPUF_PATH/gpufreq_power_dump" "0"
        write_val "$GPUF_PATH/gpufreq_power_limited" "0"
    else
        echo "Unknown $GPUF_PATH path. Skipping optimization."
    fi

    # Optimize GPU frequency v2 configurations (Matt Yang)（吟惋兮改)
    gpu_freq="$(cat $GPUF_PATH2/gpu_working_opp_table | awk '{print $3}' | sed 's/,//g' | sort -nr | head -n 1)"
	gpu_volt="$(cat $GPUF_PATH2/gpu_working_opp_table | awk -v freq="$freq" '$0 ~ freq {gsub(/.*, volt: /, ""); gsub(/,.*/, ""); print}')"
	write_val "$GPUF_PATH2/fix_custom_freq_volt" "${gpu_freq} ${gpu_volt}"
    if [ -d "$GPUF_PATH2" ]; then
        for i in $(seq 0 10); do
            lock_val "$i 0 0" /proc/gpufreqv2/limit_table
        done
        # Enable only levels 1–3
        for i in 1 3; do
            write_val "$GPUF_PATH2/limit_table" "$i 1 1"
        done
        write_val "$GPUF_PATH2/aging_mode" "disable"
    else
        echo "Unknown $GPUF_PATH2 path. Skipping optimization."
    fi
}

optimize_pvr_settings() {
    # Adjust PowerVR settings for performance
    if [ -d "$PVR_PATH" ]; then
        write_val "$PVR_PATH/gpu_power" "2"
        write_val "$PVR_PATH/HTBufferSizeInKB" "512"
        write_val "$PVR_PATH/DisableClockGating" "1"
        write_val "$PVR_PATH/EmuMaxFreq" "2"
        write_val "$PVR_PATH/EnableFWContextSwitch" "1"
        write_val "$PVR_PATH/gPVRDebugLevel" "0"
        write_val "$PVR_PATH/gpu_dvfs_enable" "1"
    else
        echo "Unknown $PVR_PATH path. Skipping optimization."
    fi

    # Additional settings power vr apphint
    if [ -d "$PVR_PATH2" ]; then
        write_val "$PVR_PATH2/CacheOpConfig" "1"
        write_val "$PVR_PATH2/CacheOpUMKMThresholdSize" "512"
        write_val "$PVR_PATH2/EnableFTraceGPU" "0"
        write_val "$PVR_PATH2/HTBOperationMode" "2"
        write_val "$PVR_PATH2/TimeCorrClock" "1"
        write_val "$PVR_PATH2/0/DisableFEDLogging" "1"
        write_val "$PVR_PATH2/0/EnableAPM" "0"
    else
        echo "Unknown $PVR_PATH2 path. Skipping optimization."
    fi
}

optimize_adreno_driver() {
    # Additional adreno settings to stabilize the gpu (Matt Yang)（吟惋兮改)
    if [ -d "$ADRENO_PATH" ]; then
        PWRLVL=$(($(cat $ADRENO_PATH/num_pwrlevels) - 1))
        mask_val "$PWRLVL" "$ADRENO_PATH/default_pwrlevel"
        mask_val "$PWRLVL" "$ADRENO_PATH/min_pwrlevel"
        mask_val "0" "$ADRENO_PATH/max_pwrlevel"
        mask_val "1" "$ADRENO_PATH/bus_split"
        mask_val "1" "$ADRENO_PATH/force_clk_on"
        mask_val "1" "$ADRENO_PATH/force_no_nap"
        mask_val "1" "$ADRENO_PATH/force_rail_on"
        mask_val "0" "$ADRENO_PATH/force_bus_on"
        mask_val "0" "$ADRENO_PATH/thermal_pwrlevel"
        mask_val "0" "$ADRENO_PATH/perfcounter"
        mask_val "0" "$ADRENO_PATH/throttling"
        mask_val "0" "$ADRENO_PATH/fsync_enable"
        mask_val "0" "$ADRENO_PATH/vsync_enable"
    else
        echo "Unknown $ADRENO_PATH path. Skipping optimization."
    fi
    
    # Adreno 610 GPU max clock speed set 1114MHz 
    # (thx to vamper865 & yash5643 from module
    # AdrenoRenderEngineTweaks)
    mask_val "1114800000" "$ADRENO_PATH/max_gpuclk"
    mask_val "1114800000" "$ADRENO_PATH/gpuclk"
    mask_val "1114" "$ADRENO_PATH/max_clock_mhz"
    mask_val "1114" "$ADRENO_PATH/gpuclk_mhz"
    
    # Disable AdrenoBoost feature on Adreno GPU
    mask_val "0" "$ADRENO_PATH/devfreq/adrenoboost"
    
    # Disable kgsl profiling
    write_val "$ADRENO_PATH2/enable" "0"
    
    # Disable adreno idler
    write_val "$ADRENO_PATH3/adreno_idler_active" "0"
    
    # Touch boost
    write_val "/sys/module/msm_performance/parameters/touchboost" "1"
}

optimize_mali_driver() {
    # Mali GPU-specific optimizations ( @Bias_khaliq )
    if [ -d "$MALI_PATH" ]; then
         write_val "$MALI_PATH/dvfs_enable" "1"
         write_val "$MALI_PATH/max_clock" "550000"
         write_val "$MALI_PATH/min_clock" "100000"
    else
        echo "Unknown $MALI_PATH path. Skipping optimization."
    fi
    
    # Mali gpu scheduling (thx to @MiAzami) 
    mali_dir=$(ls -d /sys/devices/platform/soc/*mali*/scheduling 2>/dev/null | head -n 1)
    mali1_dir=$(ls -d /sys/devices/platform/soc/*mali* 2>/dev/null | head -n 1)
    if [ -n "$mali_dir" ]; then
        apply_setting "$mali_dir/serialize_jobs" "full"
    fi

    if [ -n "$mali1_dir" ]; then
        apply_setting "$mali1_dir/js_ctx_scheduling_mode" "1"
    fi
}

optimize_task_cgroup_nice() {
    # thx to (Matt Yang)（吟惋兮改)
    change_task_cgroup "surfaceflinger" "" "cpuset"
    change_task_cgroup "system_server" "foreground" "cpuset"
    change_task_cgroup "netd|allocator" "foreground" "cpuset"
    change_task_cgroup "hardware.media.c2|vendor.mediatek.hardware" "background" "cpuset"
    change_task_cgroup "aal_sof|kfps|dsp_send_thread|vdec_ipi_recv|mtk_drm_disp_id|disp_feature|hif_thread|main_thread|rx_thread|ged_" "background" "cpuset"
    change_task_cgroup "pp_event|crtc_" "background" "cpuset"
}

final_optimize_gpu() {
    # Additional kernel-fpsgo GPU optimizations
    if [ -d "$KERNEL_FPSGO_PATH" ]; then
      if [ -f "$KERNEL_FPSGO_PATH/gpu_block_boost" ]; then
          current_val=$(cat "$KERNEL_FPSGO_PATH/gpu_block_boost" 2>/dev/null)
          # Hitung jumlah angka yang ada di dalamnya
          num_fields=$(echo "$current_val" | awk '{print NF}')
        
          if [ "$num_fields" -eq 1 ]; then
              write_val "$KERNEL_FPSGO_PATH/gpu_block_boost" "100"
          elif [ "$num_fields" -eq 3 ]; then
              write_val "$KERNEL_FPSGO_PATH/gpu_block_boost" "60 120 1"
          else
              echo "Unknown gpu_block_boost format: $current_val"
          fi
      else
          echo "gpu_block_boost node not found."
      fi
    else
        echo "Unknown $KERNEL_FPSGO_PATH path. Skipping optimization."
    fi
    
    # disable pvr tracing
    for pvrtracing in $(find /sys/kernel/debug/tracing/events/pvr_fence -name 'enable'); do
        if [ -d "/sys/kernel/debug/tracing/events/pvr_fence" ]; then
            write_val "$pvrtracing" "0"
        fi
    done
        
   # disable gpu tracing for mtk
    write_val "$GPUFREQ_TRACING_PATH/enable" "0"
   
   # Disable auto voltage scaling for mtk
    write_val "$GPU_FREQ_PATH/gpufreq_aging_enable" "0"
    
   # cpuset configuration
    write_val "/dev/cpuset/foreground/cpus" "0-3,4-7"
    write_val "/dev/cpuset/foreground/boost/cpus" "4-7"
    write_val "/dev/cpuset/top-app/cpus" "0-7"
}

cleanup_memory() {
    # Clean up memory and cache
     write_val "/proc/sys/vm/drop_caches" "3"
     write_val "/proc/sys/vm/compact_memory" "1"
}

# ----------------- MAIN EXECUTION -----------------
main() {
    optimize_gpu_temperature
    additional_gpu_settings
    optimize_gpu_frequency
    optimize_pvr_settings
    optimize_adreno_driver
    optimize_mali_driver
    optimize_task_cgroup_nice
    final_optimize_gpu
    cleanup_memory
}

# Main Execution & Exit script successfully
sync && main

############################
# End of Celestial Render
############################

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