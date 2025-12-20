###################################
# Celestial Flinger Flux (@Kzuyoo)
# Version: 1.9
# Note: Notification Disabled | No Animation Tweak
###################################
#!/system/bin/sh
#
# Celestial-Flinger-Flux by the kazuyoo
# Open-source powered — with appreciation to GL-DP and all contributors.
# Licensed under the MIT License.

# ----------------- HELPER FUNCTIONS -----------------
# --- Retrieve SurfaceFlinger & display data ---
  surface=$(dumpsys SurfaceFlinger)
  latency_out=$(dumpsys SurfaceFlinger --latency 2>/dev/null | head -n 5)

# Get FPS from display service
  FPS=$(dumpsys display | grep -m1 "mDefaultPeak" | awk '{print int($2)}')

# Take frame time from VSYNC & latency
  if echo "$latency_out" | grep -Eq '^[0-9]+$|^[0-9]{10,}$'; then
      ft=$(echo "$latency_out" | head -n1 | grep -oE '[0-9]+')
  else
      ft=$(echo "$surface" | grep -m1 -E "VSYNC period|vsyncPeriod" | awk '{print $7}' | grep -oE '[0-9]+')
  fi

# Take phase
  app_phase=$(echo "$surface" | grep -m1 "app phase" | awk '{print $3}')
  sf_phase=$(echo "$surface" | grep -m1 "SF phase" | awk '{print $3}')

# Take the total missed frame count
  missed=$(echo "$surface" | grep -m1 "Total missed frame count" | awk '{print $5}')
  
# ----------------- OPTIMIZATION SECTIONS -----------------
surfaceflinger_autoset() {
# Set SurfaceFlinger props
  setprop debug.sf.hwc.min.duration "$vspan"
  setprop debug.sf.early.app.duration "$early"
  setprop debug.sf.late.app.duration "$late"
  setprop debug.sf.early.sf.duration "$early"
  setprop debug.sf.late.sf.duration "$late"
  setprop debug.sf.earlyGl.sf.duration "$early"
  setprop debug.sf.earlyGl.app.duration "$early"

  setprop debug.sf.set_idle_timer_ms "$thresh"
  setprop debug.sf.phase_offset_threshold_for_next_vsync_ns $(( (ft/6) + (thresh * 4800) ))

# --- High FPS (60+) ---
  if [ "$FPS" -gt 60 ]; then
    setprop debug.sf.early_phase_offset_ns "$early"
    setprop debug.sf.early_gl_phase_offset_ns "$early"
    setprop debug.sf.early_app_phase_offset_ns "$early"
    setprop debug.sf.early_gl_app_phase_offset_ns "$early"

    setprop debug.sf.high_fps_late_app_phase_offset_ns "$late"
    setprop debug.sf.high_fps_late_sf_phase_offset_ns "$late"
    setprop debug.sf.high_fps_early_phase_offset_ns "$early"
    setprop debug.sf.high_fps_early_gl_phase_offset_ns "$early"
    setprop debug.sf.high_fps_early_app_phase_offset_ns "$early"
    setprop debug.sf.high_fps_early_gl_app_phase_offset_ns "$early"
  fi
}

surfaceflinger_fallback() {
# Fallback Using Fixed SurfaceFlinger Settings
  setprop debug.sf.hwc.min.duration "$vspan"
  setprop debug.sf.early.app.duration "$early"
  setprop debug.sf.late.app.duration "$late"
  setprop debug.sf.early.sf.duration "$early"
  setprop debug.sf.late.sf.duration "$late"
  setprop debug.sf.earlyGl.sf.duration "$early"
  setprop debug.sf.earlyGl.app.duration "$early"
  setprop debug.sf.set_idle_timer_ms "$thresh"
  setprop debug.sf.phase_offset_threshold_for_next_vsync_ns $(( (ft/6) + (thresh * 4800) ))
}

other() {
# SurfaceFlinger Prime Shader Minimal Optimize
  for i in solid_layers image_layers shadow_layers; do
      setprop debug.sf.prime_shader_cache.$i true
  done
    
# Percentage of frame time that's used for CPU work.
   setprop debug.hwui.target_cpu_time_percent $(awk -v b=$(cat /proc/sys/kernel/perf_cpu_time_max_percent 2>/dev/null||echo 25) '{n=$1/b;print int(35+(n*15)/(1+n))}' /proc/loadavg)
   
# Application FPS synchronization tolerance with screen refresh rate.
   setprop debug.sf.frame_rate_multiple_threshold $(awk -v ft=$ft 'BEGIN{printf "%.6f", (ft/1000000000)*(ft<=10000000?0.85:0.75)}')
}
  
