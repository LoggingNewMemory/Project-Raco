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

##############################
# Begin Functions
##############################

anyamelfissa() {
    if [ "$INCLUDE_ANYA" = "1" ] && [ "$ANYA" = "1" ]; then
        sh /data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh
    fi
}

anyakawaii() {
    if [ "$INCLUDE_ANYA" = "1" ] && [ "$ANYA" = "1" ]; then
        sh /data/adb/modules/ProjectRaco/Scripts/AnyaKawaii.sh
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
        # Keep the exception for the keyboard to prevent it from closing while you're using a terminal.
        if [ "$pkg" != "com.google.android.inputmethod.latin" ]; then 
            am force-stop "$pkg" > /dev/null 2>&1
        fi
    done


    pm trim-caches 100G > /dev/null 2>&1
    echo 3 > /proc/sys/vm/drop_caches
    logcat -c
    logcat -b all -c
	sh $STAR_PATH/KILL.sh
}

# This is also external

bypass_on() {
    BYPASS=$(grep "^ENABLE_BYPASS=" "$RACO_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    if [ "$BYPASS" = "Yes" ]; then
        sh $SCRIPT_PATH/raco_bypass_controller.sh enable
    fi
}

bypass_off() {
    BYPASS=$(grep "^ENABLE_BYPASS=" "$RACO_CONFIG" | cut -d'=' -f2 | tr -d ' ')
    if [ "$BYPASS" = "Yes" ]; then
        sh $SCRIPT_PATH/raco_bypass_controller.sh disable
    fi
}

notification() {
    local TITLE="Otonose Raco"
    local MESSAGE="$1"
    local LOGO="/data/local/tmp/logo.png"
    
    su -lp 2000 -c "cmd notification post -S bigtext -t '$TITLE' -i file://$LOGO -I file://$LOGO TagRaco '$MESSAGE'"
}

dnd_off() {
	DND=$(grep "^DND" "$RACO_CONFIG" | cut -d'=' -f2 | tr -d ' ')
	if [ "$DND" = "Yes" ]; then
		cmd notification set_dnd off
	fi
}

dnd_on() {
	DND=$(grep "^DND" "$RACO_CONFIG" | cut -d'=' -f2 | tr -d ' ')
	if [ "$DND" = "Yes" ]; then
		cmd notification set_dnd priority
	fi
}

###################################
# MTKVest Functions 
###################################

mtkvest_perf() {
    # Performance Manager - disable system limiter
    tweak 1 /proc/perfmgr/syslimiter/syslimiter_force_disable

    # Configure GED HAL settings
    if [ -d /sys/kernel/ged/hal ]; then
        tweak 2 /sys/kernel/ged/hal/loading_base_dvfs_step
        tweak 1 /sys/kernel/ged/hal/loading_stride_size
        tweak 16 /sys/kernel/ged/hal/loading_window_size
    fi

    tweak 100 /sys/kernel/ged/hal/gpu_boost_level
}

mtkvest_normal() {
    # Performance manager settings for balanced operation
    tweak 0 /proc/perfmgr/syslimiter/syslimiter_force_disable

    # Configure GED HAL settings
    if [ -d /sys/kernel/ged/hal ]; then
        tweak 4 /sys/kernel/ged/hal/loading_base_dvfs_step
        tweak 2 /sys/kernel/ged/hal/loading_stride_size
        tweak 8 /sys/kernel/ged/hal/loading_window_size
    fi

    tweak -1 /sys/kernel/ged/hal/gpu_boost_level
}

###################################
# Frequency fetching & setting (From Encore)
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
	chmod 644 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
	echo "$1" | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor >/dev/null
	chmod 444 /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
	chmod 444 /sys/devices/system/cpu/cpufreq/policy*/scaling_governor
}

cpufreq_ppm_max_perf() {
	cluster=-1
	for path in /sys/devices/system/cpu/cpufreq/policy*; do
		((cluster++))
		cpu_maxfreq=$(<"$path/cpuinfo_max_freq")
		tweak "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq

		if [ "$LITE_MODE" -eq 1 ]; then
			cpu_midfreq=$(which_midfreq "$path/scaling_available_frequencies")
			tweak "$cluster $cpu_midfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
		else
			tweak "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
		fi
	done
}

