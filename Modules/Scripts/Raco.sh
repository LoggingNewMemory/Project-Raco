#!/system/bin/sh

###############################
# DEFINE CONFIG
###############################

RACO_CONFIG="/data/ProjectRaco/raco.txt"

# Read all config values at once
read_config() {
    SOC=$(awk -F'=' '/^SOC=/ {print $2}' "$RACO_CONFIG")
    LITE_MODE=$(awk -F'=' '/^LITE_MODE=/ {print $2}' "$RACO_CONFIG")
    LIFE_MODE=$(awk -F'=' '/^LIFE_MODE=/ {print $2}' "$RACO_CONFIG")
    BETTER_POWERAVE=$(awk -F'=' '/^BETTER_POWERAVE=/ {print $2}' "$RACO_CONFIG")
    ANYA=$(awk -F'=' '/^ANYA=/ {print $2}' "$RACO_CONFIG")
    INCLUDE_ANYA=$(awk -F'=' '/^INCLUDE_ANYA=/ {print $2}' "$RACO_CONFIG")
    KCPU_MITIGATE=$(awk -F'=' '/^KCPU_MITIGATE=/ {print $2}' "$RACO_CONFIG")
    LEGACY_NOTIF=$(awk -F'=' '/^LEGACY_NOTIF=/ {print $2}' "$RACO_CONFIG")
    CPU_MAX_LIST=$(awk -F'=' '/^CPU_MAX=/ {print $2}' "$RACO_CONFIG")
    CPU_MID_LIST=$(awk -F'=' '/^CPU_MID=/ {print $2}' "$RACO_CONFIG")
    CPU_MIN_LIST=$(awk -F'=' '/^CPU_MIN=/ {print $2}' "$RACO_CONFIG")
    DEFAULT_CPU_GOV=$(awk -F'=' '/^GOV=/ {print $2}' "$RACO_CONFIG")
    DEVICE_MITIGATION=$(awk -F'=' '/^DEVICE_MITIGATION=/ {print $2}' "$RACO_CONFIG")
    DND=$(awk -F'=' '/^DND=/ {print $2}' "$RACO_CONFIG")
    BYPASS=$(awk -F'=' '/^ENABLE_BYPASS=/ {print $2; exit}' "$RACO_CONFIG" | tr -d ' ')
}

read_config

# Set default governor if not specified
if [ -z "$DEFAULT_CPU_GOV" ]; then
    if [ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ] && grep -q "schedhorizon" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
        DEFAULT_CPU_GOV="schedhorizon"
    else
        DEFAULT_CPU_GOV="schedutil"
    fi
fi

##############################
# Path Variables
##############################
ipv4="/proc/sys/net/ipv4"
SCRIPT_PATH="/data/adb/modules/ProjectRaco/Scripts"
STAR_PATH="$SCRIPT_PATH/STAR"
MODULE_PATH="/data/adb/modules/ProjectRaco"

##############################
# Source External Scripts
##############################
source "$MODULE_PATH/Scripts/corin.sh"

[ "$KCPU_MITIGATE" -eq 0 ] && [ -f "$SCRIPT_PATH/CarlottaCPU.sh" ] && source "$SCRIPT_PATH/CarlottaCPU.sh"

##############################
# Core Functions
##############################

tweak() {
    [ -e "$2" ] && {
        chmod 644 "$2" 2>/dev/null
        echo "$1" > "$2" 2>/dev/null
        chmod 444 "$2" 2>/dev/null
    }
}

kakangkuh() {
    [ -f "$2" ] && {
        chmod 644 "$2" 2>/dev/null
        echo "$1" > "$2" 2>/dev/null
    }
}

anyamelfissa() {
    [ "$INCLUDE_ANYA" = "1" ] && [ "$ANYA" = "1" ] && sh /data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh &
}

anyakawaii() {
    [ "$INCLUDE_ANYA" = "1" ] && [ "$ANYA" = "1" ] && sh /data/adb/modules/ProjectRaco/Scripts/AnyaKawaii.sh &
}

kill_all() {
    {
        sync
        cmd activity kill-all
        for pkg in $(pm list packages -3 | cut -f 2 -d ":"); do
            [ "$pkg" != "com.google.android.inputmethod.latin" ] && am force-stop "$pkg" &
        done
        wait
        pm trim-caches 100G
        echo 3 > /proc/sys/vm/drop_caches
        logcat -c
        logcat -b all -c
        sh $STAR_PATH/KILL.sh
    } > /dev/null 2>&1 &
}

