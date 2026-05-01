#include "raco.h"

/*
Bulk Writer, Why? Either I'm smart to not write one by one path and value
Or I'm lazy because I don't want to write one by one path and value
*/

void raco_bulk(const char *base, const char *files[], int count, const char *val, int lock) {
    char path[256];
    for (int i = 0; i < count; i++) {
        snprintf(path, sizeof(path), "%s/%s", base, files[i]);
        if (lock == 1) {
            rawrite(val, path);
        } else {
            rakakikomi(val, path);
        }
    }
}

void  mtk_get_max_freq(char *out) {
    char buffer[4096];
    if (raread("/proc/gpufreq/gpufreq_opp_dump", buffer, sizeof(buffer)) > 0) {
        long max_val = 0;
        char *saveptr;
        char *line = strtok_r(buffer, "\n", &saveptr);

        while (line != NULL) {
            char *f_ptr = strstr(line, "freq = ");
            if (f_ptr) {
                long val = atol(f_ptr + 7);
                if (val > max_val) max_val = val;
            }
            line = strtok_r(NULL, "\n", &saveptr);
        }
        if (max_val > 0) snprintf(out, 32, "%ld", max_val);
        else strcpy(out, "");
    } else {
        strcpy(out, "");
    }
}

void  mtk_get_mid_freq(char *out) {
    char buffer[4096];
    int indices[50];
    int count = 0; 

    if (raread("/proc/gpufreqv2/gpu_working_opp_table", buffer, sizeof(buffer)) > 0 || 
        raread("/proc/gpufreq/gpufreq_opp_dump", buffer, sizeof(buffer)) > 0) {
        char *saveptr;
        char *line = strtok_r(buffer, "\n", &saveptr);

        while (line != NULL && count < 50) {
            char *bracket = strchr(line, '[');
            if (bracket) {
                indices[count] = atol(bracket + 1);
                count++;
            }
            line = strtok_r(NULL, "\n", &saveptr);
        }
    }
    if (count > 0) snprintf(out, 32, "%d", indices[count / 2]);
    else strcpy(out, "");
}

// ==============================
// MEDIATEK DEVICES
// ==============================