cpufreq_max_perf() {
	for path in /sys/devices/system/cpu/*/cpufreq; do
		cpu_maxfreq=$(<"$path/cpuinfo_max_freq")
		tweak "$cpu_maxfreq" "$path/scaling_max_freq"

		if [ "$LITE_MODE" -eq 1 ]; then
			cpu_midfreq=$(which_midfreq "$path/scaling_available_frequencies")
			tweak "$cpu_midfreq" "$path/scaling_min_freq"
		else
			tweak "$cpu_maxfreq" "$path/scaling_min_freq"
		fi
	done
	chmod -f 444 /sys/devices/system/cpu/cpufreq/policy*/scaling_*_freq
}

cpufreq_ppm_unlock() {
	cluster=0
	for path in /sys/devices/system/cpu/cpufreq/policy*; do
		cpu_maxfreq=$(<"$path/cpuinfo_max_freq")
		cpu_minfreq=$(<"$path/cpuinfo_min_freq")
		kakangkuh "$cluster $cpu_maxfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
		kakangkuh "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
		((cluster++))
	done
}

cpufreq_unlock() {
	for path in /sys/devices/system/cpu/*/cpufreq; do
		cpu_maxfreq=$(<"$path/cpuinfo_max_freq")
		cpu_minfreq=$(<"$path/cpuinfo_min_freq")
		kakangkuh "$cpu_maxfreq" "$path/scaling_max_freq"
		kakangkuh "$cpu_minfreq" "$path/scaling_min_freq"
	done
	chmod -f 644 /sys/devices/system/cpu/cpufreq/policy*/scaling_*_freq
}

cpufreq_ppm_min_perf() {
    cluster=-1
    for path in /sys/devices/system/cpu/cpufreq/policy*; do
        ((cluster++))
        cpu_minfreq=$(<"$path/cpuinfo_min_freq")
        if [ "$BETTER_POWERAVE" -eq 1 ]; then
            cpu_midfreq=$(which_midfreq "$path/scaling_available_frequencies")
            tweak "$cluster $cpu_midfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
            tweak "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        else
            tweak "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_max_cpu_freq
            tweak "$cluster $cpu_minfreq" /proc/ppm/policy/hard_userlimit_min_cpu_freq
        fi
    done
}

cpufreq_min_perf() {
    for path in /sys/devices/system/cpu/*/cpufreq; do
        cpu_minfreq=$(<"$path/cpuinfo_min_freq")
        if [ "$BETTER_POWERAVE" -eq 1 ]; then
            cpu_midfreq=$(which_midfreq "$path/scaling_available_frequencies")
            tweak "$cpu_midfreq" "$path/scaling_max_freq"
            tweak "$cpu_minfreq" "$path/scaling_min_freq"
        else
            tweak "$cpu_minfreq" "$path/scaling_max_freq"
            tweak "$cpu_minfreq" "$path/scaling_min_freq"
        fi
    done
    chmod -f 444 /sys/devices/system/cpu/cpufreq/policy*/scaling_*_freq
}


###################################
# Device-specific performance profile
###################################

