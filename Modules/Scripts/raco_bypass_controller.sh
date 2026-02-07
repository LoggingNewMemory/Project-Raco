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
# --- Universal / Generic ---
/sys/class/power_supply/battery/input_suspend|1|0
/sys/class/power_supply/battery/battery_input_suspend|1|0
/sys/class/power_supply/battery/charge_disable|1|0
/sys/class/power_supply/battery/charging_enabled|0|1
/sys/class/power_supply/battery/charge_enabled|0|1
/sys/class/power_supply/battery/battery_charging_enabled|0|1
/sys/class/power_supply/battery/device/Charging_Enable|0|1
/sys/class/power_supply/ac/charging_enabled|0|1
/sys/class/power_supply/charge_data/enable_charger|0|1
/sys/class/power_supply/dc/charging_enabled|0|1
/sys/class/power_supply/main/charging_enabled|0|1
/sys/class/power_supply/usb/charging_enabled|0|1
/sys/class/power_supply/battery/stop_charge|1|0
/sys/class/power_supply/battery/pause_charging|1|0

# --- Oppo / OnePlus / Realme (VOOC/SuperVOOC) ---
/sys/class/oplus_chg/battery/mmi_charging_enable|0|1
/sys/class/power_supply/battery/mmi_charging_enable|0|1
/sys/devices/virtual/oplus_chg/battery/mmi_charging_enable|0|1
/sys/devices/platform/soc/soc:oplus,chg_intf/oplus_chg/battery/mmi_charging_enable|0|1
/sys/devices/platform/soc/soc:oplus,chg_intf/oplus_chg/battery/chg_enable|0|1
/sys/devices/platform/soc/soc:oplus,chg_intf/oplus_chg/battery/cool_down|1|0
/proc/fastchg_fw_update|1|0

# --- Xiaomi / Poco / Redmi (MIUI/HyperOS) ---
/sys/class/power_supply/battery/constant_charge_current_max|0|2200000
/sys/class/power_supply/battery/input_current_limit|0|3000000
/sys/class/qcom-battery/input_suspend|1|0
/sys/class/qcom-battery/charging_enabled|0|1
/sys/class/qcom-battery/cool_mode|1|0
/sys/class/qcom-battery/batt_protect_en|1|0
/proc/mtk_battery_cmd/current_cmd|0 1|0 0
/proc/mtk_battery_cmd/en_power_path|0|1

# --- Asus (ROG / Zenfone) ---
/sys/class/asuslib/bypass_charging|1|0
/sys/class/asuslib/enter_bypass|1|0
/sys/class/asuslib/charger_limit_en|1|0
/sys/class/asuslib/charging_suspend_en|1|0
/proc/driver/charger_limit_enable|1|0
/proc/driver/charger_limit|5|100

# --- Google Pixel ---
/sys/devices/platform/google,charger/charge_disable|1|0
/sys/devices/platform/google,battery/power_supply/battery/charge_disable|1|0
/sys/kernel/debug/google_charger/chg_suspend|1|0
/sys/kernel/debug/google_charger/input_suspend|1|0
/sys/devices/platform/soc/soc:google,charger/charge_disable|1|0
/sys/devices/platform/soc/soc:google,charger/charge_stop_level|0|100

# --- Samsung ---
/sys/class/power_supply/battery/batt_slate_mode|1|0
/sys/class/power_supply/battery/store_mode|1|0
/sys/class/power_supply/battery/test_mode|1|2
/sys/class/power_supply/battery/siop_level|0|100
/sys/class/power_supply/battery_ext/smart_charging_interruption|1|0
/sys/class/power_supply/battery/restricted_charging|1|0
/sys/class/power_supply/wireless/restricted_charging|1|0

# --- Huawei / Honor ---
/sys/devices/platform/huawei_charger/enable_charger|0|1
/sys/class/hw_power/charger/charge_data/enable_charger|0|1
/sys/class/power_supply/battery/hmt_ta_charge|0|1

# --- MediaTek / Misc Kernel Nodes ---
/sys/devices/platform/charger/bypass_charger|1|0
/sys/devices/platform/charger/tran_aichg_disable_charger|1|0
/sys/devices/platform/mt-battery/disable_charger|1|0
/sys/devices/platform/omap/omap_i2c.3/i2c-3/3-005f/charge_enable|0|1
/sys/devices/soc/qpnp-smbcharger-18/power_supply/battery/battery_charging_enabled|0|1
/sys/devices/platform/tegra12-i2c.0/i2c-0/0-006b/charging_state|disabled|enabled
/sys/module/pmic8058_charger/parameters/disabled|1|0
/sys/module/pm8921_charger/parameters/disabled|1|0
/sys/module/smb137b/parameters/disabled|1|0
/proc/smb1357_disable_chrg|1|0
/sys/class/power_supply/bq2589x_charger/enable_charging|0|1
/sys/devices/platform/soc/soc:qcom,pmic_glink/soc:qcom,pmic_glink:qcom,battery_charger/force_charger_suspend|1|0
/sys/kernel/nubia_charge/charger_bypass|on|off
/sys/devices/platform/lge-unified-nodes/charging_enable|0|1
/sys/devices/platform/lge-unified-nodes/charging_completed|1|0
/sys/module/lge_battery/parameters/charge_stop_level|5|100
/sys/devices/virtual/power_supply/manta-battery/charge_enabled|0|1
/sys/devices/platform/battery/CCIChargerSwitch|0|1
/sys/module/qpnp_adaptive_charge/parameters/blocking|1|0
/sys/kernel/debug/google_charger/chg_mode|0|1
/sys/class/power_supply/battery/bd_trickle_cnt|1|0
/sys/class/power_supply/idt/pin_enabled|1|0
/sys/class/power_supply/battery/charge_charger_state|1|0
/sys/class/power_supply/main/adapter_cc_mode|1|0
/sys/class/power_supply/maxfg/offmode_charger|1|0
/sys/class/power_supply/main/cool_mode|1|0
/sys/class/power_supply/battery/charge_control_limit_max|1|0
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
    # We use a file descriptor to avoid subshell variable loss issues
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