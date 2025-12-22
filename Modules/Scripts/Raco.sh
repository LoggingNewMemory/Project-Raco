#!/system/bin/sh

RACO_CONFIG="/data/ProjectRaco/raco.txt"

eval $(awk -F= '/^[^#\[]/ && /=/ {gsub(/ /, "", $2); print $1"=\""$2"\""}' "$RACO_CONFIG")

W() {
    [ -e "$2" ] || return
    echo "$1" > "$2" 2>/dev/null || { chmod 644 "$2"; echo "$1" > "$2"; chmod 444 "$2"; }
}

SCRIPT_PATH="/data/adb/modules/ProjectRaco/Scripts"
STAR_PATH="$SCRIPT_PATH/STAR"
MODULE_PATH="/data/adb/modules/ProjectRaco"
[ -f "$MODULE_PATH/Scripts/corin.sh" ] && . "$MODULE_PATH/Scripts/corin.sh"

if [ "$KCPU_MITIGATE" -eq 0 ] && [ -f "$SCRIPT_PATH/CarlottaCPU.sh" ]; then
    . "$SCRIPT_PATH/CarlottaCPU.sh"
fi

if [ -z "$GOV" ]; then
    if grep -q "schedhorizon" /sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors 2>/dev/null; then
        DEFAULT_CPU_GOV="schedhorizon"
    else
        DEFAULT_CPU_GOV="schedutil"
    fi
else
    DEFAULT_CPU_GOV="$GOV"
fi

ipv4="/proc/sys/net/ipv4"

anyamelfissa() {
    [ "$INCLUDE_ANYA" = "1" ] && [ "$ANYA" = "1" ] && sh /data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh &
}

anyakawaii() {
    [ "$INCLUDE_ANYA" = "1" ] && [ "$ANYA" = "1" ] && sh /data/adb/modules/ProjectRaco/Scripts/AnyaKawaii.sh &
}

kill_all() {
    sync
    cmd activity kill-all >/dev/null 2>&1
    pm list packages -3 | cut -f 2 -d ":" | while read pkg; do
        [ "$pkg" != "com.google.android.inputmethod.latin" ] && am force-stop "$pkg" >/dev/null 2>&1 &
    done
    wait
    pm trim-caches 100G >/dev/null 2>&1
    echo 3 > /proc/sys/vm/drop_caches
    logcat -c
    logcat -b all -c
    sh $STAR_PATH/KILL.sh &
}

bypass_on() {
    [ "$ENABLE_BYPASS" = "Yes" ] && sh $SCRIPT_PATH/raco_bypass_controller.sh enable &
}

bypass_off() {
    [ "$ENABLE_BYPASS" = "Yes" ] && sh $SCRIPT_PATH/raco_bypass_controller.sh disable &
}

notification() {
    local TITLE="Otonose Raco"
    local LOGO="/data/local/tmp/logo.png"
    if [ "$LEGACY_NOTIF" = "1" ]; then
        su -lp 2000 -c "cmd notification post -S bigtext -t '$TITLE' TagRaco '$1'"
    else
        su -lp 2000 -c "cmd notification post -S bigtext -t '$TITLE' -i file://$LOGO -I file://$LOGO TagRaco '$1'"
    fi
}

dnd_off() {
    [ "$DND" = "Yes" ] && cmd notification set_dnd off
}

dnd_on() {
    [ "$DND" = "Yes" ] && cmd notification set_dnd priority
}

mtkvest_perf() {
    W 1 /proc/perfmgr/syslimiter/syslimiter_force_disable
    if [ -d /sys/kernel/ged/hal ]; then
        W 2 /sys/kernel/ged/hal/loading_base_dvfs_step
        W 1 /sys/kernel/ged/hal/loading_stride_size
        W 16 /sys/kernel/ged/hal/loading_window_size
    fi
    W 100 /sys/kernel/ged/hal/gpu_boost_level
}

mtkvest_normal() {
    W 0 /proc/perfmgr/syslimiter/syslimiter_force_disable
    if [ -d /sys/kernel/ged/hal ]; then
        W 4 /sys/kernel/ged/hal/loading_base_dvfs_step
        W 2 /sys/kernel/ged/hal/loading_stride_size
        W 8 /sys/kernel/ged/hal/loading_window_size
    fi
    W -1 /sys/kernel/ged/hal/gpu_boost_level
}

