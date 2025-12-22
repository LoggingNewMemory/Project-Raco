tweak() {
    if [ -e "$2" ]; then
        chmod 644 "$2" >/dev/null 2>&1
        echo "$1" > "$2" 2>/dev/null
        chmod 444 "$2" >/dev/null 2>&1
    fi
}

corin_perf() {
# FreakZy Storage

tweak "deadline" "$deviceio/queue/scheduler"
tweak 1 "$queue/rq_affinity"

# GPU Tweaks (From performance.sh)
tweak "performance" "/sys/class/devfreq/mtk-dvfsrc-devfreq/governor"
tweak "performance" "/sys/class/devfreq/13000000.mali/governor"
tweak "0" "/proc/trans_scheduler/enable"
tweak "1" "/proc/game_state"
tweak "always_on" "/sys/class/misc/mali0/device/power_policy"
tweak "enable" "/proc/gpufreqv2/aging_mode"

# Settings Set | Supposed All Devices Have

# Optimize Priority
settings put secure high_priority 1 > /dev/null 2>&1
settings put secure low_priority 0 > /dev/null 2>&1

# From MTKVest

cmd power set-adaptive-power-saver-enabled false > /dev/null 2>&1
cmd power set-fixed-performance-mode-enabled true > /dev/null 2>&1

# From Corin 
cmd looper_stats disable > /dev/null 2>&1

# Power Save Mode Off
settings put global low_power 0 > /dev/null 2>&1
}

corin_balanced() {
# FreakZy Storage

tweak "deadline" "$deviceio/queue/scheduler"
tweak 1 "$queue/rq_affinity"

# GPU Tweaks (From allrounder.sh)
tweak "simple_ondemand" "/sys/class/devfreq/mtk-dvfsrc-devfreq/governor"
tweak "simple_ondemand" "/sys/class/devfreq/13000000.mali/governor"
tweak "1" "/proc/trans_scheduler/enable"
tweak "0" "/proc/game_state"
tweak "coarse_demand" "/sys/class/misc/mali0/device/power_policy"
tweak "enable" "/proc/gpufreqv2/aging_mode"

# Settings Set | Supposed All Devices Have

# Optimize Priority
settings put secure high_priority 1 > /dev/null 2>&1
settings put secure low_priority 0 > /dev/null 2>&1

# From MTKVest

cmd power set-adaptive-power-saver-enabled false > /dev/null 2>&1
cmd power set-fixed-performance-mode-enabled false > /dev/null 2>&1

# From Corin 
cmd looper_stats enable > /dev/null 2>&1

# Power Save Mode Off
settings put global low_power 0 > /dev/null 2>&1
}

corin_powersave() {
# FreakZy Storage

tweak "deadline" "$deviceio/queue/scheduler"
tweak 2 "$queue/rq_affinity"

# GPU Tweaks (From battery.sh)
tweak "powersave" "/sys/class/devfreq/mtk-dvfsrc-devfreq/governor"
tweak "powersave" "/sys/class/devfreq/13000000.mali/governor"
tweak "1" "/proc/trans_scheduler/enable"
tweak "0" "/proc/game_state"
tweak "coarse_demand" "/sys/class/misc/mali0/device/power_policy"
tweak "enable" "/proc/gpufreqv2/aging_mode"

# Settings Set | Supposed All Devices Have

# Optimize Priority
settings put secure high_priority 0 > /dev/null 2>&1
settings put secure low_priority 1 > /dev/null 2>&1

# From MTKVest

cmd power set-adaptive-power-saver-enabled true > /dev/null 2>&1
cmd power set-fixed-performance-mode-enabled false > /dev/null 2>&1

# From Corin 
cmd looper_stats enable > /dev/null 2>&1

# Power Save Mode On
settings put global low_power 1 > /dev/null 2>&1
}