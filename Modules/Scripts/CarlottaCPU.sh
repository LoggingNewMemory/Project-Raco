#!/system/bin/sh

setprop debug.hwui.use_hint_manager true
setprop debug.sf.enable_adpf_cpu_hint true

# Internal function to get the number of CPU cores
_get_num_cores() {
    local cores=0
    if [ -r /proc/cpuinfo ]; then
        while read -r line; do
            case "$line" in
                processor*) cores=$((cores + 1)) ;;
                *) continue ;;
            esac
        done < /proc/cpuinfo
    fi
    [ "$cores" -eq 0 ] && cores=1 
    echo "$cores"
}

# Calculate the number of cores once and store it
_num_cores=$(_get_num_cores)

# Internal function to calculate current CPU load
_get_cpu_load() {
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat 2>/dev/null || { echo 0; return; }
    local total1=$((user + nice + system + idle + iowait + irq + softirq + steal + 0))  
    local idle1=$((idle + iowait))

    sleep 0.1 

    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat 2>/dev/null || { echo 0; return; }
    local total2=$((user + nice + system + idle + iowait + irq + softirq + steal + 0))
    local idle2=$((idle + iowait))

    local diff_total=$((total2 - total1))
    local diff_idle=$((idle2 - idle1))

    if [ "$diff_total" -eq 0 ]; then
        echo 0
    else
        local load=$((1000 * (diff_total - diff_idle) / diff_total))  
        local adjusted_load=$((load / 10))  
        [ "$_num_cores" -gt 8 ] && adjusted_load=$((adjusted_load * 8 / _num_cores))  
        echo "$adjusted_load"
    fi
}

carcpu_perf() {
    local hardlock=80 # High ceiling for maximum performance
    local current_load=$(_get_cpu_load)
    local target_percent

    if [ "$current_load" -gt "$hardlock" ]; then
        target_percent="$hardlock"
    else
        target_percent="$current_load"
    fi
    
    setprop debug.hwui.target_cpu_time_percent "$target_percent"

    # Adjust the script's own priority to be non-intrusive
    iorenice $$ 7 idle
    renice -n 19 -p $$
    taskset -ap 1 $$
}

carcpu_balance() {
    local hardlock=55 
    local current_load=$(_get_cpu_load)
    local target_percent

    if [ "$current_load" -gt "$hardlock" ]; then
        target_percent="$hardlock"
    else
        target_percent="$current_load"
    fi

    setprop debug.hwui.target_cpu_time_percent "$target_percent"

    # Adjust the script's own priority to be non-intrusive
    iorenice $$ 7 idle
    renice -n 19 -p $$
    taskset -ap 1 $$
}

carcpu_battery() {
    local hardlock=40 
    local current_load=$(_get_cpu_load)
    local target_percent

    if [ "$current_load" -gt "$hardlock" ]; then
        target_percent="$hardlock"
    else
        target_percent="$current_load"
    fi

    setprop debug.hwui.target_cpu_time_percent "$target_percent"

    # Adjust the script's own priority to be non-intrusive
    iorenice $$ 7 idle
    renice -n 19 -p $$
    taskset -ap 1 $$
}