bypass_on() {
    [ "$BYPASS" = "Yes" ] && sh $SCRIPT_PATH/raco_bypass_controller.sh enable &
}

bypass_off() {
    [ "$BYPASS" = "Yes" ] && sh $SCRIPT_PATH/raco_bypass_controller.sh disable &
}

notification() {
    if [ "$LEGACY_NOTIF" = "1" ]; then
        su -lp 2000 -c "cmd notification post -S bigtext -t 'Otonose Raco' TagRaco '$1'"
    else
        su -lp 2000 -c "cmd notification post -S bigtext -t 'Otonose Raco' -i file:///data/local/tmp/logo.png -I file:///data/local/tmp/logo.png TagRaco '$1'"
    fi
}

dnd_off() {
    [ "$DND" = "Yes" ] && cmd notification set_dnd off
}

dnd_on() {
    [ "$DND" = "Yes" ] && cmd notification set_dnd priority
}

###################################
# MTKVest Functions 
###################################

mtkvest_perf() {
    {
        tweak 1 /proc/perfmgr/syslimiter/syslimiter_force_disable
        [ -d /sys/kernel/ged/hal ] && {
            tweak 2 /sys/kernel/ged/hal/loading_base_dvfs_step
            tweak 1 /sys/kernel/ged/hal/loading_stride_size
            tweak 16 /sys/kernel/ged/hal/loading_window_size
        }
        tweak 100 /sys/kernel/ged/hal/gpu_boost_level
    } &
}

mtkvest_normal() {
    {
        tweak 0 /proc/perfmgr/syslimiter/syslimiter_force_disable
        [ -d /sys/kernel/ged/hal ] && {
            tweak 4 /sys/kernel/ged/hal/loading_base_dvfs_step
            tweak 2 /sys/kernel/ged/hal/loading_stride_size
            tweak 8 /sys/kernel/ged/hal/loading_window_size
        }
        tweak -1 /sys/kernel/ged/hal/gpu_boost_level
    } &
}

###################################
# Frequency Functions
###################################

which_maxfreq() {
    tr ' ' '\n' < "$1" | sort -nr | head -n 1
}

which_minfreq() {
    tr ' ' '\n' < "$1" | grep -v '^[[:space:]]*$' | sort -n | head -n 1
}

which_midfreq() {
    total_opp=$(wc -w < "$1")
    mid_opp=$(((total_opp + 1) / 2))
    tr ' ' '\n' < "$1" | grep -v '^[[:space:]]*$' | sort -nr | head -n $mid_opp | tail -n 1
}

mtk_gpufreq_minfreq_index() {
    awk -F'[][]' '{print $2}' "$1" | tail -n 1
}

mtk_gpufreq_midfreq_index() {
    total_opp=$(wc -l < "$1")
    mid_opp=$(((total_opp + 1) / 2))
    awk -F'[][]' '{print $2}' "$1" | head -n $mid_opp | tail -n 1
}

devfreq_max_perf() {
    [ -f "$1/available_frequencies" ] && {
        max_freq=$(which_maxfreq "$1/available_frequencies")
        tweak "$max_freq" "$1/max_freq"
        tweak "$max_freq" "$1/min_freq"
    }
}

devfreq_mid_perf() {
    [ -f "$1/available_frequencies" ] && {
        max_freq=$(which_maxfreq "$1/available_frequencies")
        mid_freq=$(which_midfreq "$1/available_frequencies")
        tweak "$max_freq" "$1/max_freq"
        tweak "$mid_freq" "$1/min_freq"
    }
}

devfreq_unlock() {
    [ -f "$1/available_frequencies" ] && {
        max_freq=$(which_maxfreq "$1/available_frequencies")
        min_freq=$(which_minfreq "$1/available_frequencies")
        kakangkuh "$max_freq" "$1/max_freq"
        kakangkuh "$min_freq" "$1/min_freq"
    }
}

devfreq_min_perf() {
    [ -f "$1/available_frequencies" ] && {
        freq=$(which_minfreq "$1/available_frequencies")
        tweak "$freq" "$1/min_freq"
        tweak "$freq" "$1/max_freq"
    }
}

