#!/system/bin/sh

# As far for this, Zetamin no longer rely on Kazuyoo Celestial Render & Flux
# But Thank you @Kazuyoo & @Koneko_dev

max_rate=$(cmd display dump 2>/dev/null | grep -Eo 'fps=[0-9.]+' | cut -f2 -d= | sort -nr | head -n1 | cut -d . -f 1)

if [ -n "$max_rate" ] && [ "$max_rate" -gt 60 ]; then
    settings put system min_refresh_rate "$max_rate"
    settings put system peak_refresh_rate "$max_rate"
    resetprop ro.surface_flinger.game_default_frame_rate_override "$max_rate"
fi

surface=$(dumpsys SurfaceFlinger)
latency_out=$(dumpsys SurfaceFlinger --latency 2>/dev/null | head -n 5)

FPS=$(dumpsys display | grep -m1 "mDefaultPeak" | awk '{print int($2)}')

if echo "$latency_out" | grep -Eq '^[0-9]+$|^[0-9]{10,}$'; then
    ft=$(echo "$latency_out" | head -n1 | grep -oE '[0-9]+')
else
    ft=$(echo "$surface" | grep -m1 -E "VSYNC period|vsyncPeriod" | awk '{print $7}' | grep -oE '[0-9]+')
fi

app_phase=$(echo "$surface" | grep -m1 "app phase" | awk '{print $3}')
sf_phase=$(echo "$surface" | grep -m1 "SF phase" | awk '{print $3}')

missed=$(echo "$surface" | grep -m1 "Total missed frame count" | awk '{print $5}')

surfaceflinger_autoset() {
  setprop debug.sf.set_idle_timer_ms "$thresh"
  setprop debug.sf.phase_offset_threshold_for_next_vsync_ns $(( (ft/6) + (thresh * 4800) ))
}

surfaceflinger_fallback() {
  setprop debug.sf.set_idle_timer_ms "$thresh"
  setprop debug.sf.phase_offset_threshold_for_next_vsync_ns $(( (ft/6) + (thresh * 4800) ))
}

other() {
  for i in solid_layers image_layers shadow_layers; do
      setprop debug.sf.prime_shader_cache.$i true
  done

   setprop debug.hwui.target_cpu_time_percent $(awk -v b=$(cat /proc/sys/kernel/perf_cpu_time_max_percent 2>/dev/null||echo 25) '{n=$1/b;print int(35+(n*15)/(1+n))}' /proc/loadavg)

   setprop debug.sf.frame_rate_multiple_threshold $(awk -v ft=$ft 'BEGIN{printf "%.6f", (ft/1000000000)*(ft<=10000000?0.85:0.75)}')
}

main_flux() {
  dumpsys SurfaceFlinger --latency-clear
  sleep 1
  if [ -n "$ft" ] && [ "$ft" -gt 0 ]; then
    if [ "$ft" -le 13000000 ]; then
        base_const=70
    else
        base_const=72
    fi

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

    vspan=$(( ft * 51 / 1000 ))
    early=$(( ft * 272 / 1000 ))
    late=$(( ft * 655 / 1000 ))

    thresh=$(( (ft / 1000000) + base_const + 2 ))

    surfaceflinger_fallback
  fi
    set start vsync
    other
}

sync && main_flux

