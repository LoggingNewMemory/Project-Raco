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
TOAST=$(grep '^TOAST=' "$RACO_CONFIG" | cut -d'=' -f2)

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
STAR_PATH="$SCRIPT_PATH/STAR"
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

# Optimized to check writeability first
tweak() {
    if [ -f "$2" ]; then
        chmod 644 "$2" 2>/dev/null
        echo "$1" > "$2" 2>/dev/null
        chmod 444 "$2" 2>/dev/null
    fi
}

# Optimized to suppress errors
kakangkuh() {
    [ ! -f "$2" ] && return 1
    chmod 644 "$2" 2>/dev/null
    echo "$1" >"$2" 2>/dev/null
}

kill_all() {
    sync
    cmd activity kill-all > /dev/null 2>&1
    # Run package killing in parallel groups to speed up
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
    sh $STAR_PATH/KILL.sh &
}

bypass_on() {
    BYPASS=$(grep "^ENABLE_BYPASS=" "$RACO_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    if [ "$BYPASS" = "Yes" ]; then
        sh $SCRIPT_PATH/raco_bypass_controller.sh enable &
    fi
}

bypass_off() {
    BYPASS=$(grep "^ENABLE_BYPASS=" "$RACO_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    if [ "$BYPASS" = "Yes" ]; then
        sh $SCRIPT_PATH/raco_bypass_controller.sh disable &
    fi
}

notification() {
    local TITLE="Project Raco"
    local MESSAGE="$1"
    local LOGO="/data/local/tmp/logo.png"
    
    local CURRENT_TOAST=$(grep '^TOAST=' "$RACO_CONFIG" | cut -d'=' -f2)

    if [ "$CURRENT_TOAST" = "1" ]; then
        if [ ! -d "/data/ProjectRaco" ]; then
            mkdir -p "/data/ProjectRaco"
            chmod 777 "/data/ProjectRaco"
        fi
        echo "$MESSAGE" > /data/ProjectRaco/toast.txt
        chmod 666 /data/ProjectRaco/toast.txt
        am start -n com.kanagawa.yamada.project.raco/com.kanagawa.yamada.project.raco.MainActivity > /dev/null 2>&1 &
    else
        if [ "$LEGACY_NOTIF" = "1" ]; then
            su -lp 2000 -c "cmd notification post -S bigtext -t '$TITLE' TagRaco '$MESSAGE'" &
        else
            su -lp 2000 -c "cmd notification post -S bigtext -t '$TITLE' -i file://$LOGO -I file://$LOGO TagRaco '$MESSAGE'" &
        fi
    fi
}

dnd_off() {
    DND=$(grep "^DND" "$RACO_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    if [ "$DND" = "Yes" ]; then
        cmd notification set_dnd off &
    fi
}

dnd_on() {
    DND=$(grep "^DND" "$RACO_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    if [ "$DND" = "Yes" ]; then
        cmd notification set_dnd priority &
    fi
}

###################################
# Optimized Helper Functions
###################################

# Consolidates frequency logic to avoid repetitive piping
get_freq() {
    local mode=$1
    local file=$2
    [ ! -f "$file" ] && return
    
    case "$mode" in
        max) tr ' ' '\n' <"$file" | sort -nr | head -n 1 ;;
        min) tr ' ' '\n' <"$file" | grep -v '^[[:space:]]*$' | sort -n | head -n 1 ;;
        mid)
            local list=$(tr ' ' '\n' <"$file" | grep -v '^[[:space:]]*$' | sort -nr)
            local count=$(echo "$list" | wc -l)
            local mid=$(((count + 1) / 2))
            echo "$list" | head -n $mid | tail -n 1
            ;;
    esac
}

mtk_gpufreq_index() {
    local mode=$1
    local file=$2
    [ ! -f "$file" ] && return

    case "$mode" in
        min) awk -F'[][]' '{print $2}' "$file" | tail -n 1 ;;
        mid)
            local count=$(wc -l <"$file")
            local mid=$(((count + 1) / 2))
            awk -F'[][]' '{print $2}' "$file" | head -n $mid | tail -n 1
            ;;
    esac
}