mediatek_performance() {
	# MTK Power and CCI mode
	tweak 1 /proc/cpufreq/cpufreq_cci_mode
	tweak 3 /proc/cpufreq/cpufreq_power_mode

	# Force off FPSGO
	tweak 0 /sys/kernel/fpsgo/common/force_onoff

	# DDR Boost mode
	tweak 1 /sys/devices/platform/boot_dramboost/dramboost/dramboost

	# EAS/HMP Switch
	tweak 0 /sys/devices/system/cpu/eas/enable

	# Disable GED KPI
	tweak 0 /sys/module/sspm_v3/holders/ged/parameters/is_GED_KPI_enabled

	if [ "$LITE_MODE" -eq 0 ]; then
		if [ -d /proc/gpufreqv2 ]; then
			tweak 0 /proc/gpufreqv2/fix_target_opp_index
		else
			gpu_freq=$(sed -n 's/.*freq = \([0-9]\{1,\}\).*/\1/p' /proc/gpufreq/gpufreq_opp_dump | head -n 1)
			tweak "$gpu_freq" /proc/gpufreq/gpufreq_opp_freq
		fi
	else
		tweak 0 /proc/gpufreq/gpufreq_opp_freq
		tweak -1 /proc/gpufreqv2/fix_target_opp_index

		if [ -d /proc/gpufreqv2 ]; then
			mid_oppfreq=$(mtk_gpufreq_midfreq_index /proc/gpufreqv2/gpu_working_opp_table)
		else
			mid_oppfreq=$(mtk_gpufreq_midfreq_index /proc/gpufreq/gpufreq_opp_dump)
		fi
		tweak "$mid_oppfreq" /sys/kernel/ged/hal/custom_boost_gpu_freq
	fi

	# Disable GPU Power limiter
	[ -f "/proc/gpufreq/gpufreq_power_limited" ] && {
		for setting in ignore_batt_oc ignore_batt_percent ignore_low_batt ignore_thermal_protect ignore_pbm_limited; do
			tweak "$setting 1" /proc/gpufreq/gpufreq_power_limited
		done
	}

	# Disable battery current limiter
	tweak "stop 1" /proc/mtk_batoc_throttling/battery_oc_protect_stop

	# DRAM Frequency
	if [ "$LITE_MODE" -eq 0 ]; then
		tweak 0 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
		tweak 0 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
		devfreq_max_perf /sys/class/devfreq/mtk-dvfsrc-devfreq
	else
		tweak -1 /sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp
		tweak -1 /sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp
		devfreq_mid_perf /sys/class/devfreq/mtk-dvfsrc-devfreq
	fi

	# Eara Thermal
	tweak 0 /sys/kernel/eara_thermal/enable

    # Call the simplified function for other tweaks
    mtkvest_perf
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
			path="/sys/devices/system/cpu/bus_dcvs/$component"
			if [ "$LITE_MODE" -eq 1 ]; then
				qcom_cpudcvs_mid_perf "$path"
			else
				qcom_cpudcvs_max_perf "$path"
			fi
		done &
	fi

	# GPU tweak
	gpu_path="/sys/class/kgsl/kgsl-3d0/devfreq"
	if [ "$LITE_MODE" -eq 0 ]; then
	    devfreq_max_perf "$gpu_path"
	else
	    devfreq_mid_perf "$gpu_path"
	fi

	tweak 0 /sys/class/kgsl/kgsl-3d0/bus_split
	tweak 1 /sys/class/kgsl/kgsl-3d0/force_clk_on
}

tegra_performance() {
	gpu_path="/sys/kernel/tegra_gpu"
	if [ -d "$gpu_path" ]; then
		max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
		tweak "$max_freq" "$gpu_path/gpu_cap_rate"

		if [ "$LITE_MODE" -eq 1 ]; then
			mid_freq=$(which_midfreq "$gpu_path/available_frequencies")
			tweak "$mid_freq" "$gpu_path/gpu_floor_rate"
		else
			tweak "$max_freq" "$gpu_path/gpu_floor_rate"
		fi
	fi
}