void mediatek_awaken() {
    // ==============================
    // MISC TWEAKS
    // ==============================

    // GED Tweaks
    const char *ged_base = "/sys/module/ged/parameters";
    const char *ged_files[] = {
        "gx_boost_on", "gx_game_mode", "ged_smart_boost", "enable_gpu_boost",
        "ged_boost_enable", "gx_frc_mode", "cpu_boost_policy", "boost_extra"
    };
    int ged_count = sizeof(ged_files) / sizeof(ged_files[0]);
    raco_bulk(ged_base, ged_files, ged_count, "1", 1);

    // Disable GED KPI
    rawrite("0", "/sys/module/ged/parameters/is_GED_KPI_enabled");

    // PNPMGR
    const char *pnp_base = "/sys/pnpmgr";
    const char *pnp_files[] = {"mwn", "boost_enable"};
    int pnp_count = sizeof(pnp_files) / sizeof(pnp_files[0]);
    raco_bulk(pnp_base, pnp_files, pnp_count, "1", 1);
    
    rawrite("turbo", "/sys/pnpmgr/boost_mode");

    // GED HAL
    const char *ged_hal = "/sys/kernel/ged/hal";
    char path_buf[256];
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_base_dvfs_step"); rawrite("2", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_stride_size"); rawrite("1", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_window_size"); rawrite("16", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "gpu_boost_level"); rawrite("100", path_buf);

    // Standalone Mediatek Tweaks
    rawrite("1", "/proc/cpufreq/cpufreq_cci_mode");
    rawrite("3", "/proc/cpufreq/cpufreq_power_mode");
    rawrite("1", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    rawrite("0", "/sys/devices/system/cpu/eas/enable");
    rawrite("stop 1", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");

    // GPU Tweaks
    rawrite("0", "/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp");
    rawrite("0", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");

    // Power Limits
    const char *power_limits[] = {
        "ignore_batt_oc 1", "ignore_batt_percent 1", "ignore_low_batt 1",
        "ignore_thermal_protect 1", "ignore_pbm_limited 1"
    };
    for (int i = 0; i < 5; i++) rawrite(power_limits[i], "/proc/gpufreq/gpufreq_power_limited");

    // ==============================
    // GPU & FREQ TWEAKS
    // ==============================
    if (access("/proc/gpufreqv2/fix_target_opp_index", F_OK) == 0) {
        rawrite("0", "/proc/gpufreqv2/fix_target_opp_index");
    } else {
        char max_freq[32];
        mtk_get_max_freq(max_freq);
        if (strlen(max_freq) > 0) rawrite(max_freq, "/proc/gpufreq/gpufreq_opp_freq");
    }

    // Defreq Tweaks
    devfreq_max("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}

void mediatek_balanced() {
    // ==============================
    // MISC TWEAKS
    // ==============================

    // GED Tweaks
    const char *ged_base = "/sys/module/ged/parameters";
    const char *ged_files[] = {
        "gx_boost_on", "gx_game_mode", "ged_smart_boost", "enable_gpu_boost",
        "ged_boost_enable", "gx_frc_mode", "cpu_boost_policy", "boost_extra"
    };
    int ged_count = sizeof(ged_files) / sizeof(ged_files[0]);
    raco_bulk(ged_base, ged_files, ged_count, "0", 0);

    // Disable GED KPI
    rakakikomi("1", "/sys/module/ged/parameters/is_GED_KPI_enabled");

    // PNPMGR
    const char *pnp_base = "/sys/pnpmgr";
    const char *pnp_files[] = {"mwn", "boost_enable", "boost_mode"};
    int pnp_count = sizeof(pnp_files) / sizeof(pnp_files[0]);
    raco_bulk(pnp_base, pnp_files, pnp_count, "0", 0);

    // GED HAL
    const char *ged_hal = "/sys/kernel/ged/hal";
    char path_buf[256];
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_base_dvfs_step"); rakakikomi("4", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_stride_size"); rakakikomi("2", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_window_size"); rakakikomi("8", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "gpu_boost_level"); rakakikomi("-1", path_buf);

    // Standalone Mediatek Tweaks
    rakakikomi("0", "/proc/cpufreq/cpufreq_cci_mode");
    rakakikomi("0", "/proc/cpufreq/cpufreq_power_mode");
    rakakikomi("0", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    rakakikomi("2", "/sys/devices/system/cpu/eas/enable");
    rakakikomi("stop 0", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");

    // GPU Tweaks
    rakakikomi("-1", "/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp");
    rakakikomi("-1", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");

    // Power Limits
    const char *power_limits[] = {
        "ignore_batt_oc 0", "ignore_batt_percent 0", "ignore_low_batt 0",
        "ignore_thermal_protect 0", "ignore_pbm_limited 0"
    };
    for (int i = 0; i < 5; i++) rawrite(power_limits[i], "/proc/gpufreq/gpufreq_power_limited");

    // ==============================
    // GPU & FREQ TWEAKS
    // ==============================
    rakakikomi("0", "/proc/gpufreq/gpufreq_opp_freq");
    rakakikomi("-1", "/proc/gpufreqv2/fix_target_opp_index");

    char mid_idx[32];
    mtk_get_mid_freq(mid_idx);
    if (strlen(mid_idx) > 0) rakakikomi(mid_idx, "/sys/kernel/ged/hal/custom_boost_gpu_freq");

    // Defreq Tweaks
    devfreq_balanced("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}

void mediatek_powersave() {
    // ==============================
    // MISC TWEAKS
    // ==============================

    // GED Tweaks
    const char *ged_base = "/sys/module/ged/parameters";
    const char *ged_files[] = {
        "gx_boost_on", "gx_game_mode", "ged_smart_boost", "enable_gpu_boost",
        "ged_boost_enable", "gx_frc_mode", "cpu_boost_policy", "boost_extra"
    };
    int ged_count = sizeof(ged_files) / sizeof(ged_files[0]);
    raco_bulk(ged_base, ged_files, ged_count, "0", 0);

    // Disable GED KPI
    rakakikomi("1", "/sys/module/ged/parameters/is_GED_KPI_enabled");

    // PNPMGR
    const char *pnp_base = "/sys/pnpmgr";
    const char *pnp_files[] = {"mwn", "boost_enable", "boost_mode"};
    int pnp_count = sizeof(pnp_files) / sizeof(pnp_files[0]);
    raco_bulk(pnp_base, pnp_files, pnp_count, "0", 0);

    // GED HAL
    const char *ged_hal = "/sys/kernel/ged/hal";
    char path_buf[256];
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_base_dvfs_step"); rakakikomi("4", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_stride_size"); rakakikomi("2", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_window_size"); rakakikomi("8", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "gpu_boost_level"); rakakikomi("-1", path_buf);

    // Standalone Mediatek Tweaks
    rakakikomi("0", "/proc/cpufreq/cpufreq_cci_mode");

    rakakikomi("0", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    rakakikomi("2", "/sys/devices/system/cpu/eas/enable");
    rakakikomi("stop 0", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");

    // GPU Tweaks
    rakakikomi("-1", "/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp");
    rakakikomi("-1", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");

    // Power Limits
    const char *power_limits[] = {
        "ignore_batt_oc 0", "ignore_batt_percent 0", "ignore_low_batt 0",
        "ignore_thermal_protect 0", "ignore_pbm_limited 0"
    };
    for (int i = 0; i < 5; i++) rakakikomi(power_limits[i], "/proc/gpufreq/gpufreq_power_limited");

    // ==============================
    // GPU & FREQ TWEAKS
    // ==============================
    rawrite("1", "/proc/cpufreq/cpufreq_power_mode");
    
    rakakikomi("0", "/proc/gpufreq/gpufreq_opp_freq");
    rakakikomi("-1", "/proc/gpufreqv2/fix_target_opp_index");

    rakakikomi("0", "/sys/kernel/ged/hal/custom_boost_gpu_freq");

    // Defreq Tweaks
    devfreq_release("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}

void mediatek_normal() {
    // ==============================
    // MISC TWEAKS
    // ==============================

    // GED Tweaks
    const char *ged_base = "/sys/module/ged/parameters";
    const char *ged_files[] = {
        "gx_boost_on", "gx_game_mode", "ged_smart_boost", "enable_gpu_boost",
        "ged_boost_enable", "gx_frc_mode", "cpu_boost_policy", "boost_extra"
    };
    int ged_count = sizeof(ged_files) / sizeof(ged_files[0]);
    raco_bulk(ged_base, ged_files, ged_count, "0", 0);

    // Disable GED KPI
    rakakikomi("1", "/sys/module/ged/parameters/is_GED_KPI_enabled");

    // PNPMGR
    const char *pnp_base = "/sys/pnpmgr";
    const char *pnp_files[] = {"mwn", "boost_enable", "boost_mode"};
    int pnp_count = sizeof(pnp_files) / sizeof(pnp_files[0]);
    raco_bulk(pnp_base, pnp_files, pnp_count, "0", 0);

    // GED HAL
    const char *ged_hal = "/sys/kernel/ged/hal";
    char path_buf[256];
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_base_dvfs_step"); rakakikomi("4", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_stride_size"); rakakikomi("2", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_window_size"); rakakikomi("8", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "gpu_boost_level"); rakakikomi("-1", path_buf);

    // Standalone Mediatek Tweaks
    rakakikomi("0", "/proc/cpufreq/cpufreq_cci_mode");
    rakakikomi("0", "/proc/cpufreq/cpufreq_power_mode");
    rakakikomi("0", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    rakakikomi("2", "/sys/devices/system/cpu/eas/enable");
    rakakikomi("stop 0", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");

    // GPU Tweaks
    rakakikomi("-1", "/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp");
    rakakikomi("-1", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");

    // Power Limits
    const char *power_limits[] = {
        "ignore_batt_oc 0", "ignore_batt_percent 0", "ignore_low_batt 0",
        "ignore_thermal_protect 0", "ignore_pbm_limited 0"
    };
    for (int i = 0; i < 5; i++) rakakikomi(power_limits[i], "/proc/gpufreq/gpufreq_power_limited");

    // ==============================
    // GPU & FREQ TWEAKS
    // ==============================
    rakakikomi("0", "/proc/gpufreq/gpufreq_opp_freq");
    rakakikomi("-1", "/proc/gpufreqv2/fix_target_opp_index");

    rakakikomi("0", "/sys/kernel/ged/hal/custom_boost_gpu_freq");

    // Defreq Tweaks
    devfreq_release("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}