# Generic Devfreq setter to handle Race Conditions
set_devfreq() {
    local path=$1
    local mode=$2 # max, mid, min, unlock
    [ ! -f "$path/available_frequencies" ] && return

    local max=$(get_freq max "$path/available_frequencies")
    local min=$(get_freq min "$path/available_frequencies")
    local mid=$(get_freq mid "$path/available_frequencies")

    # Race Condition Fix:
    # Increasing: Max first, then Min
    # Decreasing: Min first, then Max
    
    case "$mode" in
        max)
            tweak "$max" "$path/max_freq"
            tweak "$max" "$path/min_freq"
            ;;
        mid)
            tweak "$max" "$path/max_freq"
            tweak "$mid" "$path/min_freq"
            ;;
        unlock)
            kakangkuh "$max" "$path/max_freq"
            kakangkuh "$min" "$path/min_freq"
            ;;
        min)
            tweak "$min" "$path/min_freq"
            tweak "$min" "$path/max_freq"
            ;;
    esac
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
# CPU Frequency Logic (Fixed Race Condition)
###################################

change_cpu_gov() {
    chmod 644 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null
    echo "$1" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null 2>/dev/null
    chmod 444 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null
    chmod 444 /sys/devices/system/cpu/cpufreq/policy*/scaling_governor 2>/dev/null
}

cpufreq_apply_perf() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        [ ! -d "$path" ] && continue
        local max=$(<"$path/cpuinfo_max_freq")
        local mid=$(get_freq mid "$path/scaling_available_frequencies")
        
        # 1. Set PPM Limits
        if [ "$LITE_MODE" -eq 1 ]; then
            tweak "$cluster $mid" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        else
            tweak "$cluster $max" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        fi
        tweak "$cluster $max" /proc/ppm/policy/hard_userlimit_max_cpu_freq

        # 2. Set Scaling Limits (MAX FIRST to avoid lock)
        tweak "$max" "$path/scaling_max_freq"
        
        if [ "$LITE_MODE" -eq 1 ]; then
            tweak "$mid" "$path/scaling_min_freq"
        else
            tweak "$max" "$path/scaling_min_freq"
        fi
        
        ((cluster++))
    done
}

cpufreq_apply_unlock() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        [ ! -d "$path" ] && continue
        local max=$(<"$path/cpuinfo_max_freq")
        local min=$(<"$path/cpuinfo_min_freq")
        
        # PPM
        kakangkuh "$cluster $max" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        kakangkuh "$cluster $min" /proc/ppm/policy/hard_userlimit_min_cpu_freq

        # Scaling (MAX FIRST)
        kakangkuh "$max" "$path/scaling_max_freq"
        kakangkuh "$min" "$path/scaling_min_freq"
        
        ((cluster++))
    done
}

cpufreq_apply_powersave() {
    local cluster=0
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        [ ! -d "$path" ] && continue
        local min=$(<"$path/cpuinfo_min_freq")
        local mid=$(get_freq mid "$path/scaling_available_frequencies")
        
        # PPM
        if [ "$BETTER_POWERAVE" -eq 1 ]; then
            tweak "$cluster $mid" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        else
            tweak "$cluster $min" /proc/ppm/policy/hard_userlimit_max_cpu_freq
        fi
        tweak "$cluster $min" /proc/ppm/policy/hard_userlimit_min_cpu_freq

        # Scaling (MIN FIRST to avoid lock when dropping high max)
        tweak "$min" "$path/scaling_min_freq"

        if [ "$BETTER_POWERAVE" -eq 1 ]; then
            tweak "$mid" "$path/scaling_max_freq"
        else
            tweak "$min" "$path/scaling_max_freq"
        fi
        
        ((cluster++))
    done
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
                mid_oppfreq=$(mtk_gpufreq_index mid /proc/gpufreqv2/gpu_working_opp_table)
            else
                mid_oppfreq=$(mtk_gpufreq_index mid /proc/gpufreq/gpufreq_opp_dump)
            fi
            tweak "$mid_oppfreq" /sys/kernel/ged/hal/custom_boost_gpu_freq
        fi
    ) &

    [ -f "/proc/gpufreq/gpufreq_power_limited" ] && {
        for setting in ignore_batt_oc ignore_batt_percent ignore_low_batt ignore_thermal_protect ignore_pbm_limited; do
            tweak "$setting 1" /proc/gpufreq/gpufreq_power_limited
        done
    } &

    (
        tweak "stop 1" /proc/mtk_batoc_throttling/battery_oc_protect_stop

        if [ "$LITE_MODE" -eq 0 ]; then
            tweak 0 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
            tweak 0 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
            set_devfreq /sys/class/devfreq/mtk-dvfsrc-devfreq max
        else
            tweak -1 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
            tweak -1 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
            set_devfreq /sys/class/devfreq/mtk-dvfsrc-devfreq mid
        fi
    ) &

    mtkvest_perf
    wait
}