which_maxfreq() {
    tr ' ' '\n' <"$1" | sort -nr | head -n 1
}

which_minfreq() {
    tr ' ' '\n' <"$1" | grep -v '^[[:space:]]*$' | sort -n | head -n 1
}

which_midfreq() {
    local total_opp=$(wc -w <"$1")
    local mid_opp=$(((total_opp + 1) / 2))
    tr ' ' '\n' <"$1" | grep -v '^[[:space:]]*$' | sort -nr | head -n $mid_opp | tail -n 1
}

mtk_gpufreq_minfreq_index() {
    awk -F'[][]' '{print $2}' "$1" | tail -n 1
}

mtk_gpufreq_midfreq_index() {
    local total_opp=$(wc -l <"$1")
    local mid_opp=$(((total_opp + 1) / 2))
    awk -F'[][]' '{print $2}' "$1" | head -n $mid_opp | tail -n 1
}

devfreq_max_perf() {
    [ ! -f "$1/available_frequencies" ] && return 1
    local max_freq=$(which_maxfreq "$1/available_frequencies")
    W "$max_freq" "$1/max_freq"
    W "$max_freq" "$1/min_freq"
}

devfreq_mid_perf() {
    [ ! -f "$1/available_frequencies" ] && return 1
    local max_freq=$(which_maxfreq "$1/available_frequencies")
    local mid_freq=$(which_midfreq "$1/available_frequencies")
    W "$max_freq" "$1/max_freq"
    W "$mid_freq" "$1/min_freq"
}

devfreq_unlock() {
    [ ! -f "$1/available_frequencies" ] && return 1
    local max_freq=$(which_maxfreq "$1/available_frequencies")
    local min_freq=$(which_minfreq "$1/available_frequencies")
    W "$max_freq" "$1/max_freq"
    W "$min_freq" "$1/min_freq"
}

devfreq_min_perf() {
    [ ! -f "$1/available_frequencies" ] && return 1
    local freq=$(which_minfreq "$1/available_frequencies")
    W "$freq" "$1/min_freq"
    W "$freq" "$1/max_freq"
}

qcom_cpudcvs_max_perf() {
    [ ! -f "$1/available_frequencies" ] && return 1
    local freq=$(which_maxfreq "$1/available_frequencies")
    W "$freq" "$1/hw_max_freq"
    W "$freq" "$1/hw_min_freq"
}

qcom_cpudcvs_mid_perf() {
    [ ! -f "$1/available_frequencies" ] && return 1
    local max_freq=$(which_maxfreq "$1/available_frequencies")
    local mid_freq=$(which_midfreq "$1/available_frequencies")
    W "$max_freq" "$1/hw_max_freq"
    W "$mid_freq" "$1/hw_min_freq"
}

qcom_cpudcvs_unlock() {
    [ ! -f "$1/available_frequencies" ] && return 1
    local max_freq=$(which_maxfreq "$1/available_frequencies")
    local min_freq=$(which_minfreq "$1/available_frequencies")
    W "$max_freq" "$1/hw_max_freq"
    W "$min_freq" "$1/hw_min_freq"
}

change_cpu_gov() {
    chmod 644 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    echo "$1" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
    chmod 444 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
    chmod 444 /sys/devices/system/cpu/cpufreq/policy*/scaling_governor
}

cpufreq_ppm_max_perf() {
    local cluster=0
    set -- $CPU_MAX_LIST
    local max_list="$@"
    set -- $CPU_MID_LIST
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local max_f=$(echo "$max_list" | cut -d ' ' -f $((cluster+1)))
        W "$cluster $max_f" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        if [ "$LITE_MODE" -eq 1 ]; then
            W "$cluster $1" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        else
            W "$cluster $max_f" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        fi
        shift
        ((cluster++))
    done
}

cpufreq_max_perf() {
    set -- $CPU_MAX_LIST
    local max_list="$@"
    set -- $CPU_MID_LIST
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local max_f=$(echo "$max_list" | cut -d ' ' -f 1) 
        W "$max_f" "$path/scaling_max_freq"
        if [ "$LITE_MODE" -eq 1 ]; then
            W "$1" "$path/scaling_min_freq"
        else
            W "$max_f" "$path/scaling_min_freq"
        fi
        max_list=$(echo "$max_list" | cut -d ' ' -f 2-)
        shift
    done
    chmod -f 444 /sys/devices/system/cpu/cpufreq/policy*/scaling_*_freq
}