qcom_cpudcvs_max_perf() {
    [ -f "$1/available_frequencies" ] && {
        freq=$(which_maxfreq "$1/available_frequencies")
        tweak "$freq" "$1/hw_max_freq"
        tweak "$freq" "$1/hw_min_freq"
    }
}

qcom_cpudcvs_mid_perf() {
    [ -f "$1/available_frequencies" ] && {
        max_freq=$(which_maxfreq "$1/available_frequencies")
        mid_freq=$(which_midfreq "$1/available_frequencies")
        tweak "$max_freq" "$1/hw_max_freq"
        tweak "$mid_freq" "$1/hw_min_freq"
    }
}

qcom_cpudcvs_unlock() {
    [ -f "$1/available_frequencies" ] && {
        max_freq=$(which_maxfreq "$1/available_frequencies")
        min_freq=$(which_minfreq "$1/available_frequencies")
        kakangkuh "$max_freq" "$1/hw_max_freq"
        kakangkuh "$min_freq" "$1/hw_min_freq"
    }
}

change_cpu_gov() {
    chmod 644 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null
    echo "$1" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor > /dev/null 2>&1
    chmod 444 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null
}

cpufreq_ppm_max_perf() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local i=$((cluster + 1))
        local cpu_maxfreq=$(echo "$CPU_MAX_LIST" | cut -d ' ' -f $i)
        local cpu_midfreq=$(echo "$CPU_MID_LIST" | cut -d ' ' -f $i)
        
        tweak "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        [ "$LITE_MODE" -eq 1 ] && tweak "$cluster $cpu_midfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq || tweak "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        cluster=$((cluster + 1))
    done
}

cpufreq_max_perf() {
    local i=1
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local cpu_maxfreq=$(echo "$CPU_MAX_LIST" | cut -d ' ' -f $i)
        local cpu_midfreq=$(echo "$CPU_MID_LIST" | cut -d ' ' -f $i)
        
        tweak "$cpu_maxfreq" "$path/scaling_max_freq"
        [ "$LITE_MODE" -eq 1 ] && tweak "$cpu_midfreq" "$path/scaling_min_freq" || tweak "$cpu_maxfreq" "$path/scaling_min_freq"
        i=$((i + 1))
    done
    chmod 444 /sys/devices/system/cpu/cpufreq/policy*/scaling_*_freq 2>/dev/null
}

cpufreq_ppm_unlock() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local i=$((cluster + 1))
        local cpu_maxfreq=$(echo "$CPU_MAX_LIST" | cut -d ' ' -f $i)
        local cpu_minfreq=$(echo "$CPU_MIN_LIST" | cut -d ' ' -f $i)
        
        kakangkuh "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        kakangkuh "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        cluster=$((cluster + 1))
    done
}

cpufreq_unlock() {
    local i=1
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local cpu_maxfreq=$(echo "$CPU_MAX_LIST" | cut -d ' ' -f $i)
        local cpu_minfreq=$(echo "$CPU_MIN_LIST" | cut -d ' ' -f $i)
        
        kakangkuh "$cpu_maxfreq" "$path/scaling_max_freq"
        kakangkuh "$cpu_minfreq" "$path/scaling_min_freq"
        i=$((i + 1))
    done
    chmod 644 /sys/devices/system/cpu/cpufreq/policy*/scaling_*_freq 2>/dev/null
}

cpufreq_ppm_life_perf() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local i=$((cluster + 1))
        local cpu_midfreq=$(echo "$CPU_MID_LIST" | cut -d ' ' -f $i)
        local cpu_minfreq=$(echo "$CPU_MIN_LIST" | cut -d ' ' -f $i)
        
        kakangkuh "$cluster $cpu_midfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        kakangkuh "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        cluster=$((cluster + 1))
    done
}

cpufreq_life_perf() {
    local i=1
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local cpu_midfreq=$(echo "$CPU_MID_LIST" | cut -d ' ' -f $i)
        local cpu_minfreq=$(echo "$CPU_MIN_LIST" | cut -d ' ' -f $i)
        
        kakangkuh "$cpu_midfreq" "$path/scaling_max_freq"
        kakangkuh "$cpu_minfreq" "$path/scaling_min_freq"
        i=$((i + 1))
    done
    chmod 644 /sys/devices/system/cpu/cpufreq/policy*/scaling_*_freq 2>/dev/null
}