MODDIR=${0%/*}

MALI_PATH="/proc/mali"
ps_ret="$(ps -Ao pid,args)"
GED_PATH2="/sys/kernel/debug/ged/hal"
ADRENO_PATH="/sys/class/kgsl/kgsl-3d0"
GED_PATH="/sys/module/ged/parameters"
PVR_PATH2="/sys/kernel/debug/pvr/apphint"
PVR_PATH="/sys/module/pvrsrvkm/parameters"
PLATFORM_GPU_PATH="/sys/devices/platform/gpu"
ADRENO_PATH3="/sys/module/adreno_idler/parameters"
KERNEL_FPSGO_PATH="/sys/kernel/debug/fpsgo/common"
ADRENO_PATH2="/sys/kernel/debug/kgsl/kgsl-3d0/profiling"
GPUF_PATH="/proc/gpufreq"
GPUF_PATH2="/proc/gpufreqv2"
GPU_FREQ_PATH="/proc/gpufreq"
GPUFREQ_TRACING_PATH="/sys/kernel/debug/tracing/events/mtk_events"
FPS=$(dumpsys display | grep -m1 "mDefaultPeak" | awk '{print int($2)}')

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
        echo "$value" > "$file"
    fi
}

change_task_cgroup() {
    local comm
    for temp_pid in $(echo "$ps_ret" | grep -i -E "$1" | grep -v "PID" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            comm="$(cat /proc/$temp_pid/task/$temp_tid/comm)"
            echo "$temp_tid" >"/dev/$3/$2/tasks"
        done
    done
}

change_task_nice() {
    for temp_pid in $(echo "$ps_ret" | grep -i -E "$1" | grep -v "PID" | awk '{print $1}'); do
        for temp_tid in $(ls "/proc/$temp_pid/task/"); do
            renice -n +40 -p "$temp_tid"
            renice -n -19 -p "$temp_tid"
            renice -n "$2" -p "$temp_tid"
        done
    done
}

additional_gpu_settings() {
    if [ -d "$GED_PATH" ]; then
        write_val "$GED_PATH/ged_smart_boost" "1000"
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
    fi

    if [ -d "$GED_PATH2" ]; then
         write_val "$GED_PATH2/gpu_boost_level" "2"
         write_val "$GED_PATH2/custom_upbound_gpu_freq" "1"
    fi

    if [ -d "$PLATFORM_GPU_PATH" ]; then
         write_val "$PLATFORM_GPU_PATH/dvfs_enable" "1"
         write_val "$PLATFORM_GPU_PATH/gpu_busy" "1"
    fi
}

optimize_gpu_frequency() {
    if [ -d "$GPUF_PATH" ]; then
        write_val "$GPUF_PATH/limit_table" "1 1 1"
        write_val "$GPUF_PATH/gpufreq_limited_thermal_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_limited_oc_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_limited_low_batt_volume_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_limited_low_batt_volt_ignore" "1"
        write_val "$GPUF_PATH/gpufreq_fixed_freq_volt" "0"
        write_val "$GPUF_PATH/gpufreq_opp_stress_test" "0"
        write_val "$GPUF_PATH/gpufreq_power_dump" "0"
        write_val "$GPUF_PATH/gpufreq_power_limited" "0"
    fi

    if [ -d "$GPUF_PATH2" ]; then
        write_val "$GPUF_PATH2/aging_mode" "disable"
    fi
}

optimize_pvr_settings() {
    if [ -d "$PVR_PATH" ]; then
        write_val "$PVR_PATH/gpu_power" "2"
        write_val "$PVR_PATH/HTBufferSizeInKB" "512"
        write_val "$PVR_PATH/DisableClockGating" "1"
        write_val "$PVR_PATH/EmuMaxFreq" "2"
        write_val "$PVR_PATH/EnableFWContextSwitch" "1"
        write_val "$PVR_PATH/gPVRDebugLevel" "0"
        write_val "$PVR_PATH/gpu_dvfs_enable" "1"
    fi

    if [ -d "$PVR_PATH2" ]; then
        write_val "$PVR_PATH2/CacheOpConfig" "1"
        write_val "$PVR_PATH2/CacheOpUMKMThresholdSize" "512"
        write_val "$PVR_PATH2/EnableFTraceGPU" "0"
        write_val "$PVR_PATH2/HTBOperationMode" "2"
        write_val "$PVR_PATH2/TimeCorrClock" "1"
        write_val "$PVR_PATH2/0/DisableFEDLogging" "1"
        write_val "$PVR_PATH2/0/EnableAPM" "0"
    fi
}

optimize_adreno_driver() {
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
    fi

    mask_val "0" "$ADRENO_PATH/devfreq/adrenoboost"

    write_val "$ADRENO_PATH2/enable" "0"

    write_val "$ADRENO_PATH3/adreno_idler_active" "0"

    write_val "/sys/module/msm_performance/parameters/touchboost" "1"
}

optimize_mali_driver() {
    if [ -d "$MALI_PATH" ]; then
         write_val "$MALI_PATH/dvfs_enable" "1"
    fi

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
    change_task_cgroup "surfaceflinger" "" "cpuset"
    change_task_cgroup "system_server" "foreground" "cpuset"
    change_task_cgroup "netd|allocator" "foreground" "cpuset"
    change_task_cgroup "hardware.media.c2|vendor.mediatek.hardware" "background" "cpuset"
    change_task_cgroup "aal_sof|kfps|dsp_send_thread|vdec_ipi_recv|mtk_drm_disp_id|disp_feature|hif_thread|main_thread|rx_thread|ged_" "background" "cpuset"
    change_task_cgroup "pp_event|crtc_" "background" "cpuset"
}

final_optimize_gpu() {
    if [ -d "$KERNEL_FPSGO_PATH" ]; then
      if [ -f "$KERNEL_FPSGO_PATH/gpu_block_boost" ]; then
          current_val=$(cat "$KERNEL_FPSGO_PATH/gpu_block_boost" 2>/dev/null)
          num_fields=$(echo "$current_val" | awk '{print NF}')

          if [ "$num_fields" -eq 1 ]; then
              write_val "$KERNEL_FPSGO_PATH/gpu_block_boost" "100"
          elif [ "$num_fields" -eq 3 ]; then
              write_val "$KERNEL_FPSGO_PATH/gpu_block_boost" "60 120 1"
          fi
      fi
    fi

    for pvrtracing in $(find /sys/kernel/debug/tracing/events/pvr_fence -name 'enable'); do
        if [ -d "/sys/kernel/debug/tracing/events/pvr_fence" ]; then
            write_val "$pvrtracing" "0"
        fi
    done

    write_val "$GPUFREQ_TRACING_PATH/enable" "0"

    write_val "$GPU_FREQ_PATH/gpufreq_aging_enable" "0"

    write_val "/dev/cpuset/foreground/cpus" "0-3,4-7"
    write_val "/dev/cpuset/foreground/boost/cpus" "4-7"
    write_val "/dev/cpuset/top-app/cpus" "0-7"
}

main_render() {
    additional_gpu_settings
    optimize_gpu_frequency
    optimize_pvr_settings
    optimize_adreno_driver
    optimize_mali_driver
    optimize_task_cgroup_nice
    final_optimize_gpu
}

sync && main_render

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

sync && facur_main

exit 0