cpufreq_ppm_unlock() {
    local cluster=0
    set -- $CPU_MAX_LIST
    local max_list="$@"
    set -- $CPU_MIN_LIST
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local max_f=$(echo "$max_list" | cut -d ' ' -f $((cluster+1)))
        W "$cluster $max_f" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        W "$cluster $1" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        shift
        ((cluster++))
    done
}

cpufreq_unlock() {
    set -- $CPU_MAX_LIST
    local max_list="$@"
    set -- $CPU_MIN_LIST
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local max_f=$(echo "$max_list" | cut -d ' ' -f 1)
        W "$max_f" "$path/scaling_max_freq"
        W "$1" "$path/scaling_min_freq"
        max_list=$(echo "$max_list" | cut -d ' ' -f 2-)
        shift
    done
    chmod -f 644 /sys/devices/system/cpu/cpufreq/policy*/scaling_*_freq
}

cpufreq_ppm_life_perf() {
    local cluster=0
    set -- $CPU_MID_LIST
    local mid_list="$@"
    set -- $CPU_MIN_LIST
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local mid_f=$(echo "$mid_list" | cut -d ' ' -f $((cluster+1)))
        W "$cluster $mid_f" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        W "$cluster $1" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        shift
        ((cluster++))
    done
}

cpufreq_life_perf() {
    set -- $CPU_MID_LIST
    local mid_list="$@"
    set -- $CPU_MIN_LIST
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local mid_f=$(echo "$mid_list" | cut -d ' ' -f 1)
        W "$mid_f" "$path/scaling_max_freq"
        W "$1" "$path/scaling_min_freq"
        mid_list=$(echo "$mid_list" | cut -d ' ' -f 2-)
        shift
    done
    chmod -f 644 /sys/devices/system/cpu/cpufreq/policy*/scaling_*_freq
}

cpufreq_ppm_min_perf() {
    local cluster=0
    set -- $CPU_MID_LIST
    local mid_list="$@"
    set -- $CPU_MIN_LIST
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local mid_f=$(echo "$mid_list" | cut -d ' ' -f $((cluster+1)))
        if [ "$BETTER_POWERAVE" -eq 1 ]; then
            W "$cluster $mid_f" /proc/ppm/policy/hard_userlimit_max_cpu_freq
            W "$cluster $1" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        else
            W "$cluster $1" /proc/ppm/policy/hard_userlimit_max_cpu_freq
            W "$cluster $1" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        fi
        shift
        ((cluster++))
    done
}

cpufreq_min_perf() {
    set -- $CPU_MID_LIST
    local mid_list="$@"
    set -- $CPU_MIN_LIST
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        local mid_f=$(echo "$mid_list" | cut -d ' ' -f 1)
        if [ "$BETTER_POWERAVE" -eq 1 ]; then
            W "$mid_f" "$path/scaling_max_freq"
            W "$1" "$path/scaling_min_freq"
        else
            W "$1" "$path/scaling_max_freq"
            W "$1" "$path/scaling_min_freq"
        fi
        mid_list=$(echo "$mid_list" | cut -d ' ' -f 2-)
        shift
    done
    chmod -f 444 /sys/devices/system/cpu/cpufreq/policy*/scaling_*_freq
}