exynos_performance() {
	gpu_path="/sys/kernel/gpu"
	[ -d "$gpu_path" ] && {
		max_freq=$(which_maxfreq "$gpu_path/gpu_available_frequencies")
		tweak "$max_freq" "$gpu_path/gpu_max_clock"

		if [ "$LITE_MODE" -eq 1 ]; then
			mid_freq=$(which_midfreq "$gpu_path/gpu_available_frequencies")
			tweak "$mid_freq" "$gpu_path/gpu_min_clock"
		else
			tweak "$max_freq" "$gpu_path/gpu_min_clock"
		fi
	}

	mali_sysfs=$(find /sys/devices/platform/ -iname "*.mali" -print -quit 2>/dev/null)
	tweak always_on "$mali_sysfs/power_policy"

	if [ "$DEVICE_MITIGATION" -eq 0 ]; then
		for path in /sys/class/devfreq/*devfreq_mif*; do
			if [ "$LITE_MODE" -eq 1 ]; then
				devfreq_mid_perf "$path"
			else
				devfreq_max_perf "$path"
			fi
		done &
	fi
}

unisoc_performance() {
	gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
	[ -n "$gpu_path" ] && {
		if [ "$LITE_MODE" -eq 0 ]; then
			devfreq_max_perf "$gpu_path"
		else
			devfreq_mid_perf "$gpu_path"
		fi
	}
}

tensor_performance() {
	gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
	[ -n "$gpu_path" ] && {
		max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
		tweak "$max_freq" "$gpu_path/scaling_max_freq"

		if [ "$LITE_MODE" -eq 1 ]; then
			mid_freq=$(which_midfreq "$gpu_path/available_frequencies")
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
		done &
	fi
}


###################################
# Device-specific normal profile
###################################

mediatek_normal() {

	# Free FPSGO
	tweak 2 /sys/kernel/fpsgo/common/force_onoff

	tweak 0 /proc/cpufreq/cpufreq_cci_mode
	tweak 0 /proc/cpufreq/cpufreq_power_mode
	tweak 0 /sys/devices/platform/boot_dramboost/dramboost/dramboost
	tweak 2 /sys/devices/system/cpu/eas/enable

	# Enable GED KPI
	tweak 1 /sys/module/sspm_v3/holders/ged/parameters/is_GED_KPI_enabled
	
	kakangkuh 0 /proc/gpufreq/gpufreq_opp_freq
	kakangkuh -1 /proc/gpufreqv2/fix_target_opp_index

	if [ -d /proc/gpufreqv2 ]; then
		min_oppfreq=$(mtk_gpufreq_minfreq_index /proc/gpufreqv2/gpu_working_opp_table)
	else
		min_oppfreq=$(mtk_gpufreq_minfreq_index /proc/gpufreq/gpufreq_opp_dump)
	fi
	tweak "$min_oppfreq" /sys/kernel/ged/hal/custom_boost_gpu_freq

    # Reset GPU frequency limits to normal
    if [[ -f "/proc/gpufreq/gpufreq_limit_table" ]]; then
        for id in {0..8}; do
            tweak "$id 1 1" /proc/gpufreq/gpufreq_limit_table
        done
    fi

	# Reset GPU power limiter
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

    # Call the simplified function for other tweaks
    mtkvest_normal
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
		done &

		for component in DDR LLCC L3; do
			qcom_cpudcvs_unlock /sys/devices/system/cpu/bus_dcvs/$component
		done
	fi

	devfreq_unlock /sys/class/kgsl/kgsl-3d0/devfreq
	tweak 1 /sys/class/kgsl/kgsl-3d0/bus_split
	tweak 0 /sys/class/kgsl/kgsl-3d0/force_clk_on
}

tegra_normal() {
	gpu_path="/sys/kernel/tegra_gpu"
	[ -d "$gpu_path" ] && {
		max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
		min_freq=$(which_minfreq "$gpu_path/available_frequencies")
		kakangkuh "$max_freq" "$gpu_path/gpu_cap_rate"
		kakangkuh "$min_freq" "$gpu_path/gpu_floor_rate"
	}
}

exynos_normal() {
	gpu_path="/sys/kernel/gpu"
	[ -d "$gpu_path" ] && {
		max_freq=$(which_maxfreq "$gpu_path/gpu_available_frequencies")
		min_freq=$(which_minfreq "$gpu_path/available_frequencies")
		kakangkuh "$max_freq" "$gpu_path/gpu_max_clock"
		kakangkuh "$min_freq" "$gpu_path/gpu_min_clock"
	}

	mali_sysfs=$(find /sys/devices/platform/ -iname "*.mali" -print -quit 2>/dev/null)
	tweak coarse_demand "$mali_sysfs/power_policy"

	if [ "$DEVICE_MITIGATION" -eq 0 ]; then
		for path in /sys/class/devfreq/*devfreq_mif*; do
			devfreq_unlock "$path"
		done &
	fi
}

unisoc_normal() {
	gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
	[ -n "$gpu_path" ] && devfreq_unlock "$gpu_path"
}

tensor_normal() {
	gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
	[ -n "$gpu_path" ] && {
		max_freq=$(which_maxfreq "$gpu_path/available_frequencies")
		min_freq=$(which_minfreq "$gpu_path/available_frequencies")
		kakangkuh "$max_freq" "$gpu_path/scaling_max_freq"
		kakangkuh "$min_freq" "$gpu_path/scaling_min_freq"
	}

	if [ "$DEVICE_MITIGATION" -eq 0 ]; then
		for path in /sys/class/devfreq/*devfreq_mif*; do
			devfreq_unlock "$path"
		done &
	fi
}


###################################
# Device-specific powersave profile
###################################

mediatek_powersave() {
	tweak 1 /proc/cpufreq/cpufreq_power_mode
	if [ -d /proc/gpufreqv2 ]; then
		min_gpufreq_index=$(mtk_gpufreq_minfreq_index /proc/gpufreqv2/gpu_working_opp_table)
		tweak "$min_gpufreq_index" /proc/gpufreqv2/fix_target_opp_index
	else
		gpu_freq=$(sed -n 's/.*freq = \([0-9]\{1,\}\).*/\1/p' /proc/gpufreq/gpufreq_opp_dump | tail -n 1)
		tweak "$gpu_freq" /proc/gpufreq/gpufreq_opp_freq
	fi
}