# ----------------- MAIN EXECUTION -----------------
main_flux() {
  dumpsys SurfaceFlinger --latency-clear
  sleep 1
  # --- Adaptive calculation Extended ---
  if [ -n "$ft" ] && [ "$ft" -gt 0 ]; then
    # Base constant
    if [ "$ft" -le 13000000 ]; then
        base_const=70   # 90–144Hz
    else
        base_const=72   # 60Hz
    fi

    # Core timing
    if [ "$ft" -le 13000000 ]; then
        vspan=$(( ft * 48 / 1000 ))
        early=$(( ft * 261 / 1000 ))
        late=$(( ft * 610 / 1000 ))
        thresh=$(( (ft / 1000000) + base_const + 1 ))
    else
        vspan=$(( ft * 50 / 1000 ))
        early=$(( ft * 270 / 1000 ))
        late=$(( ft * 652 / 1000 ))
        thresh=$(( (ft / 1000000) + base_const + 2 ))
    fi

    surfaceflinger_autoset
  else
    ft=16666667
    base_const=72

    # Core fallback
    vspan=$(( ft * 51 / 1000 ))
    early=$(( ft * 272 / 1000 ))
    late=$(( ft * 655 / 1000 ))

    # Fallback threshold
    thresh=$(( (ft / 1000000) + base_const + 2 ))

    surfaceflinger_fallback
  fi
    set start vsync 
    other
}

# Main Execution & Exit script successfully
 sync && main_flux

#####################################
# End of Celestial Flinger Flux
#####################################

###################################
# Celestial Render FlowX (@Kzuyoo)
# Version: 1.6G
# Note: Notification Disabled, Wait boot complete removed
# Purpose of this is the Render (GPU, etc)
###################################

# Do NOT assume where your module will be located.
# ALWAYS use $MODDIR if you need to know where this script
# and module is placed.
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
            write_val "$i 0 0" /proc/gpufreqv2/limit_table
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
main_render() {
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
sync && main_render

############################
# End of Celestial Render
############################

############################
# Facur.sh (Surface Flinger Tweaks)
# By: @Koneko_dev
# This supposed to be a better one + additional with the Celestial Render Flux
############################

facur_main() {
    local MAX_FPS
    local VSYNC_NS
    local VAL_E
    local VAL_F
    local VAL_G
    local VAL_H

    MAX_FPS=$(dumpsys display 2>/dev/null | grep -Eo 'fps=[0-9]+' | cut -d= -f2 | sort -nr | head -n1)
    [ -z "$MAX_FPS" ] && MAX_FPS=60
    VSYNC_NS=$((1000000000 / MAX_FPS))
    VAL_E=$(( (VSYNC_NS * 80) / 100 ))
    VAL_F=$(( (VSYNC_NS * 60) / 100 ))
    VAL_G=$(( -VAL_E ))
    VAL_H=$(( -VAL_F ))

    echo "Detected FPS: $MAX_FPS | VSync: ${VSYNC_NS}ns"
    echo "Durations (E=$VAL_E, F=$VAL_F, G=$VAL_G, H=$VAL_H)"

    for prop in \
        debug.sf.early.app.duration debug.sf.earlyGl.app.duration \
        debug.sf.high_fps.early.app.duration debug.sf.high_fps.earlyGl.app.duration \
        debug.sf.high_fps.late.app.duration debug.sf.late.app.duration; do
        setprop "$prop" "$VAL_E"
    done

    for prop in \
        debug.sf.early.sf.duration debug.sf.earlyGl.sf.duration \
        debug.sf.high_fps.early.sf.duration debug.sf.high_fps.earlyGl.sf.duration \
        debug.sf.high_fps.late.sf.duration debug.sf.late.sf.duration; do
        setprop "$prop" "$VAL_F"
    done

    for prop in \
        debug.sf.earlyGl_app_phase_offset_ns debug.sf.early_app_phase_offset_ns \
        debug.sf.high_fps_earlyGl_app_phase_offset_ns debug.sf.high_fps_early_app_phase_offset_ns \
        debug.sf.high_fps_late_app_phase_offset_ns debug.sf.late_app_phase_offset_ns; do
        setprop "$prop" "$VAL_G"
    done

    for prop in \
        debug.sf.earlyGl_phase_offset_ns debug.sf.early_phase_offset_ns \
        debug.sf.high_fps_earlyGl_phase_offset_ns debug.sf.high_fps_early_phase_offset_ns \
        debug.sf.high_fps_late_phase_offset_ns debug.sf.late_phase_offset_ns; do
        setprop "$prop" "$VAL_H"
    done
}

# Execute Facur Logic
sync && facur_main

############################
# End of Facur.sh
############################