snapdragon_performance() {
    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        local mode="max"
        [ "$LITE_MODE" -eq 1 ] && mode="mid"

        for path in /sys/class/devfreq/*cpu*-lat \
            /sys/class/devfreq/*cpu*-bw \
            /sys/class/devfreq/*llccbw* \
            /sys/class/devfreq/*bus_llcc* \
            /sys/class/devfreq/*bus_ddr* \
            /sys/class/devfreq/*memlat* \
            /sys/class/devfreq/*cpubw* \
            /sys/class/devfreq/*kgsl-ddr-qos*; do
            set_devfreq "$path" "$mode"
        done &

        for component in DDR LLCC L3; do
            local path="/sys/devices/system/cpu/bus_dcvs/$component"
            [ -f "$path/available_frequencies" ] && {
                 local max=$(get_freq max "$path/available_frequencies")
                 tweak "$max" "$path/hw_max_freq"
                 if [ "$LITE_MODE" -eq 1 ]; then
                    local mid=$(get_freq mid "$path/available_frequencies")
                    tweak "$mid" "$path/hw_min_freq"
                 else
                    tweak "$max" "$path/hw_min_freq"
                 fi
            }
        done &
    fi

    (
        local gpu_path="/sys/class/kgsl/kgsl-3d0/devfreq"
        if [ "$LITE_MODE" -eq 0 ]; then
            set_devfreq "$gpu_path" max
        else
            set_devfreq "$gpu_path" mid
        fi
        tweak 0 /sys/class/kgsl/kgsl-3d0/bus_split
        tweak 1 /sys/class/kgsl/kgsl-3d0/force_clk_on
    ) &
    wait
}

exynos_performance() {
    (
        gpu_path="/sys/kernel/gpu"
        if [ -d "$gpu_path" ]; then
            max_freq=$(get_freq max "$gpu_path/gpu_available_frequencies")
            tweak "$max_freq" "$gpu_path/gpu_max_clock"
            if [ "$LITE_MODE" -eq 1 ]; then
                mid_freq=$(get_freq mid "$gpu_path/gpu_available_frequencies")
                tweak "$mid_freq" "$gpu_path/gpu_min_clock"
            else
                tweak "$max_freq" "$gpu_path/gpu_min_clock"
            fi
        fi
        mali_sysfs=$(find /sys/devices/platform/ -iname "*.mali" -print -quit 2>/dev/null)
        tweak always_on "$mali_sysfs/power_policy"
    ) &

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            if [ "$LITE_MODE" -eq 1 ]; then
                set_devfreq "$path" mid
            else
                set_devfreq "$path" max
            fi
        done &
    fi
    wait
}

unisoc_performance() {
    gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        if [ "$LITE_MODE" -eq 0 ]; then
            set_devfreq "$gpu_path" max
        else
            set_devfreq "$gpu_path" mid
        fi
    }
}

tensor_performance() {
    gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        max_freq=$(get_freq max "$gpu_path/available_frequencies")
        tweak "$max_freq" "$gpu_path/scaling_max_freq"

        if [ "$LITE_MODE" -eq 1 ]; then
            mid_freq=$(get_freq mid "$gpu_path/available_frequencies")
            tweak "$mid_freq" "$gpu_path/scaling_min_freq"
        else
            tweak "$max_freq" "$gpu_path/scaling_min_freq"
        fi
    } &

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            if [ "$LITE_MODE" -eq 1 ]; then
                set_devfreq "$path" mid
            else
                set_devfreq "$path" max
            fi
        done &
    fi
    wait
}

tegra_performance() {
    gpu_path="/sys/kernel/tegra_gpu"
    if [ -d "$gpu_path" ]; then
        max_freq=$(get_freq max "$gpu_path/available_frequencies")
        tweak "$max_freq" "$gpu_path/gpu_cap_rate"
        if [ "$LITE_MODE" -eq 1 ]; then
            mid_freq=$(get_freq mid "$gpu_path/available_frequencies")
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
        
        kakangkuh 0 /proc/gpufreq/gpufreq_opp_freq
        kakangkuh -1 /proc/gpufreqv2/fix_target_opp_index

        if [ -d /proc/gpufreqv2 ]; then
            min_oppfreq=$(mtk_gpufreq_index min /proc/gpufreqv2/gpu_working_opp_table)
        else
            min_oppfreq=$(mtk_gpufreq_index min /proc/gpufreq/gpufreq_opp_dump)
        fi
        tweak "$min_oppfreq" /sys/kernel/ged/hal/custom_boost_gpu_freq
    ) &

    if [[ -f "/proc/gpufreq/gpufreq_limit_table" ]]; then
        for id in {0..8}; do
            tweak "$id 1 1" /proc/gpufreq/gpufreq_limit_table
        done
    fi &

    [ -f "/proc/gpufreq/gpufreq_power_limited" ] && {
        for setting in ignore_batt_oc ignore_batt_percent ignore_low_batt ignore_thermal_protect ignore_pbm_limited; do
            tweak "$setting 0" /proc/gpufreq/gpufreq_power_limited
        done
    } &

    (
        tweak "stop 0" /proc/mtk_batoc_throttling/battery_oc_protect_stop
        kakangkuh -1 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
        kakangkuh -1 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
        set_devfreq /sys/class/devfreq/mtk-dvfsrc-devfreq unlock
        tweak 1 /sys/kernel/eara_thermal/enable
    ) &

    mtkvest_normal
    wait
}

snapdragon_normal() {
    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*cpu*-lat /sys/class/devfreq/*cpu*-bw /sys/class/devfreq/*llccbw* /sys/class/devfreq/*bus_llcc* /sys/class/devfreq/*bus_ddr* /sys/class/devfreq/*memlat* /sys/class/devfreq/*cpubw* /sys/class/devfreq/*kgsl-ddr-qos*; do
            set_devfreq "$path" unlock
        done &

        for component in DDR LLCC L3; do
            path="/sys/devices/system/cpu/bus_dcvs/$component"
            [ -f "$path/available_frequencies" ] && {
                 local max=$(get_freq max "$path/available_frequencies")
                 local min=$(get_freq min "$path/available_frequencies")
                 kakangkuh "$max" "$path/hw_max_freq"
                 kakangkuh "$min" "$path/hw_min_freq"
            }
        done &
        wait
    fi

    set_devfreq /sys/class/kgsl/kgsl-3d0/devfreq unlock
    tweak 1 /sys/class/kgsl/kgsl-3d0/bus_split
    tweak 0 /sys/class/kgsl/kgsl-3d0/force_clk_on
}

exynos_normal() {
    (
        gpu_path="/sys/kernel/gpu"
        if [ -d "$gpu_path" ]; then
            max_freq=$(get_freq max "$gpu_path/gpu_available_frequencies")
            min_freq=$(get_freq min "$gpu_path/available_frequencies")
            kakangkuh "$max_freq" "$gpu_path/gpu_max_clock"
            kakangkuh "$min_freq" "$gpu_path/gpu_min_clock"
        fi
        mali_sysfs=$(find /sys/devices/platform/ -iname "*.mali" -print -quit 2>/dev/null)
        tweak coarse_demand "$mali_sysfs/power_policy"
    ) &

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            set_devfreq "$path" unlock
        done &
    fi
    wait
}

unisoc_normal() {
    gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && set_devfreq "$gpu_path" unlock
}

tensor_normal() {
    gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        max_freq=$(get_freq max "$gpu_path/available_frequencies")
        min_freq=$(get_freq min "$gpu_path/available_frequencies")
        kakangkuh "$max_freq" "$gpu_path/scaling_max_freq"
        kakangkuh "$min_freq" "$gpu_path/scaling_min_freq"
    } &

    if [ "$DEVICE_MITIGATION" -eq 0 ]; then
        for path in /sys/class/devfreq/*devfreq_mif*; do
            set_devfreq "$path" unlock
        done &
    fi
    wait
}

tegra_normal() {
    gpu_path="/sys/kernel/tegra_gpu"
    [ -d "$gpu_path" ] && {
        max_freq=$(get_freq max "$gpu_path/available_frequencies")
        min_freq=$(get_freq min "$gpu_path/available_frequencies")
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
        min_gpufreq_index=$(mtk_gpufreq_index min /proc/gpufreqv2/gpu_working_opp_table)
        tweak "$min_gpufreq_index" /proc/gpufreqv2/fix_target_opp_index
    else
        gpu_freq=$(sed -n 's/.*freq = \([0-9]\{1,\}\).*/\1/p' /proc/gpufreq/gpufreq_opp_dump | tail -n 1)
        tweak "$gpu_freq" /proc/gpufreq/gpufreq_opp_freq
    fi
}

