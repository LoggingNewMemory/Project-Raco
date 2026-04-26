#################################
# Modified Kobo Fast Charge
# Modified By: @Koneko_dev
#################################

#!/system/bin/sh

CURRENT_MAX=9000000
VOLTAGE_MAX=12000000
TEMP_COOL=150
TEMP_HOT=900
TEMP_WARM=850

lock_val() {
    if [ -e "$2" ]; then
        chmod 0666 "$2" >/dev/null 2>&1
        echo "$1" > "$2" 2>/dev/null
        chmod 0444 "$2" >/dev/null 2>&1
    fi
}

CP_PATHS="cp_enable cp_switcher_en cp_charging_enabled slave_chg_enable slave_enable"

for cp in $CP_PATHS; do
    find /sys/class/power_supply/ -name "$cp" 2>/dev/null | while read path; do
        lock_val "1" "$path"
    done
done

find /sys/class/power_supply/ -name "cp_current_limit" -o -name "cp_ilim" 2>/dev/null | while read path; do
    lock_val "$CURRENT_MAX" "$path"
done

if [ -d "/sys/class/power_supply/dc_charger" ]; then
    lock_val "1" "/sys/class/power_supply/dc_charger/present"
    lock_val "1" "/sys/class/power_supply/dc_charger/online"
    lock_val "$CURRENT_MAX" "/sys/class/power_supply/dc_charger/current_max"
fi

TYPEC_PATH="/sys/class/typec/port0"
if [ -d "$TYPEC_PATH" ]; then
    if [ -f "$TYPEC_PATH/power_operation_mode" ]; then
        chmod 0666 "$TYPEC_PATH/power_operation_mode"
    fi
    lock_val "sink" "$TYPEC_PATH/power_role"
    lock_val "1" "$TYPEC_PATH/vbus_vsafe0v"
fi

MODULE_PATHS="/sys/module/qpnp_smb2/parameters
/sys/module/qpnp_smb5/parameters
/sys/module/smb1351_charger/parameters
/sys/module/smb1355_charger/parameters
/sys/module/smb_lib/parameters
/sys/module/phy_msm_usb/parameters"

for mod_path in $MODULE_PATHS; do
    lock_val "0" "$mod_path/aicl_enable"
    lock_val "1" "$mod_path/hvdcp3_allowed"
    lock_val "1" "$mod_path/step_charging_enable"
    lock_val "0" "$mod_path/usb_in_suspend"
    lock_val "1" "$mod_path/skip_usb_suspend_for_fake_battery"
done

if [ -d "/proc/vooc_mp" ]; then
    lock_val "1" "/proc/vooc_mp/allow_reading"
fi
if [ -d "/sys/class/power_supply/vooc" ]; then
    lock_val "1" "/sys/class/power_supply/vooc/fast_chg_ing"
    lock_val "1" "/sys/class/power_supply/vooc/allow_reading"
fi

for zone in /sys/class/thermal/thermal_zone*/mode; do
    lock_val "disabled" "$zone"
done

find /sys/class/power_supply/ -name "skin_temp_mitigation" -o -name "connector_temp_mitigation" 2>/dev/null | while read path; do
    lock_val "0" "$path"
done

find /sys/ -name "temp_cool" -o -name "temp_hot" -o -name "temp_warm" -o -name "temp_ambient" 2>/dev/null | while read path; do
    case "$path" in
        *"cool"*) lock_val "$TEMP_COOL" "$path" ;;
        *"hot"*)  lock_val "$TEMP_HOT"  "$path" ;;
        *"warm"*) lock_val "$TEMP_WARM" "$path" ;;
        *"ambient"*) lock_val "$TEMP_COOL" "$path" ;;
    esac
done

FEATURES="fast_charge boost_mode turbo_mode pd_allowed allow_hvdcp3 hvdcp_opti quick_charge_mode pump_express_enable fast_chg_type mtk_pulse_enable pd_active force_demo_mode toggle_stat aicl_done"

for feature in $FEATURES; do
    find /sys/class/power_supply/ -name "$feature" 2>/dev/null | while read path; do
        lock_val "1" "$path"
    done
done

LIMITS="current_max constant_charge_current constant_charge_current_max input_current_limit input_current_max hw_current_max pd_current_max ctm_current_max sdp_current_max restricted_current main_current_max usb_current_max fc_current_limit fast_charge_current_limit vbus_current_max screen_on_current_limit"

for limit in $LIMITS; do
    find /sys/class/power_supply/ -name "$limit" 2>/dev/null | while read path; do
        lock_val "$CURRENT_MAX" "$path"
    done
done

VOLTAGES="input_voltage_limit input_voltage_max voltage_max voltage_max_design constant_charge_voltage_max vbus_voltage_max"

find /sys/class/power_supply/ -name "$VOLTAGES" 2>/dev/null | while read path; do
    lock_val "$VOLTAGE_MAX" "$path"
done

DISABLE_SAFETY="step_charging_enabled sw_jeita_enabled jeita_arise_throttled soft_jeita_btn_enabled aicl_enable input_suspend charge_disable safety_timer_enabled"
for safety in $DISABLE_SAFETY; do
    find /sys/class/power_supply/ -name "$safety" 2>/dev/null | while read path; do
        lock_val "0" "$path"
    done
done

if [ -d "/sys/devices/mtk-battery" ] || [ -d "/sys/bus/platform/drivers/mtk-battery" ]; then
    lock_val "$CURRENT_MAX" "/sys/devices/mtk-battery/restricted_current"
    lock_val "$CURRENT_MAX" "/sys/devices/mtk-battery/fc_current_limit"
    lock_val "1" "/sys/devices/mtk-battery/pump_express_enable"
fi

if [ -d "/sys/class/qcom-battery" ]; then
    lock_val "0" "/sys/class/qcom-battery/restricted_charging"
    lock_val "0" "/sys/class/qcom-battery/restrict_chg"
    lock_val "$CURRENT_MAX" "/sys/class/qcom-battery/restricted_current"
    if [ -f "/sys/class/qcom-battery/rerun_aicl" ]; then
        echo "1" > "/sys/class/qcom-battery/rerun_aicl" 
    fi
fi

if [ -d "/sys/class/power_supply/sec-charger" ]; then
    lock_val "$CURRENT_MAX" "/sys/class/power_supply/sec-charger/input_current_max"
    lock_val "0" "/sys/class/power_supply/sec-charger/otg_enable"
fi

find /sys/class/power_supply/usb/ -name "real_type" 2>/dev/null | while read path; do
    lock_val "DCP" "$path"
done

find /sys/ -name "store_mode" -o -name "batt_slate_mode" 2>/dev/null | while read path; do
    lock_val "0" "$path"
done

lock_val "0" "/sys/class/power_supply/battery/input_current_limited"
lock_val "1" "/sys/class/power_supply/battery/input_current_settled"
lock_val "100" "/sys/class/power_supply/battery/siop_level"
lock_val "0" "/sys/class/power_supply/battery/charge_control_limit_max"