cpufreq_ppm_min_perf() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local i=$((cluster + 1))
        local cpu_midfreq=$(echo "$CPU_MID_LIST" | cut -d ' ' -f $i)
        local cpu_minfreq=$(echo "$CPU_MIN_LIST" | cut -d ' ' -f $i)
        
        if [ "$BETTER_POWERAVE" -eq 1 ]; then
            tweak "$cluster $cpu_midfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        else
            tweak "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        fi
        tweak "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        cluster=$((cluster + 1))
    done
}

cpufreq_min_perf() {
    local i=1
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local cpu_midfreq=$(echo "$CPU_MID_LIST" | cut -d ' ' -f $i)
        local cpu_minfreq=$(echo "$CPU_MIN_LIST" | cut -d ' ' -f $i)
        
        [ "$BETTER_POWERAVE" -eq 1 ] && tweak "$cpu_midfreq" "$path/scaling_max_freq" || tweak "$cpu_minfreq" "$path/scaling_max_freq"
        tweak "$cpu_minfreq" "$path/scaling_min_freq"
        i=$((i + 1))
    done
    chmod 444 /sys/devices/system/cpu/cpufreq/policy*/scaling_*_freq 2>/dev/null
}

###################################
# Device-specific Functions
###################################

mediatek_performance() {
    {
        tweak 1 /proc/cpufreq/cpufreq_cci_mode
        tweak 3 /proc/cpufreq/cpufreq_power_mode
        tweak 0 /sys/kernel/fpsgo/common/force_onoff
        tweak 1 /sys/devices/platform/boot_dramboost/dramboost/dramboost
        tweak 0 /sys/devices/system/cpu/eas/enable
        tweak 0 /sys/module/sspm_v3/holders/ged/parameters/is_GED_KPI_enabled
        
        if [ "$LITE_MODE" -eq 0 ]; then
            if [ -d /proc/gpufreqv2 ]; then
                tweak 0 /proc/gpufreqv2/fix_target_opp_index
            else
                gpu_freq=$(sed -n 's/.*freq = \([0-9]\{1,\}\).*/\1/p' /proc/gpufreq/gpufreq_opp_dump | head -n 1)
                tweak "$gpu_freq" /proc/gpufreq/gpufreq_opp_freq
            fi
            tweak 0 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
            tweak 0 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
            devfreq_max_perf /sys/class/devfreq/mtk-dvfsrc-devfreq
        else
            tweak 0 /proc/gpufreq/gpufreq_opp_freq
            tweak -1 /proc/gpufreqv2/fix_target_opp_index
            [ -d /proc/gpufreqv2 ] && mid_oppfreq=$(mtk_gpufreq_midfreq_index /proc/gpufreqv2/gpu_working_opp_table) || mid_oppfreq=$(mtk_gpufreq_midfreq_index /proc/gpufreq/gpufreq_opp_dump)
            tweak "$mid_oppfreq" /sys/kernel/ged/hal/custom_boost_gpu_freq
            tweak -1 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
            tweak -1 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
            devfreq_mid_perf /sys/class/devfreq/mtk-dvfsrc-devfreq
        fi
        
        [ -f "/proc/gpufreq/gpufreq_power_limited" ] && {
            for setting in ignore_batt_oc ignore_batt_percent ignore_low_batt ignore_thermal_protect ignore_pbm_limited; do
                tweak "$setting 1" /proc/gpufreq/gpufreq_power_limited
            done
        }
        
        tweak "stop 1" /proc/mtk_batoc_throttling/battery_oc_protect_stop
        tweak 0 /sys/kernel/eara_thermal/enable
        mtkvest_perf
    } &
}

