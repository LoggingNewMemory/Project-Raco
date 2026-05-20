/*
Project Raco - Kobo Fast Gen 2
Copyright (C) 2026 Kanagawa Yamada 
*/

#include "raco.h"

const char *CURRENT_MAX = "9000000";
const char *VOLTAGE_MAX = "12000000";
const char *TEMP_COOL = "150";
const char *TEMP_WARM = "850";
const char *TEMP_HOT = "900";

// Tools
void apply_to_power_supply(const char *filename, const char *val) {
    DIR *dir;
    struct dirent *ent;
    
    if ((dir = opendir("/sys/class/power_supply")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (ent->d_name[0] != '.') {
                char path[256];
                snprintf(path, sizeof(path), "/sys/class/power_supply/%s/%s", ent->d_name, filename);
                
                if (access(path, F_OK) == 0) {
                    rawrite(val, path);
                }
            } 
        }
        closedir(dir);
    }
}

void apply_to_thermal(const char *filename, const char *val) {
    DIR *dir;
    struct dirent *ent;
    
    if ((dir = opendir("/sys/class/thermal")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "thermal_zone", 12) == 0) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/class/thermal/%s/%s", ent->d_name, filename);
                
                if (access(path, F_OK) == 0) {
                    rawrite(val, path);
                }
            }
        }
        closedir(dir);
    }
}

