#!/system/bin/sh
###############################
# DEFINE CONFIG
###############################

# Config file path
RACO_CONFIG="/data/ProjectRaco/raco.txt"

# Helper to read config (avoid invoking grep/cut repeatedly)
read_config() {
    sed -n "s/^$1=//p" "$RACO_CONFIG"
}

SOC=$(read_config SOC)
LITE_MODE=$(read_config LITE_MODE)
BETTER_POWERAVE=$(read_config BETTER_POWERAVE)
ANYA=$(read_config ANYA)
INCLUDE_ANYA=$(read_config INCLUDE_ANYA)
KCPU_MITIGATE=$(read_config KCPU_MITIGATE)
LEGACY_NOTIF=$(read_config LEGACY_NOTIF)
SILENT_NOTIF=$(read_config SILENT_NOTIF)
DEVICE_MITIGATION=$(read_config DEVICE_MITIGATION)
DND=$(read_config DND)
BYPASS_ENABLE=$(read_config ENABLE_BYPASS | tr -d ' ')

DEFAULT_CPU_GOV=$(read_config GOV)
if [ -z "$DEFAULT_CPU_GOV" ]; then
    if [ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ] && grep -q "schedhorizon" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
        DEFAULT_CPU_GOV="schedhorizon"
    else
        DEFAULT_CPU_GOV="schedutil"
    fi
fi

##############################
# Path Variable
##############################
ipv4="/proc/sys/net/ipv4"

##############################
# ADDED: Source External Script
##############################
SCRIPT_PATH="/data/adb/modules/ProjectRaco/Scripts"
MODULE_PATH="/data/adb/modules/ProjectRaco"

# Source with check
[ -f "$MODULE_PATH/Scripts/corin.sh" ] && source "$MODULE_PATH/Scripts/corin.sh"

if [ "$KCPU_MITIGATE" -eq 0 ] && [ -f "$SCRIPT_PATH/CarlottaCPU.sh" ]; then
    source "$SCRIPT_PATH/CarlottaCPU.sh"
fi

##############################
# Begin Functions
##############################

set_state() {
    local new_state=$1
    if [ -f "$RACO_CONFIG" ]; then
        sed -i "s/^STATE=.*/STATE=$new_state/" "$RACO_CONFIG"
    fi
}

anyamelfissa() {
    if [ "$INCLUDE_ANYA" = "1" ] && [ "$ANYA" = "1" ] && [ -f "$SCRIPT_PATH/AnyaMelfissa.sh" ]; then
        sh "$SCRIPT_PATH/AnyaMelfissa.sh" &
    fi
}

anyakawaii() {
    if [ "$INCLUDE_ANYA" = "1" ] && [ "$ANYA" = "1" ] && [ -f "$SCRIPT_PATH/AnyaKawaii.sh" ]; then
        sh "$SCRIPT_PATH/AnyaKawaii.sh" &
    fi
}

tweak() {
    # Optimized tweak function: checks existence and writability
    if [ -f "$2" ] || [ -d "$2" ]; then
        if [ ! -w "$2" ]; then
             chmod 644 "$2" >/dev/null 2>&1
        fi
        echo "$1" > "$2" 2>/dev/null
        chmod 444 "$2" >/dev/null 2>&1
    fi
}

kakangkuh() {
    # Read-write tweak (leaves permission 644/writable)
    if [ -f "$2" ]; then
        chmod 644 "$2" >/dev/null 2>&1
        echo "$1" >"$2" 2>/dev/null
    fi
}

kill_all() {
    sync
    cmd activity kill-all > /dev/null 2>&1
    # Optimized package loop
    pm list packages -3 | cut -f 2 -d ":" | while read pkg; do
        if [ "$pkg" != "com.google.android.inputmethod.latin" ]; then 
            am force-stop "$pkg" > /dev/null 2>&1 &
        fi
    done
    wait

    pm trim-caches 100G > /dev/null 2>&1
    echo 3 > /proc/sys/vm/drop_caches
    logcat -c
    logcat -b all -c
    [ "$(type -t star_kill)" = "function" ] && star_kill &
}

bypass_on() {
    if [ "$BYPASS_ENABLE" = "1" ]; then
        sh "$SCRIPT_PATH/raco_bypass_controller.sh" enable &
    fi
}

bypass_off() {
    sh "$SCRIPT_PATH/raco_bypass_controller.sh" disable &
}

notification() {
    if [ "$SILENT_NOTIF" = "1" ]; then
        local TITLE="Project Raco"
        local MESSAGE="$1"
        local LOGO="/data/local/tmp/logo.png"
        
        if [ "$LEGACY_NOTIF" = "1" ]; then
            su -lp 2000 -c "cmd notification post -S bigtext -t '$TITLE' TagRaco '$MESSAGE'" &
        else
            su -lp 2000 -c "cmd notification post -S bigtext -t '$TITLE' -i file://$LOGO -I file://$LOGO TagRaco '$MESSAGE'" &
        fi
    fi
}