snapdragon_performance() {
    {
        if [ "$DEVICE_MITIGATION" -eq 0 ]; then
            for path in /sys/class/devfreq/*{cpu*-lat,cpu*-bw,llccbw*,bus_llcc*,bus_ddr*,memlat*,cpubw*,kgsl-ddr-qos*}; do
                [ "$LITE_MODE" -eq 1 ] && devfreq_mid_perf "$path" || devfreq_max_perf "$path"
            done
            
            for component in DDR LLCC L3; do
                [ "$LITE_MODE" -eq 1 ] && qcom_cpudcvs_mid_perf "/sys/devices/system/cpu/bus_dcvs/$component" || qcom_cpudcvs_max_perf "/sys/devices/system/cpu/bus_dcvs/$component"
            done
        fi
        
        gpu_path="/sys/class/kgsl/kgsl-3d0/devfreq"
        [ "$LITE_MODE" -eq 0 ] && devfreq_max_perf "$gpu_path" || devfreq_mid_perf "$gpu_path"
        
        tweak 0 /sys/class/kgsl/kgsl-3d0/bus_split
        tweak 1 /sys/class/kgsl/kgsl-3d0/force_clk_on
    } &
}

tegra_performance() {
    gpu_path="/sys/kernel/tegra_gpu"
    [ -d "$gpu_path" ] && {
        max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
        tweak "$max_freq" "$gpu_path/gpu_cap_rate"
        [ "$LITE_MODE" -eq 1 ] && mid_freq=$(which_midfreq "$gpu_path/available_frequencies") && tweak "$mid_freq" "$gpu_path/gpu_floor_rate" || tweak "$max_freq" "$gpu_path/gpu_floor_rate"
    } &
}

exynos_performance() {
    {
        gpu_path="/sys/kernel/gpu"
        [ -d "$gpu_path" ] && {
            max_freq=$(which_maxfreq "$gpu_path/gpu_available_frequencies")
            tweak "$max_freq" "$gpu_path/gpu_max_clock"
            [ "$LITE_MODE" -eq 1 ] && mid_freq=$(which_midfreq "$gpu_path/gpu_available_frequencies") && tweak "$mid_freq" "$gpu_path/gpu_min_clock" || tweak "$max_freq" "$gpu_path/gpu_min_clock"
        }
        
        mali_sysfs=$(find /sys/devices/platform/ -iname "*.mali" -print -quit 2>/dev/null)
        tweak always_on "$mali_sysfs/power_policy"
        
        [ "$DEVICE_MITIGATION" -eq 0 ] && {
            for path in /sys/class/devfreq/*devfreq_mif*; do
                [ "$LITE_MODE" -eq 1 ] && devfreq_mid_perf "$path" || devfreq_max_perf "$path"
            done
        }
    } &
}

unisoc_performance() {
    gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        [ "$LITE_MODE" -eq 0 ] && devfreq_max_perf "$gpu_path" || devfreq_mid_perf "$gpu_path"
    } &
}

tensor_performance() {
    {
        gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
        [ -n "$gpu_path" ] && {
            max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
            tweak "$max_freq" "$gpu_path/scaling_max_freq"
            [ "$LITE_MODE" -eq 1 ] && mid_freq=$(which_midfreq "$gpu_path/available_frequencies") && tweak "$mid_freq" "$gpu_path/scaling_min_freq" || tweak "$max_freq" "$gpu_path/scaling_min_freq"
        }
        
        [ "$DEVICE_MITIGATION" -eq 0 ] && {
            for path in /sys/class/devfreq/*devfreq_mif*; do
                [ "$LITE_MODE" -eq 1 ] && devfreq_mid_perf "$path" || devfreq_max_perf "$path"
            done
        }
    } &
}

mediatek_normal() {
    {
        tweak 2 /sys/kernel/fpsgo/common/force_onoff
        tweak 0 /proc/cpufreq/cpufreq_cci_mode
        tweak 0 /proc/cpufreq/cpufreq_power_mode
        tweak 0 /sys/devices/platform/boot_dramboost/dramboost/dramboost
        tweak 2 /sys/devices/system/cpu/eas/enable
        tweak 1 /sys/module/sspm_v3/holders/ged/parameters/is_GED_KPI_enabled
        kakangkuh 0 /proc/gpufreq/gpufreq_opp_freq
        kakangkuh -1 /proc/gpufreqv2/fix_target_opp_index
        
        [ -d /proc/gpufreqv2 ] && min_oppfreq=$(mtk_gpufreq_minfreq_index /proc/gpufreqv2/gpu_working_opp_table) || min_oppfreq=$(mtk_gpufreq_minfreq_index /proc/gpufreq/gpufreq_opp_dump)
        tweak "$min_oppfreq" /sys/kernel/ged/hal/custom_boost_gpu_freq
        
        [ -f "/proc/gpufreq/gpufreq_limit_table" ] && for id in {0..8}; do tweak "$id 1 1" /proc/gpufreq/gpufreq_limit_table; done
        
        [ -f "/proc/gpufreq/gpufreq_power_limited" ] && {
            for setting in ignore_batt_oc ignore_batt_percent ignore_low_batt ignore_thermal_protect ignore_pbm_limited; do
                tweak "$setting 0" /proc/gpufreq/gpufreq_power_limited
            done
        }
        
        tweak "stop 0" /proc/mtk_batoc_throttling/battery_oc_protect_stop
        kakangkuh -1 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
        kakangkuh -1 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
        devfreq_unlock /sys/class/devfreq/mtk-dvfsrc-devfreq
        tweak 1 /sys/kernel/eara_thermal/enable
        mtkvest_normal
    } &
}

snapdragon_normal() {
    {
        if [ "$DEVICE_MITIGATION" -eq 0 ]; then
            for path in /sys/class/devfreq/*{cpu*-lat,cpu*-bw,llccbw*,bus_llcc*,bus_ddr*,memlat*,cpubw*,kgsl-ddr-qos*}; do
                devfreq_unlock "$path"
            done
            for component in DDR LLCC L3; do
                qcom_cpudcvs_unlock /sys/devices/system/cpu/bus_dcvs/$component
            done
        fi
        devfreq_unlock /sys/class/kgsl/kgsl-3d0/devfreq
        tweak 1 /sys/class/kgsl/kgsl-3d0/bus_split
        tweak 0 /sys/class/kgsl/kgsl-3d0/force_clk_on
    } &
}

tegra_normal() {
    gpu_path="/sys/kernel/tegra_gpu"
    [ -d "$gpu_path" ] && {
        max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
        min_freq=$(which_minfreq "$gpu_path/available_frequencies")
        kakangkuh "$max_freq" "$gpu_path/gpu_cap_rate"
        kakangkuh "$min_freq" "$gpu_path/gpu_floor_rate"
    } &
}

exynos_normal() {
    {
        gpu_path="/sys/kernel/gpu"
        [ -d "$gpu_path" ] && {
            max_freq=$(which_maxfreq "$gpu_path/gpu_available_frequencies")
            min_freq=$(which_minfreq "$gpu_path/available_frequencies")
            kakangkuh "$max_freq" "$gpu_path/gpu_max_clock"
            kakangkuh "$min_freq" "$gpu_path/gpu_min_clock"
        }
        
        mali_sysfs=$(find /sys/devices/platform/ -iname "*.mali" -print -quit 2>/dev/null)
        tweak coarse_demand "$mali_sysfs/power_policy"
        
        [ "$DEVICE_MITIGATION" -eq 0 ] && for path in /sys/class/devfreq/*devfreq_mif*; do devfreq_unlock "$path"; done
    } &
}

unisoc_normal() {
    gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && devfreq_unlock "$gpu_path" &
}

tensor_normal() {
    {
        gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
        [ -n "$gpu_path" ] && {
            max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
            min_freq=$(which_minfreq "$gpu_path/available_frequencies")
            kakangkuh "$max_freq" "$gpu_path/scaling_max_freq"
            kakangkuh "$min_freq" "$gpu_path/scaling_min_freq"
        }
        [ "$DEVICE_MITIGATION" -eq 0 ] && for path in /sys/class/devfreq/*devfreq_mif*; do devfreq_unlock "$path"; done
    } &
}

mediatek_powersave() {
    {
        tweak 1 /proc/cpufreq/cpufreq_power_mode
        if [ -d /proc/gpufreqv2 ]; then
            min_gpufreq_index=$(mtk_gpufreq_minfreq_index /proc/gpufreqv2/gpu_working_opp_table)
            tweak "$min_gpufreq_index" /proc/gpufreqv2/fix_target_opp_index
        else
            gpu_freq=$(sed -n 's/.*freq = \([0-9]\{1,\}\).*/\1/p' /proc/gpufreq/gpufreq_opp_dump | tail -n 1)
            tweak "$gpu_freq" /proc/gpufreq/gpufreq_opp_freq
        fi
    } &
}

