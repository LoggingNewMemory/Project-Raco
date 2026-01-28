#!/system/bin/sh
# ---------------------------------------------------------
# Project Raco - Integrated Bypass Controller
# Stores cache directly in raco.txt
# ---------------------------------------------------------

CONFIG_FILE="/data/ProjectRaco/raco.txt"
LOG_TAG="RacoBypass"

# ---------------------------------------------------------
# DATABASE: known_methods
# Format: "PATH|VALUE_TO_ENABLE_BYPASS|VALUE_TO_DISABLE_BYPASS"
# ---------------------------------------------------------
get_database() {
cat <<EOF
/sys/class/oplus_chg/battery/mmi_charging_enable|0|1
/sys/devices/platform/soc/soc:oplus,chg_intf/oplus_chg/battery/mmi_charging_enable|0|1
/sys/devices/virtual/oplus_chg/battery/mmi_charging_enable|0|1
/proc/oplus_chg/battery/mmi_charging_enable|0|1
/sys/class/power_supply/battery/mmi_charging_enable|0|1
/sys/class/power_supply/battery/batt_slate_mode|1|0
/sys/class/power_supply/battery/input_suspend|1|0
/sys/class/power_supply/battery/battery_input_suspend|1|0
/sys/class/power_supply/battery/charge_disable|1|0
/sys/class/power_supply/battery/charging_enabled|0|1
/sys/class/power_supply/battery/battery_charging_enabled|0|1
/sys/devices/platform/google,charger/charge_stop_level|100|0
/sys/class/power_supply/battery/charge_control_limit_max|0|1
/sys/devices/platform/soc/soc:google,charger/charge_disable|1|0
/sys/class/power_supply/battery/constant_charge_current_max|0|2000000
/sys/class/power_supply/battery/store_mode|1|0
/sys/class/power_supply/battery/test_mode|1|0
/sys/class/asuslib/charger_limit_en|1|0
/sys/class/asuslib/charging_suspend_en|1|0
/sys/class/hw_power/charger/charge_data/enable_charger|0|1
/proc/mtk_battery_cmd/en_power_path|0|1
/sys/devices/platform/charger/bypass_charger|1|0
/sys/kernel/nubia_charge/charger_bypass|on|off
/sys/class/qcom-battery/input_suspend|1|0
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

# Writes the new method to raco.txt
save_to_config() {
    local new_val="$1"
    
    # Check if BYPASS_SUPP exists in the file
    if grep -q "^BYPASS_SUPP=" "$CONFIG_FILE"; then
        # Use a different delimiter (#) for sed because new_val contains pipes (|)
        sed -i "s#^BYPASS_SUPP=.*#BYPASS_SUPP=$new_val#" "$CONFIG_FILE"
    else
        # If key doesn't exist, append it
        echo "BYPASS_SUPP=$new_val" >> "$CONFIG_FILE"
    fi
}

# ---------------------------------------------------------
# CORE LOGIC
# ---------------------------------------------------------

scan_and_update() {
    log_msg "Scanning for supported bypass methods..."
    
    get_database | while IFS= read -r line; do
        [ -z "$line" ] && continue
        
        # Parse line: Path|Enable|Disable
        local path=$(echo "$line" | cut -d'|' -f1)
        
        # Check if path exists and is writable
        if [ -w "$path" ]; then
            log_msg "Method Found: $path"
            
            # Save the WHOLE line (Path|Enable|Disable) to raco.txt
            save_to_config "$line"
            return 0
        fi
    done

    log_msg "No supported bypass method found."
    return 1
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
    
    # 3. Parse the cached data
    # format: path|enable_val|disable_val
    local path=$(echo "$cached_data" | cut -d'|' -f1)
    local en_val=$(echo "$cached_data" | cut -d'|' -f2)
    local dis_val=$(echo "$cached_data" | cut -d'|' -f3)

    # 4. Validate path existence (Self-Healing)
    if [ ! -w "$path" ]; then
        log_msg "Saved path ($path) not writable. Re-scanning..."
        # Clear the config line
        save_to_config ""
        # Retry logic recursively once
        scan_and_update && apply_bypass "$action"
        return $?
    fi

    # 5. Determine value to write
    local target_val=""
    if [ "$action" = "enable" ]; then
        target_val="$en_val"
    else
        target_val="$dis_val"
    fi

    # 6. Apply
    echo "$target_val" > "$path"
    
    # Basic verification
    if [ $? -eq 0 ]; then
        echo "success"
        return 0
    else
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