dnd_off() {
    if [ "$DND" = "1" ]; then
        cmd notification set_dnd off &
    fi
}

dnd_on() {
    if [ "$DND" = "1" ]; then
        cmd notification set_dnd priority &
    fi
}

clear_slingshot() {
    settings delete global angle_debug_package
    settings delete global angle_gl_driver_all_angle
    settings delete global angle_gl_driver_selection_pkgs
    settings delete global angle_gl_driver_selection_values
    setprop debug.hwui.renderer none
}

############################
# Yanz AIO Gaming 4.1 Integration
############################

yanz_mtk_boost() {
    tweak "1" "/sys/pnpmgr/mwn"
    tweak "1" "/sys/pnpmgr/boost_enable"
    tweak "turbo" "/sys/pnpmgr/boost_mode"
    
    tweak "1" "/sys/module/ged/parameters/gx_boost_on"
    tweak "1" "/sys/module/ged/parameters/gx_game_mode"
    tweak "1" "/sys/module/ged/parameters/ged_smart_boost"
    tweak "1" "/sys/module/ged/parameters/enable_gpu_boost"
    tweak "1" "/sys/module/ged/parameters/ged_boost_enable"
    tweak "100" "/sys/kernel/ged/hal/gpu_boost_level"
    tweak "0" "/sys/module/ged/parameters/is_GED_KPI_enabled"
    tweak "1" "/sys/module/ged/parameters/gx_frc_mode"
    tweak "1" "/sys/module/ged/parameters/cpu_boost_policy"
    tweak "1" "/sys/module/ged/parameters/boost_extra"
}

yanz_mtk_balance() {
    tweak "0" "/sys/pnpmgr/mwn"
    tweak "0" "/sys/pnpmgr/boost_enable"
    tweak "0" "/sys/pnpmgr/boost_mode"
    
    tweak "0" "/sys/module/ged/parameters/gx_boost_on"
    tweak "0" "/sys/module/ged/parameters/gx_game_mode"
    tweak "0" "/sys/module/ged/parameters/ged_smart_boost"
    tweak "0" "/sys/module/ged/parameters/enable_gpu_boost"
    tweak "0" "/sys/module/ged/parameters/ged_boost_enable"
    tweak "-1" "/sys/kernel/ged/hal/gpu_boost_level"
    tweak "1" "/sys/module/ged/parameters/is_GED_KPI_enabled"
    tweak "0" "/sys/module/ged/parameters/gx_frc_mode"
    tweak "0" "/sys/module/ged/parameters/cpu_boost_policy"
    tweak "0" "/sys/module/ged/parameters/boost_extra"
}

yanz_mtk_powersave() {
    yanz_mtk_balance
}

yanz_snapdragon_boost() {
    tweak "3" "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost"
    tweak "Y" "/sys/module/adreno_idler/parameters/adreno_idler_active"
    tweak "0" "/sys/class/kgsl/kgsl-3d0/throttling"
    tweak "1" "/sys/class/kgsl/kgsl-3d0/default_pwrlevel"
    
    tweak "1" "/sys/module/msm_perfmon/parameters/touch_boost_enable"
    tweak "1" "/sys/module/msm_perfmon/parameters/touch_boost_freq"
    tweak "1" "/sys/module/msm_performance/parameters/touchboost"
    tweak "1" "/sys/power/pnpmgr/touch_boost"
    
    tweak "1" "/sys/devices/system/cpu/cpu0/core_ctl/enable"
    tweak "1" "/sys/devices/system/cpu/cpu4/core_ctl/enable"
}

yanz_snapdragon_balance() {
    tweak "0" "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost"
    tweak "1" "/sys/class/kgsl/kgsl-3d0/throttling"
    tweak "0" "/sys/module/msm_perfmon/parameters/touch_boost_enable"
    tweak "0" "/sys/module/msm_perfmon/parameters/touch_boost_freq"
    tweak "0" "/sys/module/msm_performance/parameters/touchboost"
    tweak "0" "/sys/power/pnpmgr/touch_boost"
}

yanz_snapdragon_powersave() {
    yanz_snapdragon_balance
    tweak "Y" "/sys/module/adreno_idler/parameters/adreno_idler_active"
}

###################################
# MTKVest Functions 
###################################

mtkvest_perf() {
    if [ -d /sys/kernel/ged/hal ]; then
        tweak 2 /sys/kernel/ged/hal/loading_base_dvfs_step
        tweak 1 /sys/kernel/ged/hal/loading_stride_size
        tweak 16 /sys/kernel/ged/hal/loading_window_size
    fi
}