snapdragon_powersave() {
    devfreq_min_perf /sys/class/kgsl/kgsl-3d0/devfreq &
}

tegra_powersave() {
    gpu_path="/sys/kernel/tegra_gpu"
    [ -d "$gpu_path" ] && {
        freq=$(which_minfreq "$gpu_path/available_frequencies")
        tweak "$freq" "$gpu_path/gpu_floor_rate"
        tweak "$freq" "$gpu_path/gpu_cap_rate"
    } &
}

exynos_powersave() {
    gpu_path="/sys/kernel/gpu"
    [ -d "$gpu_path" ] && {
        freq=$(which_minfreq "$gpu_path/gpu_available_frequencies")
        tweak "$freq" "$gpu_path/gpu_min_clock"
        tweak "$freq" "$gpu_path/gpu_max_clock"
    } &
}

unisoc_powersave() {
    gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && devfreq_min_perf "$gpu_path" &
}

tensor_powersave() {
    gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        freq=$(which_minfreq "$gpu_path/available_frequencies")
        tweak "$freq" "$gpu_path/scaling_min_freq"
        tweak "$freq" "$gpu_path/scaling_max_freq"
    } &
}

##################################
# Performance Profile (1)
##################################
performance_basic() {
    {
        sync
        for dir in /sys/block/*; do
            tweak 0 "$dir/queue/iostats"
            tweak 0 "$dir/queue/add_random"
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
        tweak 0 /proc/sys/kernel/split_lock_mitigate
        tweak 80 /proc/sys/vm/vfs_cache_pressure
        
        for dir in /sys/class/thermal/thermal_zone*; do
            tweak "step_wise" "$dir/policy"
        done
        
        [ -f /sys/module/battery_saver/parameters/enabled ] && {
            grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled && tweak 0 /sys/module/battery_saver/parameters/enabled || tweak N /sys/module/battery_saver/parameters/enabled
        }
        
        [ -f "/sys/kernel/debug/sched_features" ] && {
            tweak NEXT_BUDDY /sys/kernel/debug/sched_features
            tweak NO_TTWU_QUEUE /sys/kernel/debug/sched_features
        }
        
        [ -d "/dev/stune/" ] && {
            tweak 1 /dev/stune/top-app/schedtune.prefer_idle
            tweak 1 /dev/stune/top-app/schedtune.boost
        }
        
        tp_path="/proc/touchpanel"
        [ -d "$tp_path" ] && {
            tweak 1 $tp_path/game_switch_enable
            tweak 0 $tp_path/oplus_tp_limit_enable
            tweak 0 $tp_path/oppo_tp_limit_enable
            tweak 1 $tp_path/oplus_tp_direction
            tweak 1 $tp_path/oppo_tp_direction
        }
        
        for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
            [ -d "$path" ] && {
                [ "$LITE_MODE" -eq 1 ] && devfreq_mid_perf "$path" || devfreq_max_perf "$path"
            }
        done
        
        [ "$LITE_MODE" -eq 0 ] && [ "$DEVICE_MITIGATION" -eq 0 ] && change_cpu_gov "performance" || change_cpu_gov "$DEFAULT_CPU_GOV"
        
        [ -d "/proc/ppm" ] && cpufreq_ppm_max_perf
        cpufreq_max_perf
        
        for dir in /sys/block/mmcblk0 /sys/block/mmcblk1 /sys/block/sd*; do
            tweak 32 "$dir/queue/read_ahead_kb"
            tweak 32 "$dir/queue/nr_requests"
        done
    } &
    
    case $SOC in
        1) mediatek_performance ;;
        2) snapdragon_performance ;;
        3) exynos_performance ;;
        4) unisoc_performance ;;
        5) tensor_performance ;;
        6) tegra_performance ;;
    esac
    
    sh $STAR_PATH/BATTERY_RESTORE.sh &
    sh $STAR_PATH/CPU_DBPerformance.sh &
    dnd_on
    corin_perf &
    bypass_on
    [ "$KCPU_MITIGATE" -eq 0 ] && carcpu_perf &
    anyamelfissa
    wait
}

##########################################
# Balanced Profile (2)
##########################################
balanced_basic() {
    {
        sync
        [ -f /sys/module/battery_saver/parameters/enabled ] && {
            grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled && kakangkuh 0 /sys/module/battery_saver/parameters/enabled || kakangkuh N /sys/module/battery_saver/parameters/enabled
        }
        
        kakangkuh 1 /proc/sys/kernel/split_lock_mitigate
        
        [ -f "/sys/kernel/debug/sched_features" ] && {
            kakangkuh NEXT_BUDDY /sys/kernel/debug/sched_features
            kakangkuh TTWU_QUEUE /sys/kernel/debug/sched_features
        }
        
        [ -d "/dev/stune/" ] && {
            kakangkuh 0 /dev/stune/top-app/schedtune.prefer_idle
            kakangkuh 1 /dev/stune/top-app/schedtune.boost
        }
        
        tp_path="/proc/touchpanel"
        [ -d "$tp_path" ] && {
            kakangkuh 0 $tp_path/game_switch_enable
            kakangkuh 1 $tp_path/oplus_tp_limit_enable
            kakangkuh 1 $tp_path/oppo_tp_limit_enable
            kakangkuh 0 $tp_path/oplus_tp_direction
            kakangkuh 0 $tp_path/oppo_tp_direction
        }
        
        kakangkuh 120 /proc/sys/vm/vfs_cache_pressure
        
        for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
            devfreq_unlock "$path"
        done
        
        change_cpu_gov "$DEFAULT_CPU_GOV"
        
        if [ -d "/proc/ppm" ]; then
            [ "$LIFE_MODE" -eq 1 ] && cpufreq_ppm_life_perf || cpufreq_ppm_unlock
        fi
        
        [ "$LIFE_MODE" -eq 1 ] && cpufreq_life_perf || cpufreq_unlock
    } &
    
    case $SOC in
        1) mediatek_normal ;;
        2) snapdragon_normal ;;
        3) exynos_normal ;;
        4) unisoc_normal ;;
        5) tensor_normal ;;
        6) tegra_normal ;;
    esac
    
    sh $STAR_PATH/BATTERY_RESTORE.sh &
    sh $STAR_PATH/CPU_DBBalance.sh &
    dnd_off
    corin_balanced &
    bypass_off
    [ "$KCPU_MITIGATE" -eq 0 ] && carcpu_balance &
    anyakawaii
    wait
}

##########################################
# Powersave Profile (3)
##########################################
powersave_basic() {
    {
        sync
        balanced_basic
        
        [ -f /sys/module/battery_saver/parameters/enabled ] && {
            grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled && tweak 1 /sys/module/battery_saver/parameters/enabled || tweak Y /sys/module/battery_saver/parameters/enabled
        }
        
        for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
            devfreq_min_perf "$path"
        done
        
        change_cpu_gov "powersave"
        [ -d "/proc/ppm" ] && cpufreq_ppm_min_perf
        cpufreq_min_perf
    } &
    
    case $SOC in
        1) mediatek_powersave ;;
        2) snapdragon_powersave ;;
        3) exynos_powersave ;;
        4) unisoc_powersave ;;
        5) tensor_powersave ;;
        6) tegra_powersave ;;
    esac
    
    sh $STAR_PATH/BATTERY_SAVER.sh &
    dnd_off
    corin_powersave &
    bypass_off
    [ "$KCPU_MITIGATE" -eq 0 ] && carcpu_battery &
    anyakawaii
    wait
}

##########################################
# MAIN EXECUTION LOGIC
##########################################

[ -z "$1" ] && {
    echo "Usage: $0 <mode>"
    echo "  1: Performance"
    echo "  2: Balanced"
    echo "  3: Powersave"
    echo "  4: Gaming Pro"
    echo "  5: Cool Down"
    echo "  6: Clear All"
    exit 1
}

MODE=$1

case $MODE in
    1)
        performance_basic
        notification "Performance Mode Activated 🔥"
        ;;
    2)
        balanced_basic
        notification "Balanced Mode Activated ⚖️"
        ;;
    3)
        powersave_basic
        notification "Powersave Mode Activated 🔋"
        ;;
    4)
        performance_basic
        kill_all
        notification "Gaming Pro Mode Activated 🚀"
        ;;
    5)
        powersave_basic
        notification "Cool Down initiated for 2 minutes... ❄️"
        sleep 120
        balanced_basic
        notification "Cool Down finished. Switched to Balanced Mode."
        ;;
    6)
        kill_all
        notification "All background applications cleared. ✅"
        ;;
    *)
        echo "Error: Invalid mode '$MODE'. Please use 1, 2, 3, 4, 5, or 6."
        exit 1
        ;;
esac

exit 0