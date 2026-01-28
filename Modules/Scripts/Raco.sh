#!/system/bin/sh
###############################
# DEFINE CONFIG
###############################

# Config file path
RACO_CONFIG="/data/ProjectRaco/raco.txt"

# Format: 1=MTK, 2=SD, 3=Exynos, 4=Unisoc, 5=Tensor, 6=Tegra, 7=Kirin
SOC=$(grep '^SOC=' "$RACO_CONFIG" | cut -d'=' -f2)
LITE_MODE=$(grep '^LITE_MODE=' "$RACO_CONFIG" | cut -d'=' -f2)
BETTER_POWERAVE=$(grep '^BETTER_POWERAVE=' "$RACO_CONFIG" | cut -d'=' -f2)
ANYA=$(grep '^ANYA=' "$RACO_CONFIG" | cut -d'=' -f2)
INCLUDE_ANYA=$(grep '^INCLUDE_ANYA=' "$RACO_CONFIG" | cut -d'=' -f2)
KCPU_MITIGATE=$(grep '^KCPU_MITIGATE=' "$RACO_CONFIG" | cut -d'=' -f2)
LEGACY_NOTIF=$(grep '^LEGACY_NOTIF=' "$RACO_CONFIG" | cut -d'=' -f2)

DEFAULT_CPU_GOV=$(grep '^GOV=' "$RACO_CONFIG" | cut -d'=' -f2)
if [ -z "$DEFAULT_CPU_GOV" ]; then
    if [ -e /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors ] && grep -q "schedhorizon" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors; then
        DEFAULT_CPU_GOV="schedhorizon"
    else
        DEFAULT_CPU_GOV="schedutil"
    fi
fi

DEVICE_MITIGATION=$(grep '^DEVICE_MITIGATION=' "$RACO_CONFIG" | cut -d'=' -f2)
DND=$(grep '^DND=' "$RACO_CONFIG" | cut -d'=' -f2)

##############################
# Path Variable
##############################
ipv4="/proc/sys/net/ipv4"

##############################
# ADDED: Source External Script
##############################
SCRIPT_PATH="/data/adb/modules/ProjectRaco/Scripts"
MODULE_PATH="/data/adb/modules/ProjectRaco"
source "$MODULE_PATH/Scripts/corin.sh"

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
    if [ "$INCLUDE_ANYA" = "1" ] && [ "$ANYA" = "1" ]; then
        sh /data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh &
    fi
}

anyakawaii() {
    if [ "$INCLUDE_ANYA" = "1" ] && [ "$ANYA" = "1" ]; then
        sh /data/adb/modules/ProjectRaco/Scripts/AnyaKawaii.sh &
    fi
}

tweak() {
    if [ -e "$2" ]; then
        chmod 644 "$2" >/dev/null 2>&1
        echo "$1" > "$2" 2>/dev/null
        chmod 444 "$2" >/dev/null 2>&1
    fi
}

kakangkuh() {
    [ ! -f "$2" ] && return 1
    chmod 644 "$2" >/dev/null 2>&1
    echo "$1" >"$2" 2>/dev/null
}

kill_all() {
    sync
    cmd activity kill-all > /dev/null 2>&1
    for pkg in $(pm list packages -3 | cut -f 2 -d ":"); do
        if [ "$pkg" != "com.google.android.inputmethod.latin" ]; then 
            am force-stop "$pkg" > /dev/null 2>&1 &
        fi
    done
    wait

    pm trim-caches 100G > /dev/null 2>&1
    echo 3 > /proc/sys/vm/drop_caches
    logcat -c
    logcat -b all -c
    star_kill &
}