mtkvest_normal() {
    if [ -d /sys/kernel/ged/hal ]; then
        tweak 4 /sys/kernel/ged/hal/loading_base_dvfs_step
        tweak 2 /sys/kernel/ged/hal/loading_stride_size
        tweak 8 /sys/kernel/ged/hal/loading_window_size
    fi
}

###################################
# Frequency fetching & setting
###################################

which_maxfreq() {
    tr ' ' '\n' <"$1" | sort -nr | head -n 1
}

which_minfreq() {
    tr ' ' '\n' <"$1" | grep -v '^[[:space:]]*$' | sort -n | head -n 1
}

which_midfreq() {
    total_opp=$(wc -w <"$1")
    mid_opp=$(((total_opp + 1) / 2))
    tr ' ' '\n' <"$1" | grep -v '^[[:space:]]*$' | sort -nr | head -n $mid_opp | tail -n 1
}

# Unified devfreq handler
set_devfreq() {
    local path="$1"
    local mode="$2" # max, mid, min, unlock
    [ ! -f "$path/available_frequencies" ] && return 1

    local max_avail=$(which_maxfreq "$path/available_frequencies")
    local min_avail=$(which_minfreq "$path/available_frequencies")
    local mid_avail=$(which_midfreq "$path/available_frequencies")

    case $mode in
        max)
            tweak "$max_avail" "$path/min_freq"
            tweak "$max_avail" "$path/max_freq"
            ;;
        mid)
            tweak "$max_avail" "$path/max_freq"
            tweak "$mid_avail" "$path/min_freq"
            ;;
        min)
            tweak "$min_avail" "$path/min_freq"
            tweak "$min_avail" "$path/max_freq"
            ;;
        unlock)
            kakangkuh "$min_avail" "$path/min_freq"
            kakangkuh "$max_avail" "$path/max_freq"
            ;;
    esac
}

devfreq_max_perf() { set_devfreq "$1" "max"; }
devfreq_mid_perf() { set_devfreq "$1" "mid"; }
devfreq_min_perf() { set_devfreq "$1" "min"; }
devfreq_unlock() { set_devfreq "$1" "unlock"; }

qcom_cpudcvs_max_perf() {
    [ ! -f "$1/available_frequencies" ] && return 1
    freq=$(which_maxfreq "$1/available_frequencies")
    tweak "$freq" "$1/hw_max_freq"
    tweak "$freq" "$1/hw_min_freq"
}

qcom_cpudcvs_mid_perf() {
    [ ! -f "$1/available_frequencies" ] && return 1
    max_freq=$(which_maxfreq "$1/available_frequencies")
    mid_freq=$(which_midfreq "$1/available_frequencies")
    tweak "$max_freq" "$1/hw_max_freq"
    tweak "$mid_freq" "$1/hw_min_freq"
}

qcom_cpudcvs_unlock() {
    [ ! -f "$1/available_frequencies" ] && return 1
    max_freq=$(which_maxfreq "$1/available_frequencies")
    min_freq=$(which_minfreq "$1/available_frequencies")
    kakangkuh "$max_freq" "$1/hw_max_freq"
    kakangkuh "$min_freq" "$1/hw_min_freq"
}

change_cpu_gov() {
    local gov="$1"
    for policy in /sys/devices/system/cpu/cpufreq/policy*; do
        local gov_file="$policy/scaling_governor"
        # Force permission change to 644 to ensure we can write
        if [ -f "$gov_file" ]; then
             chmod 644 "$gov_file" >/dev/null 2>&1
             echo "$gov" > "$gov_file" 2>/dev/null
             chmod 444 "$gov_file" >/dev/null 2>&1
        fi
    done
}

###################################
# CPUFreq Frequency Tweaks
###################################

# Essential: Reset limits to hardware bounds to prevent "write error: Invalid Argument"
cpufreq_reset_limits() {
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        if [ -d "$path" ]; then
            chmod 644 "$path/scaling_max_freq" "$path/scaling_min_freq" 2>/dev/null
            local hw_min=$(cat "$path/cpuinfo_min_freq")
            local hw_max=$(cat "$path/cpuinfo_max_freq")
            
            # Widen the window: Set min to lowest, max to highest
            echo "$hw_min" > "$path/scaling_min_freq" 2>/dev/null
            echo "$hw_max" > "$path/scaling_max_freq" 2>/dev/null
        fi
    done
}