// Executions
void kobo_fast_charge() {

    // CP Paths
    const char *cp_paths[] = {"cp_enable", "cp_switcher_en", "cp_charging_enabled", "slave_chg_enable", "slave_enable"};
    for (int i = 0; i < 5; i++) apply_to_power_supply(cp_paths[i], "1");

    apply_to_power_supply("cp_current_limit", CURRENT_MAX);
    apply_to_power_supply("cp_ilim", CURRENT_MAX);

    // DC Charger
    if (access("/sys/class/power_supply/dc_charger", F_OK) == 0) {
        rawrite("1", "/sys/class/power_supply/dc_charger/present");
        rawrite("1", "/sys/class/power_supply/dc_charger/online");
        rawrite(CURRENT_MAX, "/sys/class/power_supply/dc_charger/current_max");
    }

    // Type C Port 0
    const char *typec_path = "/sys/class/typec/port0";
    if (access(typec_path, F_OK) == 0) {
        char path_buf[256];
        snprintf(path_buf, sizeof(path_buf), "%s/power_role", typec_path); rawrite("sink", path_buf);
        snprintf(path_buf, sizeof(path_buf), "%s/vbus_vsafe0v", typec_path); rawrite("1", path_buf);
    }

    // Charger Modules
    const char *modules[] = {
        "qpnp_smb2", "qpnp_smb5", "smb1351_charger", 
        "smb1355_charger", "smb_lib", "phy_msm_usb"
    };
    for (int i = 0; i < 6; i++) {
        char mod_path[256];
        snprintf(mod_path, sizeof(mod_path), "/sys/module/%s/parameters/aicl_enable", modules[i]); rawrite("0", mod_path);
        snprintf(mod_path, sizeof(mod_path), "/sys/module/%s/parameters/hvdcp3_allowed", modules[i]); rawrite("1", mod_path);
        snprintf(mod_path, sizeof(mod_path), "/sys/module/%s/parameters/step_charging_enable", modules[i]); rawrite("1", mod_path);
        snprintf(mod_path, sizeof(mod_path), "/sys/module/%s/parameters/usb_in_suspend", modules[i]); rawrite("0", mod_path);
        snprintf(mod_path, sizeof(mod_path), "/sys/module/%s/parameters/skip_usb_suspend_for_fake_battery", modules[i]); rawrite("1", mod_path);
    }

    // VOOC
    if (access("/proc/vooc_mp", F_OK) == 0) rawrite("1", "/proc/vooc_mp/allow_reading");
    if (access("/sys/class/power_supply/vooc", F_OK) == 0) {
        rawrite("1", "/sys/class/power_supply/vooc/fast_chg_ing");
        rawrite("1", "/sys/class/power_supply/vooc/allow_reading");
    }

    // Disable Thermal Limit
    apply_to_thermal("mode", "disabled");
    apply_to_power_supply("skin_temp_mitigation", "0");
    apply_to_power_supply("connector_temp_mitigation", "0");
    
    apply_to_power_supply("temp_cool", TEMP_COOL);
    apply_to_power_supply("temp_hot", TEMP_HOT);
    apply_to_power_supply("temp_warm", TEMP_WARM);
    apply_to_power_supply("temp_ambient", TEMP_COOL);

    // Fast Charge Features
    const char *features[] = {
        "fast_charge", "boost_mode", "turbo_mode", "pd_allowed", 
        "allow_hvdcp3", "hvdcp_opti", "quick_charge_mode", 
        "pump_express_enable", "fast_chg_type", "mtk_pulse_enable", 
        "pd_active", "force_demo_mode", "toggle_stat", "aicl_done"
    };
    for (int i = 0; i < 14; i++) apply_to_power_supply(features[i], "1");   

    // Limit Breaker
    const char *limits[] = {
        "current_max", "constant_charge_current", "constant_charge_current_max", 
        "input_current_limit", "input_current_max", "hw_current_max", 
        "pd_current_max", "ctm_current_max", "sdp_current_max", 
        "restricted_current", "main_current_max", "usb_current_max", 
        "fc_current_limit", "fast_charge_current_limit", "vbus_current_max", 
        "screen_on_current_limit"
    };
    for (int i = 0; i < 16; i++) apply_to_power_supply(limits[i], CURRENT_MAX);

    // Input Voltage
    const char *voltages[] = {
        "input_voltage_limit", "input_voltage_max", "voltage_max", 
        "voltage_max_design", "constant_charge_voltage_max", "vbus_voltage_max"
    };
    for (int i = 0; i < 6; i++) apply_to_power_supply(voltages[i], VOLTAGE_MAX);

    // Disable Safety
    const char *safeties[] = {
        "step_charging_enabled", "sw_jeita_enabled", "jeita_arise_throttled", 
        "soft_jeita_btn_enabled", "aicl_enable", "input_suspend", 
        "charge_disable", "safety_timer_enabled"
    };
    for (int i = 0; i < 8; i++) apply_to_power_supply(safeties[i], "0");

    // Vendor Specific
    if (access("/sys/devices/mtk-battery", F_OK) == 0) {
        rawrite(CURRENT_MAX, "/sys/devices/mtk-battery/restricted_current");
        rawrite(CURRENT_MAX, "/sys/devices/mtk-battery/fc_current_limit");
        rawrite("1", "/sys/devices/mtk-battery/pump_express_enable");
    }

    if (access("/sys/class/qcom-battery", F_OK) == 0) {
        rawrite("0", "/sys/class/qcom-battery/restricted_charging");
        rawrite("0", "/sys/class/qcom-battery/restrict_chg");
        rawrite(CURRENT_MAX, "/sys/class/qcom-battery/restricted_current");
        if (access("/sys/class/qcom-battery/rerun_aicl", F_OK) == 0) {
            rawrite("1", "/sys/class/qcom-battery/rerun_aicl");
        }
    }

    if (access("/sys/class/power_supply/sec-charger", F_OK) == 0) {
        rawrite(CURRENT_MAX, "/sys/class/power_supply/sec-charger/input_current_max");
        rawrite("0", "/sys/class/power_supply/sec-charger/otg_enable");
    }

    // Clean Up
    apply_to_power_supply("real_type", "DCP");
    apply_to_power_supply("store_mode", "0");
    apply_to_power_supply("batt_slate_mode", "0");

    rawrite("0", "/sys/class/power_supply/battery/input_current_limited");
    rawrite("1", "/sys/class/power_supply/battery/input_current_settled");
    rawrite("100", "/sys/class/power_supply/battery/siop_level");
    rawrite("0", "/sys/class/power_supply/battery/charge_control_limit_max");   
}