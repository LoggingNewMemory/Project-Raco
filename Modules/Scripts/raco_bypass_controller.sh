#!/system/bin/sh
# ---------------------------------------------------------
# Project Raco - Integrated Bypass Controller
# Stores cache directly in raco.txt
# Updated with ACC paths & Multi-method execution
# Sources: VR-25 (ACC), XDA, Kernel Sources
# ---------------------------------------------------------

CONFIG_FILE="/data/ProjectRaco/raco.txt"
LOG_TAG="RacoBypass"

# ---------------------------------------------------------
# DATABASE: known_methods
# Format: "PATH|VALUE_TO_ENABLE_BYPASS|VALUE_TO_DISABLE_BYPASS"
# (Column 2 = Stop Charging / Enable Bypass)
# (Column 3 = Start Charging / Disable Bypass)
# ---------------------------------------------------------
get_database() {
cat <<EOF
# Generic / Universal (Standard Linux Power Supply Class)
/sys/class/power_supply/battery/charging_enabled|0|1
/sys/class/power_supply/main/charging_enabled|0|1
/sys/class/power_supply/battery/batt_charging_enabled|0|1

# Xiaomi / POCO / OnePlus (Qualcomm & MediaTek)
/sys/class/power_supply/battery/battery_charging_enabled|0|1

# Google Pixel (Pixel 3 through Pixel 7/8 series)
/sys/class/power_supply/battery/charge_disable|1|0
/sys/devices/platform/google,battery/power_supply/battery/charge_disable|1|0
/sys/class/power_supply/google_charger/charge_start_level|0|100

# Samsung (Galaxy Series - Stops charging but keeps USB power)
# batt_slate_mode: 1 = Retail/Demo Mode (Stops Charging), 0 = Normal
/sys/class/power_supply/battery/batt_slate_mode|1|0
/sys/class/power_supply/battery/store_mode|1|0

# Motorola
/sys/class/power_supply/battery/mmi_charging_enable|0|1

# ASUS (ROG Phone / ZenFone - Hardware Bypass Support)
/sys/class/power_supply/battery/device/bypass_charging|1|0
/sys/class/power_supply/battery/ide_mode|1|0

# Huawei / Honor
/sys/class/power_supply/battery/mmi_charging_enable|0|1
/sys/class/power_supply/bms/battery_charging_enabled|0|1

# Lenovo
/sys/class/power_supply/battery/conservation_mode|1|0
EOF
}

# ---------------------------------------------------------
# HELPER FUNCTIONS
# ---------------------------------------------------------

log_msg() {
    echo "$@"
}

# Reads the BYPASS_SUPP value from raco.txt
get_cached_config() {
    if [ -f "$CONFIG_FILE" ]; then
        grep "^BYPASS_SUPP=" "$CONFIG_FILE" | cut -d'=' -f2-
    fi
}

# Writes the new method(s) to raco.txt
# Supports multiple paths separated by ';;'
save_to_config() {
    local new_val="$1"
    
    # Check if BYPASS_SUPP exists in the file
    if grep -q "^BYPASS_SUPP=" "$CONFIG_FILE"; then
        # Use a different delimiter (#) for sed because new_val contains pipes and semicolons
        sed -i "s#^BYPASS_SUPP=.*#BYPASS_SUPP=$new_val#" "$CONFIG_FILE"
    else
        # If key doesn't exist, append it
        echo "BYPASS_SUPP=$new_val" >> "$CONFIG_FILE"
    fi
}

# ---------------------------------------------------------
# CORE LOGIC
# ---------------------------------------------------------

# Scans ALL methods and accumulates valid ones
scan_and_update() {
    log_msg "Scanning for ALL supported bypass methods..."
    
    local found_methods=""
    local found_count=0
    
    # Read database line by line
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        # Skip comments
        case "$line" in \#*) continue ;; esac
        
        # Parse line: Path|Enable|Disable
        local path=$(echo "$line" | cut -d'|' -f1)
        
        # Check if path exists and is writable
        if [ -w "$path" ]; then
            # Append to found_methods with delimiter ';;'
            if [ -z "$found_methods" ]; then
                found_methods="$line"
            else
                found_methods="${found_methods};;${line}"
            fi
            found_count=$((found_count + 1))
        fi
    done <<EOF
$(get_database)
EOF

    if [ -n "$found_methods" ]; then
        log_msg "Found $found_count supported method(s)."
        save_to_config "$found_methods"
        return 0
    else
        log_msg "No supported bypass method found."
        save_to_config ""
        return 1
    fi
}

apply_bypass() {
    local action="$1" # enable or disable
    
    # 1. Read from raco.txt
    local cached_data=$(get_cached_config)
    
    # 2. If empty, scan
    if [ -z "$cached_data" ]; then
        scan_and_update
        # Re-read after scan
        cached_data=$(get_cached_config)
        
        # If still empty, we failed
        if [ -z "$cached_data" ]; then
            echo "unsupported"
            return 1
        fi
    fi
    
    # 3. Iterate through ALL cached methods
    # Delimiter is ';;'
    local original_ifs="$IFS"
    
    local success_count=0
    
    # Normalize string for loop (replace ;; with newline)
    local methods_list=$(echo "$cached_data" | sed 's/;;/\n/g')
    
    IFS='
'
    for method_line in $methods_list; do
        [ -z "$method_line" ] && continue
        
        # Restore standard IFS for parsing the individual line
        IFS="$original_ifs"
        
        # Parse the line: path|enable_val|disable_val
        local path=$(echo "$method_line" | cut -d'|' -f1)
        local en_val=$(echo "$method_line" | cut -d'|' -f2)
        local dis_val=$(echo "$method_line" | cut -d'|' -f3)

        # Validate path existence
        if [ ! -w "$path" ]; then
            log_msg "Warning: Saved path ($path) not writable. Skipping."
            continue
        fi

        # Determine value to write
        local target_val=""
        if [ "$action" = "enable" ]; then
            target_val="$en_val"
        else
            target_val="$dis_val"
        fi

        # Apply
        log_msg "Applying $action to $path..."
        echo "$target_val" > "$path"
        
        if [ $? -eq 0 ]; then
            success_count=$((success_count + 1))
        fi
        
        # Set IFS back to newline for the outer loop
        IFS='
'
    done
    
    IFS="$original_ifs"

    # 4. Result
    if [ "$success_count" -gt 0 ]; then
        echo "success"
        return 0
    else
        # If we failed but had cached data, the paths might have changed (e.g. system update/reboot)
        # Try a force rescan once
        log_msg "All cached methods failed. Attempting re-scan..."
        save_to_config ""
        scan_and_update
        local new_data=$(get_cached_config)
        
        if [ -n "$new_data" ] && [ "$new_data" != "$cached_data" ]; then
             echo "rescan_needed_retry"
             return 1
        fi
        
        echo "fail"
        return 1
    fi
}

# ---------------------------------------------------------
# MAIN
# ---------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
    echo "Root required." >&2
    exit 1
fi

# Ensure config file exists
if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$(dirname "$CONFIG_FILE")"
    touch "$CONFIG_FILE"
fi

case "$1" in
    test)
        # Force a refresh
        save_to_config ""
        if scan_and_update; then
            echo "supported"
        else
            echo "unsupported"
        fi
        ;;
    
    enable)
        apply_bypass "enable"
        ;;
    
    disable)
        apply_bypass "disable"
        ;;
        
    *)
        echo "Usage: $0 {test|enable|disable}"
        exit 1
        ;;
esac

exit 0