cpufreq_max_perf() {
    # 1. Reset limits first
    cpufreq_reset_limits
    
    # 2. Apply Max Perf
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        if [ -d "$path" ]; then
            local hw_max=$(cat "$path/cpuinfo_max_freq")
            local mid_freq=$(which_midfreq "$path/scaling_available_frequencies")

            if [ "$LITE_MODE" -ne 1 ]; then
                 echo "$hw_max" > "$path/scaling_min_freq" 2>/dev/null
            else
                 # Lite mode: allow scaling down to mid, but cap at max
                 echo "$mid_freq" > "$path/scaling_min_freq" 2>/dev/null
            fi
            echo "$hw_max" > "$path/scaling_max_freq" 2>/dev/null
            
            chmod 444 "$path/scaling_max_freq" "$path/scaling_min_freq" 2>/dev/null
        fi
    done
}

cpufreq_unlock() {
    # Unlocking is just resetting limits and leaving them writable
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        if [ -d "$path" ]; then
            chmod 644 "$path/scaling_max_freq" "$path/scaling_min_freq" 2>/dev/null
            local hw_min=$(cat "$path/cpuinfo_min_freq")
            local hw_max=$(cat "$path/cpuinfo_max_freq")
            
            echo "$hw_min" > "$path/scaling_min_freq" 2>/dev/null
            echo "$hw_max" > "$path/scaling_max_freq" 2>/dev/null
        fi
    done
}

cpufreq_min_perf() {
    # 1. Reset limits first
    cpufreq_reset_limits

    # 2. Apply Min Perf
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        if [ -d "$path" ]; then
            local hw_min=$(cat "$path/cpuinfo_min_freq")
            local mid_freq=$(which_midfreq "$path/scaling_available_frequencies")
            
            echo "$hw_min" > "$path/scaling_min_freq" 2>/dev/null
            
            if [ "$BETTER_POWERAVE" -eq 1 ]; then
                echo "$mid_freq" > "$path/scaling_max_freq" 2>/dev/null
            else
                echo "$hw_min" > "$path/scaling_max_freq" 2>/dev/null
            fi
            
            chmod 444 "$path/scaling_max_freq" "$path/scaling_min_freq" 2>/dev/null
        fi
    done
}

# PPM Handling
cpufreq_ppm_max_perf() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local cpu_maxfreq=$(<"$path/cpuinfo_max_freq")
        tweak "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq

        if [ "$LITE_MODE" -eq 1 ]; then
            local cpu_midfreq=$(which_midfreq "$path/scaling_available_frequencies")
            tweak "$cluster $cpu_midfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        else
            tweak "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        fi
        ((cluster++))
    done
}

cpufreq_ppm_unlock() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local cpu_maxfreq=$(<"$path/cpuinfo_max_freq")
        local cpu_minfreq=$(<"$path/cpuinfo_min_freq")
        
        kakangkuh "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        kakangkuh "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        ((cluster++))
    done
}

cpufreq_ppm_min_perf() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local cpu_minfreq=$(<"$path/cpuinfo_min_freq")
        if [ "$BETTER_POWERAVE" -eq 1 ]; then
            local cpu_midfreq=$(which_midfreq "$path/scaling_available_frequencies")
            tweak "$cluster $cpu_midfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
            tweak "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        else
            tweak "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
            tweak "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        fi
        ((cluster++))
    done
}

###################################
# Device Profiles
###################################

mediatek_performance() {
    tweak 1 /proc/cpufreq/cpufreq_cci_mode
    tweak 3 /proc/cpufreq/cpufreq_power_mode
    tweak 1 /sys/devices/platform/boot_dramboost/dramboost/dramboost
    tweak 0 /sys/devices/system/cpu/eas/enable
    tweak 0 /sys/kernel/eara_thermal/enable

    mtkvest_perf
    yanz_mtk_boost

    tweak "stop 1" /proc/mtk_batoc_throttling/battery_oc_protect_stop

    if [ "$LITE_MODE" -eq 0 ]; then
        tweak 0 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
        tweak 0 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
        devfreq_max_perf /sys/class/devfreq/mtk-dvfsrc-devfreq
    else
        tweak -1 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
        tweak -1 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
        devfreq_mid_perf /sys/class/devfreq/mtk-dvfsrc-devfreq
    fi
}