snapdragon_powersave() {
	devfreq_min_perf /sys/class/kgsl/kgsl-3d0/devfreq
}

tegra_powersave() {
	gpu_path="/sys/kernel/tegra_gpu"
	[ -d "$gpu_path" ] && {
		freq=$(which_minfreq "$gpu_path/available_frequencies")
		tweak "$freq" "$gpu_path/gpu_floor_rate"
		tweak "$freq" "$gpu_path/gpu_cap_rate"
	}
}

exynos_powersave() {
	gpu_path="/sys/kernel/gpu"
	[ -d "$gpu_path" ] && {
		freq=$(which_minfreq "$gpu_path/gpu_available_frequencies")
		tweak "$freq" "$gpu_path/gpu_min_clock"
		tweak "$freq" "$gpu_path/gpu_max_clock"
	}
}

unisoc_powersave() {
	gpu_path=$(find /sys/class/devfreq/ -type d -iname "*.gpu" -print -quit 2>/dev/null)
	[ -n "$gpu_path" ] && devfreq_min_perf "$gpu_path"
}

tensor_powersave() {
	gpu_path=$(find /sys/devices/platform/ -type d -iname "*.mali" -print -quit 2>/dev/null)
	[ -n "$gpu_path" ] && {
		freq=$(which_minfreq "$gpu_path/available_frequencies")
		tweak "$freq" "$gpu_path/scaling_min_freq"
		tweak "$freq" "$gpu_path/scaling_max_freq"
	}
}