bypass_on() {
    BYPASS=$(grep "^ENABLE_BYPASS=" "$RACO_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    if [ "$BYPASS" = "1" ]; then
        sh $SCRIPT_PATH/raco_bypass_controller.sh enable &
    fi
}

bypass_off() {
    sh $SCRIPT_PATH/raco_bypass_controller.sh disable &
}

notification() {
    local TITLE="Project Raco"
    local MESSAGE="$1"
    local LOGO="/data/local/tmp/logo.png"
    
    if [ "$LEGACY_NOTIF" = "1" ]; then
        su -lp 2000 -c "cmd notification post -S bigtext -t '$TITLE' TagRaco '$MESSAGE'" &
    else
        su -lp 2000 -c "cmd notification post -S bigtext -t '$TITLE' -i file://$LOGO -I file://$LOGO TagRaco '$MESSAGE'" &
    fi
}

dnd_off() {
    DND_VAL=$(grep "^DND=" "$RACO_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    if [ "$DND_VAL" = "1" ]; then
        cmd notification set_dnd off &
    fi
}

dnd_on() {
    DND_VAL=$(grep "^DND=" "$RACO_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    if [ "$DND_VAL" = "1" ]; then
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

###################################
# MTKVest Functions 
###################################

mtkvest_perf() {
    (
        tweak 1 /proc/perfmgr/syslimiter/syslimiter_force_disable
        tweak 100 /sys/kernel/ged/hal/gpu_boost_level
    ) &

    if [ -d /sys/kernel/ged/hal ]; then
        (
            tweak 2 /sys/kernel/ged/hal/loading_base_dvfs_step
            tweak 1 /sys/kernel/ged/hal/loading_stride_size
            tweak 16 /sys/kernel/ged/hal/loading_window_size
        ) &
    fi
}

mtkvest_normal() {
    (
        tweak 0 /proc/perfmgr/syslimiter/syslimiter_force_disable
        tweak -1 /sys/kernel/ged/hal/gpu_boost_level
    ) &

    if [ -d /sys/kernel/ged/hal ]; then
        (
            tweak 4 /sys/kernel/ged/hal/loading_base_dvfs_step
            tweak 2 /sys/kernel/ged/hal/loading_stride_size
            tweak 8 /sys/kernel/ged/hal/loading_window_size
        ) &
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

mtk_gpufreq_minfreq_index() {
    awk -F'[][]' '{print $2}' "$1" | tail -n 1
}

mtk_gpufreq_midfreq_index() {
    total_opp=$(wc -l <"$1")
    mid_opp=$(((total_opp + 1) / 2))
    awk -F'[][]' '{print $2}' "$1" | head -n $mid_opp | tail -n 1
}

devfreq_max_perf() {
    [ ! -f "$1/available_frequencies" ] && return 1
    max_freq=$(which_maxfreq "$1/available_frequencies")
    tweak "$max_freq" "$1/max_freq"
    tweak "$max_freq" "$1/min_freq"
}

devfreq_mid_perf() {
    [ ! -f "$1/available_frequencies" ] && return 1
    max_freq=$(which_maxfreq "$1/available_frequencies")
    mid_freq=$(which_midfreq "$1/available_frequencies")
    tweak "$max_freq" "$1/max_freq"
    tweak "$mid_freq" "$1/min_freq"
}

devfreq_unlock() {
    [ ! -f "$1/available_frequencies" ] && return 1
    max_freq=$(which_maxfreq "$1/available_frequencies")
    min_freq=$(which_minfreq "$1/available_frequencies")
    kakangkuh "$max_freq" "$1/max_freq"
    kakangkuh "$min_freq" "$1/min_freq"
}

devfreq_min_perf() {
    [ ! -f "$1/available_frequencies" ] && return 1
    freq=$(which_minfreq "$1/available_frequencies")
    tweak "$freq" "$1/min_freq"
    tweak "$freq" "$1/max_freq"
}

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
    chmod 644 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null
    echo "$1" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>/dev/null
    chmod 444 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null
    chmod 444 /sys/devices/system/cpu/cpufreq/policy*/scaling_governor 2>/dev/null
}

###################################
# CPUFreq Frequency Tweaks
###################################

cpufreq_ppm_max_perf() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        (
            local cpu_maxfreq=$(<"$path/cpuinfo_max_freq")

            tweak "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq

            if [ "$LITE_MODE" -eq 1 ]; then
                local cpu_midfreq=$(which_midfreq "$path/scaling_available_frequencies")
                tweak "$cluster $cpu_midfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
            else
                tweak "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
            fi
        ) &
        ((cluster++))
    done
}

cpufreq_max_perf() {
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        (
            if [ -w "$path/scaling_max_freq" ] || chmod 644 "$path/scaling_max_freq" "$path/scaling_min_freq" 2>/dev/null; then
                local cpu_maxfreq=$(cat "$path/cpuinfo_max_freq")
                local cpu_midfreq=$(which_midfreq "$path/scaling_available_frequencies")
                
                echo "$cpu_maxfreq" > "$path/scaling_max_freq" 2>/dev/null
                
                if [ -n "$cpu_midfreq" ]; then
                    echo "$cpu_midfreq" > "$path/scaling_min_freq" 2>/dev/null
                fi
                
                if [ "$LITE_MODE" -ne 1 ]; then
                     echo "$cpu_maxfreq" > "$path/scaling_min_freq" 2>/dev/null
                fi

                chmod 444 "$path/scaling_max_freq" "$path/scaling_min_freq" 2>/dev/null
            fi
        ) &
    done
    wait
}

cpufreq_ppm_unlock() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        (
            local cpu_maxfreq=$(<"$path/cpuinfo_max_freq")
            local cpu_minfreq=$(<"$path/cpuinfo_min_freq")
            
            kakangkuh "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
            kakangkuh "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        ) &
        ((cluster++))
    done
}

cpufreq_unlock() {
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        (
            if [ -d "$path" ]; then
                chmod 644 "$path/scaling_max_freq" "$path/scaling_min_freq" 2>/dev/null
                
                local cpu_maxfreq=$(cat "$path/cpuinfo_max_freq")
                local cpu_minfreq=$(cat "$path/cpuinfo_min_freq")
                
                echo "$cpu_maxfreq" > "$path/scaling_max_freq" 2>/dev/null
                echo "$cpu_minfreq" > "$path/scaling_min_freq" 2>/dev/null
                
                chmod 644 "$path/scaling_max_freq" "$path/scaling_min_freq" 2>/dev/null
            fi
        ) &
    done
    wait
}

cpufreq_ppm_min_perf() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        (
            local cpu_minfreq=$(<"$path/cpuinfo_min_freq")

            if [ "$BETTER_POWERAVE" -eq 1 ]; then
                local cpu_midfreq=$(which_midfreq "$path/scaling_available_frequencies")
                tweak "$cluster $cpu_midfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
                tweak "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
            else
                tweak "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
                tweak "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
            fi
        ) &
        ((cluster++))
    done
}

cpufreq_min_perf() {
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        (
            if [ -w "$path/scaling_max_freq" ] || chmod 644 "$path/scaling_max_freq" "$path/scaling_min_freq" 2>/dev/null; then
                local cpu_minfreq=$(cat "$path/cpuinfo_min_freq")
                
                echo "$cpu_minfreq" > "$path/scaling_min_freq" 2>/dev/null
                
                if [ "$BETTER_POWERAVE" -eq 1 ]; then
                    local cpu_midfreq=$(which_midfreq "$path/scaling_available_frequencies")
                    echo "$cpu_midfreq" > "$path/scaling_max_freq" 2>/dev/null
                else
                    echo "$cpu_minfreq" > "$path/scaling_max_freq" 2>/dev/null
                fi

                chmod 444 "$path/scaling_max_freq" "$path/scaling_min_freq" 2>/dev/null
            fi
        ) &
    done
    wait
}

###################################
# Device Profiles
###################################

mediatek_performance() {
    (
        tweak 1 /proc/cpufreq/cpufreq_cci_mode
        tweak 3 /proc/cpufreq/cpufreq_power_mode
        tweak 0 /sys/kernel/fpsgo/common/force_onoff
        tweak 1 /sys/devices/platform/boot_dramboost/dramboost/dramboost
        tweak 0 /sys/devices/system/cpu/eas/enable
        tweak 0 /sys/module/sspm_v3/holders/ged/parameters/is_GED_KPI_enabled
        tweak 0 /sys/kernel/eara_thermal/enable
    ) &

    (
        if [ "$LITE_MODE" -eq 0 ]; then
            if [ -d /proc/gpufreqv2 ]; then
                tweak 0 /proc/gpufreqv2/fix_target_opp_index
            else
                local gpu_freq=$(sed -n 's/.*freq = \([0-9]\{1,\}\).*/\1/p' /proc/gpufreq/gpufreq_opp_dump | head -n 1)
                tweak "$gpu_freq" /proc/gpufreq/gpufreq_opp_freq
            fi
        else
            tweak 0 /proc/gpufreq/gpufreq_opp_freq
            tweak -1 /proc/gpufreqv2/fix_target_opp_index
            local mid_oppfreq
            if [ -d /proc/gpufreqv2 ]; then
                mid_oppfreq=$(mtk_gpufreq_midfreq_index /proc/gpufreqv2/gpu_working_opp_table)
            else
                mid_oppfreq=$(mtk_gpufreq_midfreq_index /proc/gpufreq/gpufreq_opp_dump)
            fi
            tweak "$mid_oppfreq" /sys/kernel/ged/hal/custom_boost_gpu_freq
        fi
    ) &

    [ -f "/proc/gpufreq/gpufreq_power_limited" ] && {
        for setting in ignore_batt_oc ignore_batt_percent ignore_low_batt ignore_thermal_protect ignore_pbm_limited; do
            tweak "$setting 1" /proc/gpufreq/gpufreq_power_limited &
        done
        wait
    } &

    (
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
    ) &

    mtkvest_perf
    wait
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
        done &

        for component in DDR LLCC L3; do
            local path="/sys/devices/system/cpu/bus_dcvs/$component"
            if [ "$LITE_MODE" -eq 1 ]; then
                qcom_cpudcvs_mid_perf "$path"
            else
                qcom_cpudcvs_max_perf "$path"
            fi
        done &
    fi

    (
        local gpu_path="/sys/class/kgsl/kgsl-3d0/devfreq"
        if [ "$LITE_MODE" -eq 0 ]; then
            devfreq_max_perf "$gpu_path"
        else
            devfreq_mid_perf "$gpu_path"
        fi
        tweak 0 /sys/class/kgsl/kgsl-3d0/bus_split
        tweak 1 /sys/class/kgsl/kgsl-3d0/force_clk_on
    ) &
    wait
}

exynos_performance() {
    (
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
    ) &

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            if [ "$LITE_MODE" -eq 1 ]; then
                devfreq_mid_perf "$path"
            else
                devfreq_max_perf "$path"
            fi
        done &
    fi
    wait
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
    } &

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            if [ "$LITE_MODE" -eq 1 ]; then
                devfreq_mid_perf "$path"
            else
                devfreq_max_perf "$path"
            fi
        done &
    fi
    wait
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

###################################
# Normal Profiles
###################################

mediatek_normal() {
    (
        tweak 2 /sys/kernel/fpsgo/common/force_onoff
        tweak 0 /proc/cpufreq/cpufreq_cci_mode
        tweak 0 /proc/cpufreq/cpufreq_power_mode
        tweak 0 /sys/devices/platform/boot_dramboost/dramboost/dramboost
        tweak 2 /sys/devices/system/cpu/eas/enable
        tweak 1 /sys/module/sspm_v3/holders/ged/parameters/is_GED_KPI_enabled
    ) &

    (
        kakangkuh 0 /proc/gpufreq/gpufreq_opp_freq
        kakangkuh -1 /proc/gpufreqv2/fix_target_opp_index

        if [ -d /proc/gpufreqv2 ]; then
            local min_oppfreq=$(mtk_gpufreq_minfreq_index /proc/gpufreqv2/gpu_working_opp_table)
        else
            local min_oppfreq=$(mtk_gpufreq_minfreq_index /proc/gpufreq/gpufreq_opp_dump)
        fi
        tweak "$min_oppfreq" /sys/kernel/ged/hal/custom_boost_gpu_freq
    ) &

    if [[ -f "/proc/gpufreq/gpufreq_limit_table" ]]; then
        for id in {0..8}; do
            tweak "$id 1 1" /proc/gpufreq/gpufreq_limit_table &
        done
        wait
    fi &

    [ -f "/proc/gpufreq/gpufreq_power_limited" ] && {
        for setting in ignore_batt_oc ignore_batt_percent ignore_low_batt ignore_thermal_protect ignore_pbm_limited; do
            tweak "$setting 0" /proc/gpufreq/gpufreq_power_limited &
        done
        wait
    } &

    (
        tweak "stop 0" /proc/mtk_batoc_throttling/battery_oc_protect_stop
        kakangkuh -1 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
        kakangkuh -1 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
        devfreq_unlock /sys/class/devfreq/mtk-dvfsrc-devfreq
        tweak 1 /sys/kernel/eara_thermal/enable
    ) &

    mtkvest_normal
    wait
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
            devfreq_unlock "$path" &
        done

        for component in DDR LLCC L3; do
            qcom_cpudcvs_unlock /sys/devices/system/cpu/bus_dcvs/$component &
        done
        wait
    fi

    devfreq_unlock /sys/class/kgsl/kgsl-3d0/devfreq &
    tweak 1 /sys/class/kgsl/kgsl-3d0/bus_split &
    tweak 0 /sys/class/kgsl/kgsl-3d0/force_clk_on &
    wait
}

exynos_normal() {
    (
        local gpu_path="/sys/kernel/gpu"
        if [ -d "$gpu_path" ]; then
            local max_freq=$(which_maxfreq "$gpu_path/gpu_available_frequencies")
            local min_freq=$(which_minfreq "$gpu_path/available_frequencies")
            kakangkuh "$max_freq" "$gpu_path/gpu_max_clock"
            kakangkuh "$min_freq" "$gpu_path/gpu_min_clock"
        fi
        local mali_sysfs=$(find /sys/devices/platform/ -iname "*.mali" -print -quit 2>/dev/null)
        tweak coarse_demand "$mali_sysfs/power_policy"
    ) &

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            devfreq_unlock "$path" &
        done
        wait
    fi
    wait
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
    } &

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            devfreq_unlock "$path" &
        done
        wait
    fi
    wait
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

###################################
# Powersave Profiles
###################################

mediatek_powersave() {
    tweak 1 /proc/cpufreq/cpufreq_power_mode
    if [ -d /proc/gpufreqv2 ]; then
        local min_gpufreq_index=$(mtk_gpufreq_minfreq_index /proc/gpufreqv2/gpu_working_opp_table)
        tweak "$min_gpufreq_index" /proc/gpufreqv2/fix_target_opp_index
    else
        local gpu_freq=$(sed -n 's/.*freq = \([0-9]\{1,\}\).*/\1/p' /proc/gpufreq/gpufreq_opp_dump | tail -n 1)
        tweak "$gpu_freq" /proc/gpufreq/gpufreq_opp_freq
    fi
}

snapdragon_powersave() {
    devfreq_min_perf /sys/class/kgsl/kgsl-3d0/devfreq
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
    
    (
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
                (
                    if [ "$LITE_MODE" -eq 1 ]; then
                        devfreq_mid_perf "$path"
                    else
                        devfreq_max_perf "$path"
                    fi
                ) &
            fi
        done

        for dir in /sys/block/mmcblk0 /sys/block/mmcblk1 /sys/block/sd*; do
            tweak 32 "$dir/queue/read_ahead_kb"
            tweak 32 "$dir/queue/nr_requests"
        done
    ) &

    {
        change_cpu_gov "performance"
        sleep 2
        
        if [ -d "/proc/ppm" ]; then
            cpufreq_ppm_max_perf
        fi
        cpufreq_max_perf
    } &
    
    wait 

    case $SOC in
        1) mediatek_performance ;;
        2) snapdragon_performance ;;
        3) exynos_performance ;;
        4) unisoc_performance ;;
        5) tensor_performance ;;
        6) tegra_performance ;;
    esac
    wait

    dnd_on &
    corin_perf &
    bypass_on &
    clear_slingshot &

    if [ "$KCPU_MITIGATE" -eq 0 ]; then
        carcpu_perf &
    fi

    anyamelfissa &
    wait
}