snapdragon_performance() {
    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*cpu*-lat \
            /sys/class/devfreq/*cpu*-bw \
            /sys/class/devfreq/*llccbw* \
            /sys/class/devfreq/*bus_llcc* \
            /sys/class/devfreq/*bus_ddr* \
            /sys/class/devfreq/*memlat* \
            /sys/class/devfreq/*cpubw* \
            /sys/class/devfreq/*kgsl-ddr-qos*; do
            if [ "$LITE_MODE" -eq 1 ]; then
                devfreq_mid_perf "$path"
            else
                devfreq_max_perf "$path"
            fi
        done

        for component in DDR LLCC L3; do
            local path="/sys/devices/system/cpu/bus_dcvs/$component"
            if [ "$LITE_MODE" -eq 1 ]; then
                qcom_cpudcvs_mid_perf "$path"
            else
                qcom_cpudcvs_max_perf "$path"
            fi
        done
    fi

    local gpu_path="/sys/class/kgsl/kgsl-3d0/devfreq"
    if [ "$LITE_MODE" -eq 0 ]; then
        devfreq_max_perf "$gpu_path"
    else
        devfreq_mid_perf "$gpu_path"
    fi
    tweak 0 /sys/class/kgsl/kgsl-3d0/bus_split
    tweak 1 /sys/class/kgsl/kgsl-3d0/force_clk_on

    yanz_snapdragon_boost
}

exynos_performance() {
    local gpu_path="/sys/kernel/gpu"
    if [ -d "$gpu_path" ]; then
        local max_freq=$(which_maxfreq "$gpu_path/gpu_available_frequencies")
        tweak "$max_freq" "$gpu_path/gpu_max_clock"
        if [ "$LITE_MODE" -eq 1 ]; then
            local mid_freq=$(which_midfreq "$gpu_path/gpu_available_frequencies")
            tweak "$mid_freq" "$gpu_path/gpu_min_clock"
        else
            tweak "$max_freq" "$gpu_path/gpu_min_clock"
        fi
    fi
    local mali_sysfs=$(find /sys/devices/platform/ -iname "*.mali" -print -quit 2>/dev/null)
    tweak always_on "$mali_sysfs/power_policy"

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            if [ "$LITE_MODE" -eq 1 ]; then
                devfreq_mid_perf "$path"
            else
                devfreq_max_perf "$path"
            fi
        done
    fi
}

unisoc_performance() {
    local gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        if [ "$LITE_MODE" -eq 0 ]; then
            devfreq_max_perf "$gpu_path"
        else
            devfreq_mid_perf "$gpu_path"
        fi
    }
}

tensor_performance() {
    local gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        local max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
        tweak "$max_freq" "$gpu_path/scaling_max_freq"

        if [ "$LITE_MODE" -eq 1 ]; then
            local mid_freq=$(which_midfreq "$gpu_path/available_frequencies")
            tweak "$mid_freq" "$gpu_path/scaling_min_freq"
        else
            tweak "$max_freq" "$gpu_path/scaling_min_freq"
        fi
    }

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            if [ "$LITE_MODE" -eq 1 ]; then
                devfreq_mid_perf "$path"
            else
                devfreq_max_perf "$path"
            fi
        done
    fi
}

tegra_performance() {
    local gpu_path="/sys/kernel/tegra_gpu"
    if [ -d "$gpu_path" ]; then
        local max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
        tweak "$max_freq" "$gpu_path/gpu_cap_rate"
        if [ "$LITE_MODE" -eq 1 ]; then
            local mid_freq=$(which_midfreq "$gpu_path/available_frequencies")
            tweak "$mid_freq" "$gpu_path/gpu_floor_rate"
        else
            tweak "$max_freq" "$gpu_path/gpu_floor_rate"
        fi
    fi
}

mediatek_normal() {
    tweak 0 /proc/cpufreq/cpufreq_cci_mode
    tweak 0 /proc/cpufreq/cpufreq_power_mode
    tweak 0 /sys/devices/platform/boot_dramboost/dramboost/dramboost
    tweak 2 /sys/devices/system/cpu/eas/enable
    tweak "stop 0" /proc/mtk_batoc_throttling/battery_oc_protect_stop
    kakangkuh -1 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
    kakangkuh -1 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
    devfreq_unlock /sys/class/devfreq/mtk-dvfsrc-devfreq
    tweak 1 /sys/kernel/eara_thermal/enable

    mtkvest_normal
    yanz_mtk_balance
}

snapdragon_normal() {
    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*cpu*-lat \
            /sys/class/devfreq/*cpu*-bw \
            /sys/class/devfreq/*llccbw* \
            /sys/class/devfreq/*bus_llcc* \
            /sys/class/devfreq/*bus_ddr* \
            /sys/class/devfreq/*memlat* \
            /sys/class/devfreq/*cpubw* \
            /sys/class/devfreq/*kgsl-ddr-qos*; do
            devfreq_unlock "$path"
        done

        for component in DDR LLCC L3; do
            qcom_cpudcvs_unlock /sys/devices/system/cpu/bus_dcvs/$component
        done
    fi

    devfreq_unlock /sys/class/kgsl/kgsl-3d0/devfreq
    tweak 1 /sys/class/kgsl/kgsl-3d0/bus_split
    tweak 0 /sys/class/kgsl/kgsl-3d0/force_clk_on
    yanz_snapdragon_balance
}

exynos_normal() {
    local gpu_path="/sys/kernel/gpu"
    if [ -d "$gpu_path" ]; then
        local max_freq=$(which_maxfreq "$gpu_path/gpu_available_frequencies")
        local min_freq=$(which_minfreq "$gpu_path/available_frequencies")
        kakangkuh "$max_freq" "$gpu_path/gpu_max_clock"
        kakangkuh "$min_freq" "$gpu_path/gpu_min_clock"
    fi
    local mali_sysfs=$(find /sys/devices/platform/ -iname "*.mali" -print -quit 2>/dev/null)
    tweak coarse_demand "$mali_sysfs/power_policy"

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            devfreq_unlock "$path"
        done
    fi
}

unisoc_normal() {
    local gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && devfreq_unlock "$gpu_path"
}

tensor_normal() {
    local gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        local max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
        local min_freq=$(which_minfreq "$gpu_path/available_frequencies")
        kakangkuh "$max_freq" "$gpu_path/scaling_max_freq"
        kakangkuh "$min_freq" "$gpu_path/scaling_min_freq"
    }

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            devfreq_unlock "$path"
        done
    fi
}

tegra_normal() {
    local gpu_path="/sys/kernel/tegra_gpu"
    [ -d "$gpu_path" ] && {
        local max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
        local min_freq=$(which_minfreq "$gpu_path/available_frequencies")
        kakangkuh "$max_freq" "$gpu_path/gpu_cap_rate"
        kakangkuh "$min_freq" "$gpu_path/gpu_floor_rate"
    }
}

mediatek_powersave() {
    tweak 1 /proc/cpufreq/cpufreq_power_mode
    yanz_mtk_powersave
}

snapdragon_powersave() {
    devfreq_min_perf /sys/class/kgsl/kgsl-3d0/devfreq
    yanz_snapdragon_powersave
}

exynos_powersave() {
    local gpu_path="/sys/kernel/gpu"
    [ -d "$gpu_path" ] && {
        local freq=$(which_minfreq "$gpu_path/gpu_available_frequencies")
        tweak "$freq" "$gpu_path/gpu_min_clock"
        tweak "$freq" "$gpu_path/gpu_max_clock"
    }
}

unisoc_powersave() {
    local gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && devfreq_min_perf "$gpu_path"
}

tensor_powersave() {
    local gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        local freq=$(which_minfreq "$gpu_path/available_frequencies")
        tweak "$freq" "$gpu_path/scaling_min_freq"
        tweak "$freq" "$gpu_path/scaling_max_freq"
    }
}

tegra_powersave() {
    local gpu_path="/sys/kernel/tegra_gpu"
    [ -d "$gpu_path" ] && {
        local freq=$(which_minfreq "$gpu_path/available_frequencies")
        tweak "$freq" "$gpu_path/gpu_floor_rate"
        tweak "$freq" "$gpu_path/gpu_cap_rate"
    }
}

##################################
# Performance Profile (1)
##################################
performance_basic() {
    sync
    
    for dir in /sys/block/*; do
        tweak 0 "$dir/queue/iostats"
        tweak 0 "$dir/queue/add_random"
        tweak 32 "$dir/queue/read_ahead_kb"
        tweak 32 "$dir/queue/nr_requests"
    done

    tweak 1 "$ipv4/tcp_low_latency"
    tweak 1 "$ipv4/tcp_ecn"
    tweak 3 "$ipv4/tcp_fastopen"
    tweak 1 "$ipv4/tcp_sack"
    tweak 0 "$ipv4/tcp_timestamps"

    tweak 3 /proc/sys/kernel/perf_cpu_time_max_percent
    tweak 0 /proc/sys/kernel/sched_schedstats
    tweak 0 /proc/sys/kernel/task_cpustats_enable
    tweak 0 /proc/sys/kernel/sched_autogroup_enabled
    tweak 1 /proc/sys/kernel/sched_child_runs_first
    tweak 32 /proc/sys/kernel/sched_nr_migrate
    tweak 50000 /proc/sys/kernel/sched_migration_cost_ns
    tweak 1000000 /proc/sys/kernel/sched_min_granularity_ns
    tweak 1500000 /proc/sys/kernel/sched_wakeup_granularity_ns
    tweak 0 /proc/sys/kernel/split_lock_mitigate

    tweak 0 /proc/sys/vm/page-cluster
    tweak 15 /proc/sys/vm/stat_interval
    tweak 0 /proc/sys/vm/compaction_proactiveness
    tweak 0 /sys/module/mmc_core/parameters/use_spi_crc
    tweak 0 /sys/module/opchain/parameters/chain_on
    tweak 0 /sys/module/cpufreq_bouncing/parameters/enable
    tweak 0 /proc/task_info/task_sched_info/task_sched_info_enable
    tweak 0 /proc/oplus_scheduler/sched_assist/sched_assist_enabled
    tweak "libunity.so, libil2cpp.so, libmain.so, libUE4.so, libgodot_android.so, libgdx.so, libgdx-box2d.so, libminecraftpe.so, libLive2DCubismCore.so, libyuzu-android.so, libryujinx.so, libcitra-android.so, libhdr_pro_engine.so, libandroidx.graphics.path.so, libeffect.so" /proc/sys/kernel/sched_lib_name
    tweak 255 /proc/sys/kernel/sched_lib_mask_force
    tweak 80 /proc/sys/vm/vfs_cache_pressure

    for dir in /sys/class/thermal/thermal_zone*; do
        tweak "step_wise" "$dir/policy"
    done

    if [ -f /sys/module/battery_saver/parameters/enabled ]; then
        if grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled; then
            tweak 0 /sys/module/battery_saver/parameters/enabled
        else
            tweak N /sys/module/battery_saver/parameters/enabled
        fi
    fi

    if [ -f "/sys/kernel/debug/sched_features" ]; then
        tweak NEXT_BUDDY /sys/kernel/debug/sched_features
        tweak NO_TTWU_QUEUE /sys/kernel/debug/sched_features
    fi

    if [ -d "/dev/stune/" ]; then
        tweak 1 /dev/stune/top-app/schedtune.prefer_idle
        tweak 1 /dev/stune/top-app/schedtune.boost
    fi

    tp_path="/proc/touchpanel"
    if [ -d "$tp_path" ]; then
        tweak 1 $tp_path/game_switch_enable
        tweak 0 $tp_path/oplus_tp_limit_enable
        tweak 0 $tp_path/oppo_tp_limit_enable
        tweak 1 $tp_path/oplus_tp_direction
        tweak 1 $tp_path/oppo_tp_direction
    fi

    for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
        if [ -d "$path" ]; then
            if [ "$LITE_MODE" -eq 1 ]; then
                devfreq_mid_perf "$path"
            else
                devfreq_max_perf "$path"
            fi
        fi
    done

    # CPU SETTINGS: Order matters. Reset limits, Set Gov, Then Apply Profile
    change_cpu_gov "performance"
    sleep 1 # Safety wait
    
    if [ -d "/proc/ppm" ]; then
        cpufreq_ppm_max_perf
    fi
    cpufreq_max_perf
    
    case $SOC in
        1) mediatek_performance ;;
        2) snapdragon_performance ;;
        3) exynos_performance ;;
        4) unisoc_performance ;;
        5) tensor_performance ;;
        6) tegra_performance ;;
    esac

    dnd_on
    corin_perf
    bypass_on
    clear_slingshot

    if [ "$KCPU_MITIGATE" -eq 0 ]; then
        carcpu_perf
    fi

    anyamelfissa
}

##########################################
# Balanced Profile (2) - REWORKED
##########################################
balanced_basic() {
    sync
    
    # Reset Block I/O
    for dir in /sys/block/*; do
        kakangkuh 1 "$dir/queue/iostats"
        kakangkuh 1 "$dir/queue/add_random"
        kakangkuh 128 "$dir/queue/read_ahead_kb"
        kakangkuh 128 "$dir/queue/nr_requests"
    done

    # Reset Net
    kakangkuh 0 /proc/sys/net/ipv4/tcp_low_latency
    kakangkuh 2 /proc/sys/net/ipv4/tcp_ecn
    kakangkuh 1 /proc/sys/net/ipv4/tcp_fastopen
    kakangkuh 1 /proc/sys/net/ipv4/tcp_timestamps

    # Reset Sched & VM
    kakangkuh 500000 /proc/sys/kernel/sched_migration_cost_ns
    kakangkuh 3000000 /proc/sys/kernel/sched_min_granularity_ns
    kakangkuh 4000000 /proc/sys/kernel/sched_wakeup_granularity_ns
    kakangkuh 1 /proc/sys/vm/stat_interval
    kakangkuh 3 /proc/sys/vm/page-cluster
    kakangkuh 1 /proc/sys/kernel/split_lock_mitigate
    kakangkuh 120 /proc/sys/vm/vfs_cache_pressure

    if [ -f /sys/module/battery_saver/parameters/enabled ]; then
        if grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled; then
            kakangkuh 0 /sys/module/battery_saver/parameters/enabled
        else
            kakangkuh N /sys/module/battery_saver/parameters/enabled
        fi
    fi

    if [ -f "/sys/kernel/debug/sched_features" ]; then
        kakangkuh NEXT_BUDDY /sys/kernel/debug/sched_features
        kakangkuh TTWU_QUEUE /sys/kernel/debug/sched_features
    fi

    if [ -d "/dev/stune/" ]; then
        kakangkuh 0 /dev/stune/top-app/schedtune.prefer_idle
        kakangkuh 0 /dev/stune/top-app/schedtune.boost
    fi

    tp_path="/proc/touchpanel"
    if [ -d "$tp_path" ]; then
        kakangkuh 0 $tp_path/game_switch_enable
        kakangkuh 1 $tp_path/oplus_tp_limit_enable
        kakangkuh 1 $tp_path/oppo_tp_limit_enable
        kakangkuh 0 $tp_path/oplus_tp_direction
        kakangkuh 0 $tp_path/oppo_tp_direction
    fi

    for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
         devfreq_unlock "$path"
    done

    # CPU SETTINGS
    # 1. First, reset frequencies to hardware defaults (Unlock)
    # This prevents the "max < min" write errors if coming from powersave/perf
    if [ -d "/proc/ppm" ]; then
        cpufreq_ppm_unlock
    fi
    cpufreq_unlock
    
    # 2. Then set the balanced governor
    change_cpu_gov "$DEFAULT_CPU_GOV"

    case $SOC in
        1) mediatek_normal ;;
        2) snapdragon_normal ;;
        3) exynos_normal ;;
        4) unisoc_normal ;;
        5) tensor_normal ;;
        6) tegra_normal ;;
    esac
    
    dnd_off
    corin_balanced
    bypass_off
    clear_slingshot

    if [ "$KCPU_MITIGATE" -eq 0 ]; then
        carcpu_balance
    fi

    anyakawaii
}

##########################################
# Powersave Profile (3)
##########################################
powersave_basic() {
    sync
    
    if [ -f /sys/module/battery_saver/parameters/enabled ]; then
        if grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled; then
            kakangkuh 1 /sys/module/battery_saver/parameters/enabled
        else
            kakangkuh Y /sys/module/battery_saver/parameters/enabled
        fi
    fi

    kakangkuh 1 /proc/sys/kernel/split_lock_mitigate
    kakangkuh 100 /proc/sys/vm/vfs_cache_pressure

    if [ -f "/sys/kernel/debug/sched_features" ]; then
        kakangkuh NEXT_BUDDY /sys/kernel/debug/sched_features
        kakangkuh NO_TTWU_QUEUE /sys/kernel/debug/sched_features
    fi

    if [ -d "/dev/stune/" ]; then
        kakangkuh 0 /dev/stune/top-app/schedtune.prefer_idle
        kakangkuh 0 /dev/stune/top-app/schedtune.boost
    fi

    tp_path="/proc/touchpanel"
    if [ -d "$tp_path" ]; then
        kakangkuh 0 $tp_path/game_switch_enable
        kakangkuh 1 $tp_path/oplus_tp_limit_enable
        kakangkuh 1 $tp_path/oppo_tp_limit_enable
        kakangkuh 0 $tp_path/oplus_tp_direction
        kakangkuh 0 $tp_path/oppo_tp_direction
    fi
    
    for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
        devfreq_min_perf "$path"
    done

    # CPU SETTINGS
    # 1. Reset limits to prevent errors
    cpufreq_reset_limits

    # 2. Set powersave gov
    change_cpu_gov "powersave"
    sleep 1

    # 3. Apply limits
    if [ -d "/proc/ppm" ]; then
        cpufreq_ppm_min_perf
    fi
    cpufreq_min_perf

    case $SOC in
        1) mediatek_powersave ;;
        2) snapdragon_powersave ;;
        3) exynos_powersave ;;
        4) unisoc_powersave ;;
        5) tensor_powersave ;;
        6) tegra_powersave ;;
    esac

    dnd_off
    corin_powersave
    bypass_off
    clear_slingshot

    if [ "$KCPU_MITIGATE" -eq 0 ]; then
        carcpu_battery
    fi

    anyakawaii
}

##########################################
# MAIN EXECUTION LOGIC
##########################################

if [ -z "$1" ]; then
    echo "Usage: $0 <mode>"
    exit 1
fi

MODE=$1

case $MODE in
    1)
        performance_basic
        set_state 1
        notification "Performance Mode Activated 🔥"
        ;;
    2)
        balanced_basic
        set_state 2
        notification "Balanced Mode Activated ⚖️"
        ;;
    3)
        powersave_basic
        set_state 3
        notification "Powersave Mode Activated 🔋"
        ;;
    4)
        performance_basic
        kill_all
        set_state 4
        notification "Gaming Pro Mode Activated 🚀"
        ;;
    5)
        set_state 5
        powersave_basic
        notification "Cool Down initiated for 2 minutes... ❄️"
        sleep 120
        balanced_basic
        set_state 2
        notification "Cool Down finished. Switched to Balanced Mode."
        ;;
    6)
        kill_all
        notification "All background applications cleared. ✅"
        ;;
    *)
        echo "Error: Invalid mode '$MODE'."
        exit 1
        ;;
esac

exit 0