##################################
# Performance Profile (1)
##################################
performance_basic() {
    sync
    # I/O Tweaks
    for dir in /sys/block/*; do
        tweak 0 "$dir/queue/iostats"
        tweak 0 "$dir/queue/add_random"
    done &

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

    for dir in /sys/class/thermal/thermal_zone*; do
        tweak "step_wise" "$dir/policy"
    done

    [ -f /sys/module/battery_saver/parameters/enabled ] && {
        if grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled; then
            tweak 0 /sys/module/battery_saver/parameters/enabled
        else
            tweak N /sys/module/battery_saver/parameters/enabled
        fi
    }

    tweak 0 /proc/sys/kernel/split_lock_mitigate

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

    tweak 80 /proc/sys/vm/vfs_cache_pressure

    for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
        if [ -d "$path" ]; then
            if [ "$LITE_MODE" -eq 1 ]; then
                devfreq_mid_perf "$path"
            else
                devfreq_max_perf "$path"
            fi
        fi
    done &

    if [ "$LITE_MODE" -eq 0 ] && [ "$DEVICE_MITIGATION" -eq 0 ]; then
        change_cpu_gov "performance"
    else
        change_cpu_gov "$DEFAULT_CPU_GOV"
    fi

    # Set both PPM and standard cpufreq if PPM exists, otherwise just standard
    if [ -d "/proc/ppm" ]; then
        cpufreq_ppm_max_perf
    fi
    cpufreq_max_perf

    for dir in /sys/block/mmcblk0 /sys/block/mmcblk1 /sys/block/sd*; do
        tweak 32 "$dir/queue/read_ahead_kb"
        tweak 32 "$dir/queue/nr_requests"
    done &
    
    # Apply device-specific tweaks
    case $SOC in
        1) mediatek_performance ;;
        2) snapdragon_performance ;;
        3) exynos_performance ;;
        4) unisoc_performance ;;
        5) tensor_performance ;;
        6) tegra_performance ;;
    esac

	sh $STAR_PATH/BATTERY_RESTORE.sh
	sh $STAR_PATH/CPU_DBPerformance.sh
	sh $STAR_PATH/SF_Performance.sh
    dnd_on
    corin_perf
    bypass_on
    anyamelfissa
}

##########################################
# Balanced Profile (2)
##########################################
balanced_basic() {
    sync
    [ -f /sys/module/battery_saver/parameters/enabled ] && {
        if grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled; then
        kakangkuh 0 /sys/module/battery_saver/parameters/enabled
        else
        kakangkuh N /sys/module/battery_saver/parameters/enabled
        fi
    }

    kakangkuh 1 /proc/sys/kernel/split_lock_mitigate

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

    kakangkuh 120 /proc/sys/vm/vfs_cache_pressure

    for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
        devfreq_unlock "$path"
    done &

    change_cpu_gov "$DEFAULT_CPU_GOV"

    # Set both PPM and standard cpufreq if PPM exists, otherwise just standard
    if [ -d "/proc/ppm" ]; then
        cpufreq_ppm_unlock
    fi
    cpufreq_unlock
    
    # Apply device-specific tweaks
    case $SOC in
        1) mediatek_normal ;;
        2) snapdragon_normal ;;
        3) exynos_normal ;;
        4) unisoc_normal ;;
        5) tensor_normal ;;
        6) tegra_normal ;;
    esac
	
	sh $STAR_PATH/BATTERY_RESTORE.sh
	sh $STAR_PATH/CPU_DBBalance.sh
	sh $STAR_PATH/SF_Smoothness.sh
	dnd_off
    corin_balanced
    bypass_off
    anyakawaii
}

##########################################
# Powersave Profile (3)
##########################################
powersave_basic() {
    sync
    balanced_basic

    [ -f /sys/module/battery_saver/parameters/enabled ] && {
        if grep -qo '[0-9]\+' /sys/module/battery_saver/parameters/enabled; then
            tweak 1 /sys/module/battery_saver/parameters/enabled
        else
            tweak Y /sys/module/battery_saver/parameters/enabled
        fi
    }
    
    for path in /sys/class/devfreq/*.ufshc /sys/class/devfreq/mmc*; do
		devfreq_min_perf "$path"
	done &

    change_cpu_gov "powersave"

    # Set both PPM and standard cpufreq if PPM exists, otherwise just standard
    if [ -d "/proc/ppm" ]; then
        cpufreq_ppm_min_perf
    fi
    cpufreq_min_perf

    # Apply device-specific tweaks
    case $SOC in
        1) mediatek_powersave ;;
        2) snapdragon_powersave ;;
        3) exynos_powersave ;;
        4) unisoc_powersave ;;
        5) tensor_powersave ;;
        6) tegra_powersave ;;
    esac

	sh $STAR_PATH/BATTERY_SAVER.sh
    dnd_off
    corin_powersave
    bypass_off
    anyakawaii
}
##########################################
# MAIN EXECUTION LOGIC
##########################################

if [ -z "$1" ]; then
    echo "Usage: $0 <mode>"
    echo "  1: Performance"
    echo "  2: Balanced"
    echo "  3: Powersave"
    echo "  4: Gaming Pro"
    echo "  5: Cool Down"
    echo "  6: Clear All"
    exit 1
fi

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