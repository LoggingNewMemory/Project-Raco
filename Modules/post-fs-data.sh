###################################
# Celestial Flinger Flux (@Kzuyoo)
# Version: 1.8 Essential
###################################

MODDIR=${0%/*}

# --- SurfaceFlinger Optimized Props ---
resetprop -n ro.sf.disable_triple_buffer "0"
resetprop -n ro.surface_flinger.running_without_sync_framework "true"
resetprop -n ro.surface_flinger.start_graphics_allocator_service "false"
resetprop -n ro.surface_flinger.use_content_detection_for_refresh_rate "false"
resetprop -n ro.surface_flinger.support_kernel_idle_timer "true"
resetprop -n ro.surface_flinger.use_context_priority "true"
resetprop -n ro.surface_flinger.max_frame_buffer_acquired_buffers "3"

# --- Touch Timer ---
resetprop -n ro.surface_flinger.set_touch_timer_ms "180"

# --- Recording / Casting Optimization ---
resetprop -n ro.surface_flinger.force_hwc_copy_for_virtual_displays "true"

#####################################
# End of Celestial Flinger Flux
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
# dark gpu rendering by Dreamy Wanderer
MODDIR=${0%/*}
dir=$MODDIR

# @Bias_khaliq
# Function to detect GPU type 
detect_gpu_type() {
    if [ -d "/sys/class/kgsl/kgsl-3d0" ]; then
        echo "adreno"
    elif [ -n "$(find /sys/devices/platform -name mali -type d)" ]; then
        echo "mali"
    elif [ -n "$(find /sys/ -name pvr* -type d)" ]; then
        echo "PowerVR"
    else
        echo "none"
    fi
}

gpu_optimize_adreno() {
    mkdir -p "$dir/system/lib/egl" "$dir/system/lib64/egl" "$dir/system/vendor/lib/egl" "$dir/system/vendor/lib64/egl"
    # Function to get GPU model
    get_gpu_model() {
        if [ -d "/sys/class/kgsl/kgsl-3d0" ]; then
            model=$(cat "/sys/class/kgsl/kgsl-3d0/gpu_model")
            echo "$model"
        fi
    }
    # Get GPU vendor and model
    gpu_model=$(get_gpu_model)
    # Write GPU info to egl.cfg files
    write_gpu_info() {
        egl_cfg_path=$1
        gpu_model=$2
        echo "0 1 $gpu_model" > "$egl_cfg_path"
    }
    write_gpu_info "$dir/system/lib/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/lib64/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/vendor/lib/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/vendor/lib64/egl/egl.cfg" "$gpu_model"
}

gpu_optimize_mali() {
    gpu_path=$(find /sys/devices/platform/*mali*/gpuinfo -type f -print | head -n 1)
    if [ ! -d "$dir/system" ] && [ -n "$gpu_path" ]; then
        mkdir -p "$dir/system/lib/egl" "$dir/system/lib64/egl" "$dir/system/vendor/lib/egl" "$dir/system/vendor/lib64/egl" &&
        gpu_id=$(awk '{print $1}' "$gpu_path")
        echo "0 1 $gpu_id" > "$dir/system/lib/egl/egl.cfg"
        echo "0 1 $gpu_id" > "$dir/system/lib64/egl/egl.cfg"
        echo "0 1 $gpu_id" > "$dir/system/vendor/lib/egl/egl.cfg"
        echo "0 1 $gpu_id" > "$dir/system/vendor/lib64/egl/egl.cfg"
    fi
}

gpu_optimize_powervr() {
    mkdir -p "$dir/system/lib/egl" "$dir/system/lib64/egl" "$dir/system/vendor/lib/egl" "$dir/system/vendor/lib64/egl"

# Get GPU vendor and model
    gpu_model=pvr

# Write GPU info to egl.cfg files
  write_gpu_info() {
    egl_cfg_path=$1
    gpu_model=$2
    echo "0 1 $gpu_model" > "$egl_cfg_path"
  }

    write_gpu_info "$dir/system/lib/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/lib64/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/vendor/lib/egl/egl.cfg" "$gpu_model"
    write_gpu_info "$dir/system/vendor/lib64/egl/egl.cfg" "$gpu_model"
}

# Detect GPU type
gpu_type=$(detect_gpu_type)

# Execute appropriate function based on GPU type 
case $gpu_type in
    "adreno")
        echo "adreno"
        gpu_optimize_adreno
        ;;
    "mali")
        echo "mali"
        gpu_optimize_mali
        ;;
    "pvr")
        echo "powervr"
        gpu_optimize_powervr
        ;;
    *)
        echo "Unknown or unsupported GPU type. Skipping optimization."
        ;;
esac

# This script will be executed in post-fs-data mode

############################
# End of Celestial Render
############################