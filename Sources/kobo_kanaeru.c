/*
Project Raco - Performance Module (Kobo Kanaeru Fast Charge)
Copyright (C) 2026 Kanagawa Yamada 
*/

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/stat.h>
#include <glob.h>
#include "raco_utils.h"

void kobo_fast_charge() {
    const char* MAX_CURR = "9000000";
    const char* MAX_VOLT = "12000000";
    const char* TEMP_COOL = "150";
    const char* TEMP_HOT = "900";
    const char* TEMP_WARM = "850";

    // CP Paths
    const char* cp_paths[] = {"cp_enable", "cp_switcher_en", "cp_charging_enabled", "slave_chg_enable", "slave_enable"};
    for (int i = 0; i < 5; i++) find_and_tweak("/sys/class/power_supply/", cp_paths[i], "1", 1);
    
    find_and_tweak("/sys/class/power_supply/", "cp_current_limit", MAX_CURR, 1);
    find_and_tweak("/sys/class/power_supply/", "cp_ilim", MAX_CURR, 1);

    // DC Charger
    if (access("/sys/class/power_supply/dc_charger", F_OK) == 0) {
        tweak("1", "/sys/class/power_supply/dc_charger/present");
        tweak("1", "/sys/class/power_supply/dc_charger/online");
        tweak(MAX_CURR, "/sys/class/power_supply/dc_charger/current_max");
    }

    // TypeC Paths
    if (access("/sys/class/typec/port0", F_OK) == 0) {
        if (access("/sys/class/typec/port0/power_operation_mode", F_OK) == 0) {
            chmod("/sys/class/typec/port0/power_operation_mode", 0666);
        }
        tweak("sink", "/sys/class/typec/port0/power_role");
        tweak("1", "/sys/class/typec/port0/vbus_vsafe0v");
    }

    // Module Paths (SMB & PHY)
    const char* mod_paths[] = {
        "/sys/module/qpnp_smb2/parameters", "/sys/module/qpnp_smb5/parameters",
        "/sys/module/smb1351_charger/parameters", "/sys/module/smb1355_charger/parameters",
        "/sys/module/smb_lib/parameters", "/sys/module/phy_msm_usb/parameters"
    };
    for(int i = 0; i < 6; i++) {
        char path[256];
        snprintf(path, sizeof(path), "%s/aicl_enable", mod_paths[i]); tweak("0", path);
        snprintf(path, sizeof(path), "%s/hvdcp3_allowed", mod_paths[i]); tweak("1", path);
        snprintf(path, sizeof(path), "%s/step_charging_enable", mod_paths[i]); tweak("1", path);
        snprintf(path, sizeof(path), "%s/usb_in_suspend", mod_paths[i]); tweak("0", path);
        snprintf(path, sizeof(path), "%s/skip_usb_suspend_for_fake_battery", mod_paths[i]); tweak("1", path);
    }

    // VOOC Paths
    if (access("/proc/vooc_mp", F_OK) == 0) tweak("1", "/proc/vooc_mp/allow_reading");
    if (access("/sys/class/power_supply/vooc", F_OK) == 0) {
        tweak("1", "/sys/class/power_supply/vooc/fast_chg_ing");
        tweak("1", "/sys/class/power_supply/vooc/allow_reading");
    }

    // Thermal Zone Disabling
    glob_t gbuf;
    if (glob("/sys/class/thermal/thermal_zone*/mode", 0, NULL, &gbuf) == 0) {
        for(size_t i = 0; i < gbuf.gl_pathc; i++) tweak("disabled", gbuf.gl_pathv[i]);
        globfree(&gbuf);
    }
    
    find_and_tweak("/sys/class/power_supply/", "skin_temp_mitigation", "0", 1);
    find_and_tweak("/sys/class/power_supply/", "connector_temp_mitigation", "0", 1);
    
    // Thermal Limitations Override
    find_and_tweak("/sys/class/power_supply/", "temp_cool", TEMP_COOL, 1);
    find_and_tweak("/sys/class/power_supply/", "temp_hot", TEMP_HOT, 1);
    find_and_tweak("/sys/class/power_supply/", "temp_warm", TEMP_WARM, 1);
    find_and_tweak("/sys/class/power_supply/", "temp_ambient", TEMP_COOL, 1);

    // Fast Charge Features Array
    const char* features[] = {
        "fast_charge", "boost_mode", "turbo_mode", "pd_allowed", "allow_hvdcp3", 
        "hvdcp_opti", "quick_charge_mode", "pump_express_enable", "fast_chg_type", 
        "mtk_pulse_enable", "pd_active", "force_demo_mode", "toggle_stat", "aicl_done"
    };
    for(int i = 0; i < 14; i++) find_and_tweak("/sys/class/power_supply/", features[i], "1", 1);

    // Current Limits Array
    const char* limits[] = {
        "current_max", "constant_charge_current", "constant_charge_current_max", 
        "input_current_limit", "input_current_max", "hw_current_max", "pd_current_max", 
        "ctm_current_max", "sdp_current_max", "restricted_current", "main_current_max", 
        "usb_current_max", "fc_current_limit", "fast_charge_current_limit", 
        "vbus_current_max", "screen_on_current_limit"
    };
    for(int i = 0; i < 16; i++) find_and_tweak("/sys/class/power_supply/", limits[i], MAX_CURR, 1);

    // Voltages Array
    const char* voltages[] = {
        "input_voltage_limit", "input_voltage_max", "voltage_max", 
        "voltage_max_design", "constant_charge_voltage_max", "vbus_voltage_max"
    };
    for(int i = 0; i < 6; i++) find_and_tweak("/sys/class/power_supply/", voltages[i], MAX_VOLT, 1);

    // Disable Safety Checks
    const char* safeties[] = {
        "step_charging_enabled", "sw_jeita_enabled", "jeita_arise_throttled", 
        "soft_jeita_btn_enabled", "aicl_enable", "input_suspend", "charge_disable", 
        "safety_timer_enabled"
    };
    for(int i = 0; i < 8; i++) find_and_tweak("/sys/class/power_supply/", safeties[i], "0", 1);

    // Vendor Specific Batteries (MTK, QCOM, SEC)
    if (access("/sys/devices/mtk-battery", F_OK) == 0 || access("/sys/bus/platform/drivers/mtk-battery", F_OK) == 0) {
        tweak(MAX_CURR, "/sys/devices/mtk-battery/restricted_current");
        tweak(MAX_CURR, "/sys/devices/mtk-battery/fc_current_limit");
        tweak("1", "/sys/devices/mtk-battery/pump_express_enable");
    }

    if (access("/sys/class/qcom-battery", F_OK) == 0) {
        tweak("0", "/sys/class/qcom-battery/restricted_charging");
        tweak("0", "/sys/class/qcom-battery/restrict_chg");
        tweak(MAX_CURR, "/sys/class/qcom-battery/restricted_current");
        if (access("/sys/class/qcom-battery/rerun_aicl", F_OK) == 0) {
            tweak("1", "/sys/class/qcom-battery/rerun_aicl");
        }
    }

    if (access("/sys/class/power_supply/sec-charger", F_OK) == 0) {
        tweak(MAX_CURR, "/sys/class/power_supply/sec-charger/input_current_max");
        tweak("0", "/sys/class/power_supply/sec-charger/otg_enable");
    }

    // Misc Settings
    find_and_tweak("/sys/class/power_supply/usb/", "real_type", "DCP", 1);
    find_and_tweak("/sys/class/power_supply/", "store_mode", "0", 1);
    find_and_tweak("/sys/class/power_supply/", "batt_slate_mode", "0", 1);

    tweak("0", "/sys/class/power_supply/battery/input_current_limited");
    tweak("1", "/sys/class/power_supply/battery/input_current_settled");
    tweak("100", "/sys/class/power_supply/battery/siop_level");
    tweak("0", "/sys/class/power_supply/battery/charge_control_limit_max");
}

int main(int argc, char *argv[]) {
    printf("[*] Executing Kobo Kanaeru Fast Charge Optimizations...\n");
    kobo_fast_charge();
    printf("[+] Kobo Kanaeru applied successfully.\n");
    return 0;
}