##########################################
# Balanced Profile (2)
##########################################
balanced_basic() {
    sync
    performance_basic 
    wait

    (
        if [ -f /sys/module/battery_saver/parameters/enabled ]; then
            if grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled; then
                kakangkuh 0 /sys/module/battery_saver/parameters/enabled
            else
                kakangkuh N /sys/module/battery_saver/parameters/enabled
            fi
        fi

        kakangkuh 500000 /proc/sys/kernel/sched_migration_cost_ns
        kakangkuh 3000000 /proc/sys/kernel/sched_min_granularity_ns
        kakangkuh 4000000 /proc/sys/kernel/sched_wakeup_granularity_ns
        kakangkuh 0 /proc/sys/net/ipv4/tcp_low_latency
        kakangkuh 1 /proc/sys/vm/stat_interval
        kakangkuh 3 /proc/sys/vm/page-cluster

        kakangkuh 1 /proc/sys/kernel/split_lock_mitigate
        kakangkuh 120 /proc/sys/vm/vfs_cache_pressure

        if [ -f "/sys/kernel/debug/sched_features" ]; then
            kakangkuh NEXT_BUDDY /sys/kernel/debug/sched_features
            kakangkuh TTWU_QUEUE /sys/kernel/debug/sched_features
        fi

        if [ -d "/dev/stune/" ]; then
            kakangkuh 0 /dev/stune/top-app/schedtune.prefer_idle
            kakangkuh 1 /dev/stune/top-app/schedtune.boost
        fi

        tp_path="/proc/touchpanel"
        if [ -d "$tp_path" ]; then
            kakangkuh 0 $tp_path/game_switch_enable
            kakangkuh 1 $tp_path/oplus_tp_limit_enable
            kakangkuh 1 $tp_path/oppo_tp_limit_enable
            kakangkuh 0 $tp_path/oplus_tp_direction
            kakangkuh 0 $tp_path/oppo_tp_direction
        fi

        for dir in /sys/block/mmcblk0 /sys/block/mmcblk1 /sys/block/sd*; do
            kakangkuh 128 "$dir/queue/read_ahead_kb"
            kakangkuh 128 "$dir/queue/nr_requests"
        done

        for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
             devfreq_unlock "$path" &
        done
    ) &

    {
        if [ -d "/proc/ppm" ]; then
            cpufreq_ppm_unlock
        fi
        cpufreq_unlock
        
        change_cpu_gov "$DEFAULT_CPU_GOV"
    } &
    
    wait 

    case $SOC in
        1) mediatek_normal ;;
        2) snapdragon_normal ;;
        3) exynos_normal ;;
        4) unisoc_normal ;;
        5) tensor_normal ;;
        6) tegra_normal ;;
    esac
    wait
    
    dnd_off &
    corin_balanced &
    bypass_off &
    clear_slingshot &

    if [ "$KCPU_MITIGATE" -eq 0 ]; then
        carcpu_balance &
    fi

    anyakawaii &
    wait
}

##########################################
# Powersave Profile (3)
##########################################
powersave_basic() {
    sync
    
    (
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
            devfreq_min_perf "$path" &
        done
    ) &

    {
        change_cpu_gov "powersave"
        sleep 2
        
        if [ -d "/proc/ppm" ]; then
            cpufreq_ppm_min_perf
        fi
        cpufreq_min_perf
    } &

    wait

    case $SOC in
        1) mediatek_powersave ;;
        2) snapdragon_powersave ;;
        3) exynos_powersave ;;
        4) unisoc_powersave ;;
        5) tensor_powersave ;;
        6) tegra_powersave ;;
    esac
    wait

    dnd_off &
    corin_powersave &
    bypass_off &
    clear_slingshot &

    if [ "$KCPU_MITIGATE" -eq 0 ]; then
        carcpu_battery &
    fi

    anyakawaii &
    wait
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