mediatek_performance() {
    W 1 /proc/cpufreq/cpufreq_cci_mode
    W 3 /proc/cpufreq/cpufreq_power_mode
    W 0 /sys/kernel/fpsgo/common/force_onoff
    W 1 /sys/devices/platform/boot_dramboost/dramboost/dramboost
    W 0 /sys/devices/system/cpu/eas/enable
    W 0 /sys/module/sspm_v3/holders/ged/parameters/is_GED_KPI_enabled

    if [ "$LITE_MODE" -eq 0 ]; then
        if [ -d /proc/gpufreqv2 ]; then
            W 0 /proc/gpufreqv2/fix_target_opp_index
        else
            local gpu_freq=$(sed -n 's/.*freq = \([0-9]\{1,\}\).*/\1/p' /proc/gpufreq/gpufreq_opp_dump | head -n 1)
            W "$gpu_freq" /proc/gpufreq/gpufreq_opp_freq
        fi
    else
        W 0 /proc/gpufreq/gpufreq_opp_freq
        W -1 /proc/gpufreqv2/fix_target_opp_index
        local mid_oppfreq
        if [ -d /proc/gpufreqv2 ]; then
            mid_oppfreq=$(mtk_gpufreq_midfreq_index /proc/gpufreqv2/gpu_working_opp_table)
        else
            mid_oppfreq=$(mtk_gpufreq_midfreq_index /proc/gpufreq/gpufreq_opp_dump)
        fi
        W "$mid_oppfreq" /sys/kernel/ged/hal/custom_boost_gpu_freq
    fi

    [ -f "/proc/gpufreq/gpufreq_power_limited" ] && {
        for setting in ignore_batt_oc ignore_batt_percent ignore_low_batt ignore_thermal_protect ignore_pbm_limited; do
            W "$setting 1" /proc/gpufreq/gpufreq_power_limited
        done
    }

    W "stop 1" /proc/mtk_batoc_throttling/battery_oc_protect_stop

    if [ "$LITE_MODE" -eq 0 ]; then
        W 0 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
        W 0 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
        devfreq_max_perf /sys/class/devfreq/mtk-dvfsrc-devfreq
    else
        W -1 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
        W -1 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
        devfreq_mid_perf /sys/class/devfreq/mtk-dvfsrc-devfreq
    fi
    W 0 /sys/kernel/eara_thermal/enable
    mtkvest_perf
}