snapdragon_powersave() {
    set_devfreq /sys/class/kgsl/kgsl-3d0/devfreq min
}

exynos_powersave() {
    gpu_path="/sys/kernel/gpu"
    [ -d "$gpu_path" ] && {
        freq=$(get_freq min "$gpu_path/gpu_available_frequencies")
        tweak "$freq" "$gpu_path/gpu_min_clock"
        tweak "$freq" "$gpu_path/gpu_max_clock"
    }
}

unisoc_powersave() {
    gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && set_devfreq "$gpu_path" min
}

tensor_powersave() {
    gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
    [ -n "$gpu_path" ] && {
        freq=$(get_freq min "$gpu_path/available_frequencies")
        tweak "$freq" "$gpu_path/scaling_min_freq"
        tweak "$freq" "$gpu_path/scaling_max_freq"
    }
}

tegra_powersave() {
    gpu_path="/sys/kernel/tegra_gpu"
    [ -d "$gpu_path" ] && {
        freq=$(get_freq min "$gpu_path/available_frequencies")
        tweak "$freq" "$gpu_path/gpu_floor_rate"
        tweak "$freq" "$gpu_path/gpu_cap_rate"
    }
}

##################################
# Performance Profile (1)
##################################
performance_basic() {
    sync
    
    # Combined Sysfs Tweaks to reduce subshells
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
            if [ "$LITE_MODE" -eq 1 ]; then
                set_devfreq "$path" mid
            else
                set_devfreq "$path" max
            fi
        done

        for dir in /sys/block/mmcblk0 /sys/block/mmcblk1 /sys/block/sd*; do
            tweak 32 "$dir/queue/read_ahead_kb"
            tweak 32 "$dir/queue/nr_requests"
        done
    ) &

    # CPU Freq (Concurrent)
    (
        if [ "$LITE_MODE" -eq 0 ] && [ "$DEVICE_MITIGATION" -eq 0 ]; then
            change_cpu_gov "performance"
        else
            change_cpu_gov "$DEFAULT_CPU_GOV"
        fi
        
        cpufreq_apply_perf
    ) &
    
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

    sh $STAR_PATH/BATTERY_RESTORE.sh &
    sh $STAR_PATH/CPU_DBPerformance.sh &
    dnd_on &
    corin_perf &
    bypass_on &
    
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
    performance_basic # Dirty Fix to fix Locked GPU
    wait

    (
        if [ -f /sys/module/battery_saver/parameters/enabled ]; then
            if grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled; then
                kakangkuh 0 /sys/module/battery_saver/parameters/enabled
            else
                kakangkuh N /sys/module/battery_saver/parameters/enabled
            fi
        fi

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

        for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
            set_devfreq "$path" unlock
        done
    ) &

    (
        change_cpu_gov "$DEFAULT_CPU_GOV"
        cpufreq_apply_unlock
    ) &
    
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
    
    sh $STAR_PATH/BATTERY_RESTORE.sh &
    sh $STAR_PATH/CPU_DBBalance.sh &
    dnd_off &
    corin_balanced &
    bypass_off &

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
            set_devfreq "$path" min
        done
    ) &

    (
        change_cpu_gov "powersave"
        cpufreq_apply_powersave
    ) &

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

    sh $STAR_PATH/BATTERY_SAVER.sh &
    dnd_off &
    corin_powersave &
    bypass_off &

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