snapdragon_performance() {
    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*cpu*-lat /sys/class/devfreq/*cpu*-bw /sys/class/devfreq/*llccbw* /sys/class/devfreq/*bus_llcc* /sys/class/devfreq/*bus_ddr* /sys/class/devfreq/*memlat* /sys/class/devfreq/*cpubw* /sys/class/devfreq/*kgsl-ddr-qos*; do
            [ "$LITE_MODE" -eq 1 ] && devfreq_mid_perf "$path" || devfreq_max_perf "$path"
        done &

        for component in DDR LLCC L3; do
            path="/sys/devices/system/cpu/bus_dcvs/$component"
            [ "$LITE_MODE" -eq 1 ] && qcom_cpudcvs_mid_perf "$path" || qcom_cpudcvs_max_perf "$path"
        done &
    fi

    local gpu_path="/sys/class/kgsl/kgsl-3d0/devfreq"
    [ "$LITE_MODE" -eq 0 ] && devfreq_max_perf "$gpu_path" || devfreq_mid_perf "$gpu_path"
    W 0 /sys/class/kgsl/kgsl-3d0/bus_split
    W 1 /sys/class/kgsl/kgsl-3d0/force_clk_on
}

tegra_performance() {
    local gpu_path="/sys/kernel/tegra_gpu"
    if [ -d "$gpu_path" ]; then
        local max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
        W "$max_freq" "$gpu_path/gpu_cap_rate"
        if [ "$LITE_MODE" -eq 1 ]; then
            local mid_freq=$(which_midfreq "$gpu_path/available_frequencies")
            W "$mid_freq" "$gpu_path/gpu_floor_rate"
        else
            W "$max_freq" "$gpu_path/gpu_floor_rate"
        fi
    fi
}

exynos_performance() {
    local gpu_path="/sys/kernel/gpu"
    [ -d "$gpu_path" ] && {
        local max_freq=$(which_maxfreq "$gpu_path/gpu_available_frequencies")
        W "$max_freq" "$gpu_path/gpu_max_clock"
        if [ "$LITE_MODE" -eq 1 ]; then
            local mid_freq=$(which_midfreq "$gpu_path/gpu_available_frequencies")
            W "$mid_freq" "$gpu_path/gpu_min_clock"
        else
            W "$max_freq" "$gpu_path/gpu_min_clock"
        fi
    }
    local mali_sysfs=$(find /sys/devices/platform/ -iname "*.mali" -print -quit 2>/dev/null)
    W always_on "$mali_sysfs/power_policy"

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            [ "$LITE_MODE" -eq 1 ] && devfreq_mid_perf "$path" || devfreq_max_perf "$path"
        done &
    fi
}

unisoc_performance() {
    local gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        [ "$LITE_MODE" -eq 0 ] && devfreq_max_perf "$gpu_path" || devfreq_mid_perf "$gpu_path"
    }
}

tensor_performance() {
    local gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        local max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
        W "$max_freq" "$gpu_path/scaling_max_freq"
        if [ "$LITE_MODE" -eq 1 ]; then
            local mid_freq=$(which_midfreq "$gpu_path/available_frequencies")
            W "$mid_freq" "$gpu_path/scaling_min_freq"
        else
            W "$max_freq" "$gpu_path/scaling_min_freq"
        fi
    }
    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            [ "$LITE_MODE" -eq 1 ] && devfreq_mid_perf "$path" || devfreq_max_perf "$path"
        done &
    fi
}

mediatek_normal() {
    W 2 /sys/kernel/fpsgo/common/force_onoff
    W 0 /proc/cpufreq/cpufreq_cci_mode
    W 0 /proc/cpufreq/cpufreq_power_mode
    W 0 /sys/devices/platform/boot_dramboost/dramboost/dramboost
    W 2 /sys/devices/system/cpu/eas/enable
    W 1 /sys/module/sspm_v3/holders/ged/parameters/is_GED_KPI_enabled
    W 0 /proc/gpufreq/gpufreq_opp_freq
    W -1 /proc/gpufreqv2/fix_target_opp_index

    local min_oppfreq
    if [ -d /proc/gpufreqv2 ]; then
        min_oppfreq=$(mtk_gpufreq_minfreq_index /proc/gpufreqv2/gpu_working_opp_table)
    else
        min_oppfreq=$(mtk_gpufreq_minfreq_index /proc/gpufreq/gpufreq_opp_dump)
    fi
    W "$min_oppfreq" /sys/kernel/ged/hal/custom_boost_gpu_freq

    if [ -f "/proc/gpufreq/gpufreq_limit_table" ]; then
        for id in 0 1 2 3 4 5 6 7 8; do
            W "$id 1 1" /proc/gpufreq/gpufreq_limit_table
        done
    fi

    [ -f "/proc/gpufreq/gpufreq_power_limited" ] && {
        for setting in ignore_batt_oc ignore_batt_percent ignore_low_batt ignore_thermal_protect ignore_pbm_limited; do
            W "$setting 0" /proc/gpufreq/gpufreq_power_limited
        done
    }

    W "stop 0" /proc/mtk_batoc_throttling/battery_oc_protect_stop
    W -1 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
    W -1 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
    devfreq_unlock /sys/class/devfreq/mtk-dvfsrc-devfreq
    W 1 /sys/kernel/eara_thermal/enable
    mtkvest_normal
}

snapdragon_normal() {
    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*cpu*-lat /sys/class/devfreq/*cpu*-bw /sys/class/devfreq/*llccbw* /sys/class/devfreq/*bus_llcc* /sys/class/devfreq/*bus_ddr* /sys/class/devfreq/*memlat* /sys/class/devfreq/*cpubw* /sys/class/devfreq/*kgsl-ddr-qos*; do
            devfreq_unlock "$path"
        done &
        for component in DDR LLCC L3; do
            qcom_cpudcvs_unlock /sys/devices/system/cpu/bus_dcvs/$component
        done
    fi
    devfreq_unlock /sys/class/kgsl/kgsl-3d0/devfreq
    W 1 /sys/class/kgsl/kgsl-3d0/bus_split
    W 0 /sys/class/kgsl/kgsl-3d0/force_clk_on
}

tegra_normal() {
    local gpu_path="/sys/kernel/tegra_gpu"
    [ -d "$gpu_path" ] && {
        local max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
        local min_freq=$(which_minfreq "$gpu_path/available_frequencies")
        W "$max_freq" "$gpu_path/gpu_cap_rate"
        W "$min_freq" "$gpu_path/gpu_floor_rate"
    }
}

exynos_normal() {
    local gpu_path="/sys/kernel/gpu"
    [ -d "$gpu_path" ] && {
        local max_freq=$(which_maxfreq "$gpu_path/gpu_available_frequencies")
        local min_freq=$(which_minfreq "$gpu_path/available_frequencies")
        W "$max_freq" "$gpu_path/gpu_max_clock"
        W "$min_freq" "$gpu_path/gpu_min_clock"
    }
    local mali_sysfs=$(find /sys/devices/platform/ -iname "*.mali" -print -quit 2>/dev/null)
    W coarse_demand "$mali_sysfs/power_policy"

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            devfreq_unlock "$path"
        done &
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
        W "$max_freq" "$gpu_path/scaling_max_freq"
        W "$min_freq" "$gpu_path/scaling_min_freq"
    }
    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            devfreq_unlock "$path"
        done &
    fi
}

mediatek_powersave() {
    W 1 /proc/cpufreq/cpufreq_power_mode
    if [ -d /proc/gpufreqv2 ]; then
        local min_gpufreq_index=$(mtk_gpufreq_minfreq_index /proc/gpufreqv2/gpu_working_opp_table)
        W "$min_gpufreq_index" /proc/gpufreqv2/fix_target_opp_index
    else
        local gpu_freq=$(sed -n 's/.*freq = \([0-9]\{1,\}\).*/\1/p' /proc/gpufreq/gpufreq_opp_dump | tail -n 1)
        W "$gpu_freq" /proc/gpufreq/gpufreq_opp_freq
    fi
}

snapdragon_powersave() {
    devfreq_min_perf /sys/class/kgsl/kgsl-3d0/devfreq
}

tegra_powersave() {
    local gpu_path="/sys/kernel/tegra_gpu"
    [ -d "$gpu_path" ] && {
        local freq=$(which_minfreq "$gpu_path/available_frequencies")
        W "$freq" "$gpu_path/gpu_floor_rate"
        W "$freq" "$gpu_path/gpu_cap_rate"
    }
}

exynos_powersave() {
    local gpu_path="/sys/kernel/gpu"
    [ -d "$gpu_path" ] && {
        local freq=$(which_minfreq "$gpu_path/gpu_available_frequencies")
        W "$freq" "$gpu_path/gpu_min_clock"
        W "$freq" "$gpu_path/gpu_max_clock"
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
        W "$freq" "$gpu_path/scaling_min_freq"
        W "$freq" "$gpu_path/scaling_max_freq"
    }
}

performance_basic() {
    sync
    for dir in /sys/block/*; do
        W 0 "$dir/queue/iostats"
        W 0 "$dir/queue/add_random"
        W 32 "$dir/queue/read_ahead_kb"
        W 32 "$dir/queue/nr_requests"
    done &

    W 1 "$ipv4/tcp_low_latency"
    W 1 "$ipv4/tcp_ecn"
    W 3 "$ipv4/tcp_fastopen"
    W 1 "$ipv4/tcp_sack"
    W 0 "$ipv4/tcp_timestamps"
    W 3 /proc/sys/kernel/perf_cpu_time_max_percent
    W 0 /proc/sys/kernel/sched_schedstats
    W 0 /proc/sys/kernel/task_cpustats_enable
    W 0 /proc/sys/kernel/sched_autogroup_enabled
    W 1 /proc/sys/kernel/sched_child_runs_first
    W 32 /proc/sys/kernel/sched_nr_migrate
    W 50000 /proc/sys/kernel/sched_migration_cost_ns
    W 1000000 /proc/sys/kernel/sched_min_granularity_ns
    W 1500000 /proc/sys/kernel/sched_wakeup_granularity_ns
    W 0 /proc/sys/vm/page-cluster
    W 15 /proc/sys/vm/stat_interval
    W 0 /proc/sys/vm/compaction_proactiveness
    W 0 /sys/module/mmc_core/parameters/use_spi_crc
    W 0 /sys/module/opchain/parameters/chain_on
    W 0 /sys/module/cpufreq_bouncing/parameters/enable
    W 0 /proc/task_info/task_sched_info/task_sched_info_enable
    W 0 /proc/oplus_scheduler/sched_assist/sched_assist_enabled
    W "libunity.so, libil2cpp.so, libmain.so, libUE4.so, libgodot_android.so, libgdx.so, libgdx-box2d.so, libminecraftpe.so, libLive2DCubismCore.so, libyuzu-android.so, libryujinx.so, libcitra-android.so, libhdr_pro_engine.so, libandroidx.graphics.path.so, libeffect.so" /proc/sys/kernel/sched_lib_name
    W 255 /proc/sys/kernel/sched_lib_mask_force

    for dir in /sys/class/thermal/thermal_zone*; do
        W "step_wise" "$dir/policy"
    done &

    [ -f /sys/module/battery_saver/parameters/enabled ] && {
        if grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled; then
            W 0 /sys/module/battery_saver/parameters/enabled
        else
            W N /sys/module/battery_saver/parameters/enabled
        fi
    }

    W 0 /proc/sys/kernel/split_lock_mitigate

    if [ -f "/sys/kernel/debug/sched_features" ]; then
        W NEXT_BUDDY /sys/kernel/debug/sched_features
        W NO_TTWU_QUEUE /sys/kernel/debug/sched_features
    fi

    if [ -d "/dev/stune/" ]; then
        W 1 /dev/stune/top-app/schedtune.prefer_idle
        W 1 /dev/stune/top-app/schedtune.boost
    fi

    local tp_path="/proc/touchpanel"
    if [ -d "$tp_path" ]; then
        W 1 $tp_path/game_switch_enable
        W 0 $tp_path/oplus_tp_limit_enable
        W 0 $tp_path/oppo_tp_limit_enable
        W 1 $tp_path/oplus_tp_direction
        W 1 $tp_path/oppo_tp_direction
    fi

    W 80 /proc/sys/vm/vfs_cache_pressure

    for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
        if [ -d "$path" ]; then
            [ "$LITE_MODE" -eq 1 ] && devfreq_mid_perf "$path" || devfreq_max_perf "$path"
        fi
    done &

    if [ "$LITE_MODE" -eq 0 ] && [ "$DEVICE_MITIGATION" -eq 0 ]; then
        change_cpu_gov "performance"
    else
        change_cpu_gov "$DEFAULT_CPU_GOV"
    fi

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

    sh $STAR_PATH/BATTERY_RESTORE.sh &
    sh $STAR_PATH/CPU_DBPerformance.sh &
    dnd_on
    corin_perf
    bypass_on
    [ "$KCPU_MITIGATE" -eq 0 ] && carcpu_perf &
    anyamelfissa
}

balanced_basic() {
    sync
    [ -f /sys/module/battery_saver/parameters/enabled ] && {
        if grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled; then
            W 0 /sys/module/battery_saver/parameters/enabled
        else
            W N /sys/module/battery_saver/parameters/enabled
        fi
    }

    W 1 /proc/sys/kernel/split_lock_mitigate

    if [ -f "/sys/kernel/debug/sched_features" ]; then
        W NEXT_BUDDY /sys/kernel/debug/sched_features
        W TTWU_QUEUE /sys/kernel/debug/sched_features
    fi

    if [ -d "/dev/stune/" ]; then
        W 0 /dev/stune/top-app/schedtune.prefer_idle
        W 1 /dev/stune/top-app/schedtune.boost
    fi

    local tp_path="/proc/touchpanel"
    if [ -d "$tp_path" ]; then
        W 0 $tp_path/game_switch_enable
        W 1 $tp_path/oplus_tp_limit_enable
        W 1 $tp_path/oppo_tp_limit_enable
        W 0 $tp_path/oplus_tp_direction
        W 0 $tp_path/oppo_tp_direction
    fi

    W 120 /proc/sys/vm/vfs_cache_pressure

    for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
        devfreq_unlock "$path"
    done &

    change_cpu_gov "$DEFAULT_CPU_GOV"

    if [ -d "/proc/ppm" ]; then
        [ "$LIFE_MODE" -eq 1 ] && cpufreq_ppm_life_perf || cpufreq_ppm_unlock
    fi
    
    [ "$LIFE_MODE" -eq 1 ] && cpufreq_life_perf || cpufreq_unlock
    
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
    corin_balanced
    bypass_off
    [ "$KCPU_MITIGATE" -eq 0 ] && carcpu_balance &
    anyakawaii
}

powersave_basic() {
    sync
    balanced_basic

    [ -f /sys/module/battery_saver/parameters/enabled ] && {
        if grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled; then
            W 1 /sys/module/battery_saver/parameters/enabled
        else
            W Y /sys/module/battery_saver/parameters/enabled
        fi
    }
    
    for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
        devfreq_min_perf "$path"
    done &

    change_cpu_gov "powersave"

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

    sh $STAR_PATH/BATTERY_SAVER.sh &
    dnd_off
    corin_powersave
    bypass_off
    [ "$KCPU_MITIGATE" -eq 0 ] && carcpu_battery &
    anyakawaii
}

if [ -z "$1" ]; then
    echo "Usage: $0 <mode> (1-6)"
    exit 1
fi

case $1 in
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
        echo "Error: Invalid mode '$1'."
        exit 1
        ;;
esac

exit 0