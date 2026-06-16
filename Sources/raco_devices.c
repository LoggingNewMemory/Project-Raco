/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
 */

#include "raco.h"

// ==============================
// MEDIATEK DEVICES
// ==============================

void mtk_get_max_freq(char *out) {
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

void mtk_get_mid_freq(char *out) {
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
    if (count > 0) snprintf(out, 32, "%d", indices[(count - 1) / 2]);
    else strcpy(out, "");
}

void mtk_get_min_freq(char *out) {
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
    // The last element is the highest index number (lowest frequency)
    if (count > 0) snprintf(out, 32, "%d", indices[count - 1]);
    else strcpy(out, "");
}

// Device Performance Settings

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
    if (config.device_mitigation == 1) {
        rawrite("2", "/sys/devices/system/cpu/eas/enable");
        rawrite("stop 0", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");
    } else {
        rawrite("0", "/sys/devices/system/cpu/eas/enable");
        rawrite("stop 1", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");
    }

    // GPU Tweaks
    rawrite("0", "/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp");
    rawrite("0", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");

    // FPSGo Sysfs Force Off
    rawrite("0", "/sys/kernel/fpsgo/common/fpsgo_enable");
    rawrite("0", "/sys/kernel/fpsgo/fbt/fbt_enable");
    rawrite("0", "/sys/kernel/fpsgo/fstb/fstb_self_ctrl_fps_enable");
    rawrite("0", "/sys/module/mtk_fpsgo/parameters/fstb_self_ctrl_fps_enable");

    // Power Limits
    if (config.device_mitigation == 1) {
        const char *power_limits[] = {
            "ignore_batt_oc 0", "ignore_batt_percent 0", "ignore_low_batt 0",
            "ignore_thermal_protect 0", "ignore_pbm_limited 0"
        };
        for (int i = 0; i < 5; i++) rawrite(power_limits[i], "/proc/gpufreq/gpufreq_power_limited");
    } else {
        const char *power_limits[] = {
            "ignore_batt_oc 1", "ignore_batt_percent 1", "ignore_low_batt 1",
            "ignore_thermal_protect 1", "ignore_pbm_limited 1"
        };
        for (int i = 0; i < 5; i++) rawrite(power_limits[i], "/proc/gpufreq/gpufreq_power_limited");
    }

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
    if (config.device_mitigation != 1) {
        devfreq_max("/sys/class/devfreq/mtk-dvfsrc-devfreq");
    }
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
    raco_bulk(ged_base, ged_files, ged_count, "0", 1);

    // Disable GED KPI
    rawrite("1", "/sys/module/ged/parameters/is_GED_KPI_enabled");

    // PNPMGR
    const char *pnp_base = "/sys/pnpmgr";
    const char *pnp_files[] = {"mwn", "boost_enable", "boost_mode"};
    int pnp_count = sizeof(pnp_files) / sizeof(pnp_files[0]);
    raco_bulk(pnp_base, pnp_files, pnp_count, "0", 1);

    // GED HAL
    const char *ged_hal = "/sys/kernel/ged/hal";
    char path_buf[256];
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_base_dvfs_step"); rawrite("4", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_stride_size"); rawrite("2", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_window_size"); rawrite("8", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "gpu_boost_level"); rawrite("-1", path_buf);

    // Standalone Mediatek Tweaks
    rawrite("0", "/proc/cpufreq/cpufreq_cci_mode");
    rawrite("0", "/proc/cpufreq/cpufreq_power_mode");
    rawrite("0", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    rawrite("2", "/sys/devices/system/cpu/eas/enable");
    rawrite("stop 0", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");

    // GPU Tweaks
    rawrite("-1", "/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp");
    rawrite("-1", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");

    // FPSGo Sysfs Restore
    rawrite("1", "/sys/kernel/fpsgo/common/fpsgo_enable");
    rawrite("1", "/sys/kernel/fpsgo/fbt/fbt_enable");
    rawrite("1", "/sys/kernel/fpsgo/fstb/fstb_self_ctrl_fps_enable");
    rawrite("1", "/sys/module/mtk_fpsgo/parameters/fstb_self_ctrl_fps_enable");

    // Power Limits
    const char *power_limits[] = {
        "ignore_batt_oc 0", "ignore_batt_percent 0", "ignore_low_batt 0",
        "ignore_thermal_protect 0", "ignore_pbm_limited 0"
    };
    for (int i = 0; i < 5; i++) rawrite(power_limits[i], "/proc/gpufreq/gpufreq_power_limited");

    // ==============================
    // GPU & FREQ TWEAKS
    // ==============================
    rawrite("0", "/proc/gpufreq/gpufreq_opp_freq");
    rawrite("-1", "/proc/gpufreqv2/fix_target_opp_index");

    char mid_idx[32];
    mtk_get_mid_freq(mid_idx);
    if (strlen(mid_idx) > 0) rawrite(mid_idx, "/sys/kernel/ged/hal/custom_boost_gpu_freq");

    // Defreq Tweaks
    devfreq_mid_perf("/sys/class/devfreq/mtk-dvfsrc-devfreq");
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
    raco_bulk(ged_base, ged_files, ged_count, "0", 1);

    // Disable GED KPI
    rawrite("1", "/sys/module/ged/parameters/is_GED_KPI_enabled");

    // PNPMGR
    const char *pnp_base = "/sys/pnpmgr";
    const char *pnp_files[] = {"mwn", "boost_enable", "boost_mode"};
    int pnp_count = sizeof(pnp_files) / sizeof(pnp_files[0]);
    raco_bulk(pnp_base, pnp_files, pnp_count, "0", 1);

    // GED HAL
    const char *ged_hal = "/sys/kernel/ged/hal";
    char path_buf[256];
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_base_dvfs_step"); rawrite("4", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_stride_size"); rawrite("2", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_window_size"); rawrite("8", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "gpu_boost_level"); rawrite("-1", path_buf);

    // Standalone Mediatek Tweaks
    rawrite("0", "/proc/cpufreq/cpufreq_cci_mode");
    rawrite("0", "/proc/cpufreq/cpufreq_power_mode");
    rawrite("0", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    rawrite("2", "/sys/devices/system/cpu/eas/enable");
    rawrite("stop 0", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");

    // GPU Tweaks
    rakakikomi("-1", "/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp");
    rakakikomi("-1", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");

    // FPSGo Sysfs Restore
    rawrite("1", "/sys/kernel/fpsgo/common/fpsgo_enable");
    rawrite("1", "/sys/kernel/fpsgo/fbt/fbt_enable");
    rawrite("1", "/sys/kernel/fpsgo/fstb/fstb_self_ctrl_fps_enable");
    rawrite("1", "/sys/module/mtk_fpsgo/parameters/fstb_self_ctrl_fps_enable");

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

    char min_idx[32];
    mtk_get_min_freq(min_idx);
    if (strlen(min_idx) > 0) rawrite(min_idx, "/sys/kernel/ged/hal/custom_boost_gpu_freq");

    // Defreq Tweaks
    devfreq_release("/sys/class/devfreq/mtk-dvfsrc-devfreq");
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
    raco_bulk(ged_base, ged_files, ged_count, "0", 1);

    // Disable GED KPI
    rawrite("1", "/sys/module/ged/parameters/is_GED_KPI_enabled");

    // PNPMGR
    const char *pnp_base = "/sys/pnpmgr";
    const char *pnp_files[] = {"mwn", "boost_enable", "boost_mode"};
    int pnp_count = sizeof(pnp_files) / sizeof(pnp_files[0]);
    raco_bulk(pnp_base, pnp_files, pnp_count, "0", 1);

    // GED HAL
    const char *ged_hal = "/sys/kernel/ged/hal";
    char path_buf[256];
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_base_dvfs_step"); rawrite("4", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_stride_size"); rawrite("2", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "loading_window_size"); rawrite("8", path_buf);
    snprintf(path_buf, sizeof(path_buf), "%s/%s", ged_hal, "gpu_boost_level"); rawrite("-1", path_buf);

    // Standalone Mediatek Tweaks
    rawrite("0", "/proc/cpufreq/cpufreq_cci_mode");
    rawrite("0", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    rawrite("2", "/sys/devices/system/cpu/eas/enable");
    rawrite("stop 0", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");

    // GPU Tweaks
    rakakikomi("-1", "/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp");
    rakakikomi("-1", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");

    // FPSGo Sysfs Restore
    rawrite("1", "/sys/kernel/fpsgo/common/fpsgo_enable");
    rawrite("1", "/sys/kernel/fpsgo/fbt/fbt_enable");
    rawrite("1", "/sys/kernel/fpsgo/fstb/fstb_self_ctrl_fps_enable");
    rawrite("1", "/sys/module/mtk_fpsgo/parameters/fstb_self_ctrl_fps_enable");

    // Power Limits
    const char *power_limits[] = {
        "ignore_batt_oc 0", "ignore_batt_percent 0", "ignore_low_batt 0",
        "ignore_thermal_protect 0", "ignore_pbm_limited 0"
    };
    for (int i = 0; i < 5; i++) rawrite(power_limits[i], "/proc/gpufreq/gpufreq_power_limited");

    // ==============================
    // GPU & FREQ TWEAKS
    // ==============================
    rawrite("1", "/proc/cpufreq/cpufreq_power_mode");
    
    rakakikomi("0", "/proc/gpufreq/gpufreq_opp_freq");
    rakakikomi("-1", "/proc/gpufreqv2/fix_target_opp_index");

    char min_idx[32];
    mtk_get_min_freq(min_idx);
    if (strlen(min_idx) > 0) rawrite(min_idx, "/sys/kernel/ged/hal/custom_boost_gpu_freq");

    // Defreq Tweaks
    devfreq_release("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}

// ==============================
// SNAPDRAGON DEVICES
// ==============================

void snapdragon_core_ctl_apply(const char *val, int lock) {
    DIR *dir;
    struct dirent *ent;

    if ((dir = opendir("/sys/devices/system/cpu")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "cpu", 3) == 0) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/%s/core_ctl/enable", ent->d_name);

                if (access(path, F_OK) == 0) {
                    if (lock == 1) {
                        rawrite(val, path);
                    } else {
                        rakakikomi(val,path);
                    }
                }
            }
        }
        closedir(dir);
    }
}

void snapdragon_devfreq_apply(int mode) {
    if(config.device_mitigation == 1) return;
    DIR *dir; struct dirent *ent;
    if ((dir = opendir("/sys/class/devfreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {

            if ((strstr(ent->d_name, "cpu") && strstr (ent->d_name, "-lat")) ||
                (strstr(ent->d_name, "cpu") && strstr (ent->d_name, "-bw")) ||
                strstr(ent->d_name, "llccbw") ||
                strstr (ent->d_name, "bus_llcc") ||
                strstr(ent->d_name, "bus_ddr") ||
                strstr (ent->d_name, "memlat") ||
                strstr(ent->d_name, "cpubw") ||
                strstr (ent->d_name, "kgsl-ddr-qos")) {
                
                char path[256];
                
                snprintf(path, sizeof(path), "/sys/class/devfreq/%s", ent->d_name);

                    if (mode == 0) devfreq_max(path);
                    else if (mode == 1) devfreq_release(path);
                    else if (mode == 2) devfreq_mid_perf(path);
            }
        }
        closedir(dir);
    }
    const char *dcvs_paths[] = {
        "/sys/devices/system/cpu/bus_dcvs/DDR",
        "/sys/devices/system/cpu/bus_dcvs/LLCC",
        "/sys/devices/system/cpu/bus_dcvs/L3"
    };
    for (int i = 0; i < 3; i++) {
        if (mode == 0) devfreq_max(dcvs_paths[i]);
        else if (mode == 1) devfreq_release(dcvs_paths[i]);
        else if (mode == 2) devfreq_mid_perf(dcvs_paths[i]);
    }
}

void snapdragon_set_kgsl_pwrlevel(int mode) {
    char num_buf[32] = {0};
    int max_idx = 5; // fallback
    if (raread("/sys/class/kgsl/kgsl-3d0/num_pwrlevels", num_buf, sizeof(num_buf)) > 0) {
        max_idx = atoi(num_buf) - 1;
        if (max_idx < 0) max_idx = 5;
    }
    
    char min_val[16];
    if (mode == 0) {
        // Max perf
        rawrite("0", "/sys/class/kgsl/kgsl-3d0/min_pwrlevel");
        rawrite("0", "/sys/class/kgsl/kgsl-3d0/max_pwrlevel");
    } else if (mode == 2) {
        // Mid perf
        snprintf(min_val, sizeof(min_val), "%d", max_idx / 2);
        rawrite(min_val, "/sys/class/kgsl/kgsl-3d0/min_pwrlevel");
        rawrite("0", "/sys/class/kgsl/kgsl-3d0/max_pwrlevel");
    } else {
        // Release
        snprintf(min_val, sizeof(min_val), "%d", max_idx);
        rawrite(min_val, "/sys/class/kgsl/kgsl-3d0/min_pwrlevel");
        rawrite("0", "/sys/class/kgsl/kgsl-3d0/max_pwrlevel");
    }
}

// Device Performance Settings

void snapdragon_awaken() {
    // ==============================
    // MISC TWEAKS
    // ==============================

    // Force CLK & PWR Level
    const char *kgsl_base = "/sys/class/kgsl/kgsl-3d0";
    const char *kgsl_1[] = {"force_clk_on", "default_pwrlevel"};
    raco_bulk(kgsl_base, kgsl_1, 2, "1", 1);
    
    snapdragon_set_kgsl_pwrlevel(0);

    // Bus Split & Throttling
    if (config.device_mitigation == 1) {
        const char *kgsl_0[] = {"bus_split", "throttling"};
        raco_bulk(kgsl_base, kgsl_0, 2, "1", 1);
    } else {
        const char *kgsl_0[] = {"bus_split", "throttling"};
        raco_bulk(kgsl_base, kgsl_0, 2, "0", 1);
    }

    // Adreno Boost
    char path_buf[256];
    snprintf(path_buf, sizeof(path_buf), "%s/%s", kgsl_base, "devfreq/adrenoboost");
    rawrite("3", path_buf);

    // MSM Parameters & Touch Boost Freq
    const char *msm_base = "/sys/module/msm_perfmon/parameters";
    const char *msm_files[] = {"touch_boost_enable", "touch_boost_freq"};
    raco_bulk(msm_base, msm_files, 2, "1", 1);

    rawrite("1", "/sys/module/msm_performance/parameters/touchboost"); // Enable Touchboost
    rawrite("Y", "/sys/module/adreno_idler/parameters/adreno_idler_active"); // Set Adreno Idl

    snapdragon_core_ctl_apply("1", 1);

    // ==============================
    // GPU & FREQ TWEAKS
    // ==============================

    snapdragon_devfreq_apply(0);
    if (config.device_mitigation != 1) {
        devfreq_max("/sys/class/kgsl/kgsl-3d0/devfreq");
    }
}

void snapdragon_balanced() {
    // ==============================
    // MISC TWEAKS
    // ==============================

    // Force CLK & PWR Level
    const char *kgsl_base = "/sys/class/kgsl/kgsl-3d0";
    const char *kgsl_1[] = {"force_clk_on", "default_pwrlevel"};
    raco_bulk(kgsl_base, kgsl_1, 2, "0", 0);
    
    snapdragon_set_kgsl_pwrlevel(2);

    // Bus Split & Throttling
    const char *kgsl_0[] = {"bus_split", "throttling"};
    raco_bulk(kgsl_base, kgsl_0, 2, "1", 0);

    // Adreno Boost
    char path_buf[256];
    snprintf(path_buf, sizeof(path_buf), "%s/%s", kgsl_base, "devfreq/adrenoboost");
    rakakikomi("0", path_buf);

    // MSM Parameters & Touch Boost Freq
    const char *msm_base = "/sys/module/msm_perfmon/parameters";
    const char *msm_files[] = {"touch_boost_enable", "touch_boost_freq"};
    raco_bulk(msm_base, msm_files, 2, "0", 0);

    rakakikomi("0", "/sys/module/msm_performance/parameters/touchboost"); // Enable Touchboost
    rakakikomi("N", "/sys/module/adreno_idler/parameters/adreno_idler_active"); // Set Adreno Idl

    snapdragon_core_ctl_apply("0", 0);

    // ==============================
    // GPU & FREQ TWEAKS
    // ==============================

    snapdragon_devfreq_apply(2);
    devfreq_mid_perf("/sys/class/kgsl/kgsl-3d0/devfreq");
}

void snapdragon_normal() {
    // ==============================
    // MISC TWEAKS
    // ==============================

    // Force CLK & PWR Level
    const char *kgsl_base = "/sys/class/kgsl/kgsl-3d0";
    const char *kgsl_1[] = {"force_clk_on", "default_pwrlevel"};
    raco_bulk(kgsl_base, kgsl_1, 2, "0", 0);
    
    snapdragon_set_kgsl_pwrlevel(1);

    // Bus Split & Throttling
    const char *kgsl_0[] = {"bus_split", "throttling"};
    raco_bulk(kgsl_base, kgsl_0, 2, "1", 0);

    // Adreno Boost
    char path_buf[256];
    snprintf(path_buf, sizeof(path_buf), "%s/%s", kgsl_base, "devfreq/adrenoboost");
    rakakikomi("0", path_buf);

    // MSM Parameters & Touch Boost Freq
    const char *msm_base = "/sys/module/msm_perfmon/parameters";
    const char *msm_files[] = {"touch_boost_enable", "touch_boost_freq"};
    raco_bulk(msm_base, msm_files, 2, "0", 0);

    rakakikomi("0", "/sys/module/msm_performance/parameters/touchboost"); // Enable Touchboost
    rakakikomi("N", "/sys/module/adreno_idler/parameters/adreno_idler_active"); // Set Adreno Idl

    snapdragon_core_ctl_apply("0", 0);

    // ==============================
    // GPU & FREQ TWEAKS
    // ==============================

    snapdragon_devfreq_apply(1);
    devfreq_release("/sys/class/kgsl/kgsl-3d0/devfreq");
}

void snapdragon_powersave() {
    // ==============================
    // MISC TWEAKS
    // ==============================

    // Force CLK & PWR Level
    const char *kgsl_base = "/sys/class/kgsl/kgsl-3d0";
    const char *kgsl_1[] = {"force_clk_on", "default_pwrlevel"};
    raco_bulk(kgsl_base, kgsl_1, 2, "0", 0);
    
    snapdragon_set_kgsl_pwrlevel(1);

    // Bus Split & Throttling
    const char *kgsl_0[] = {"bus_split", "throttling"};
    raco_bulk(kgsl_base, kgsl_0, 2, "1", 0);

    // Adreno Boost
    char path_buf[256];
    snprintf(path_buf, sizeof(path_buf), "%s/%s", kgsl_base, "devfreq/adrenoboost");
    rakakikomi("0", path_buf);

    // MSM Parameters & Touch Boost Freq
    const char *msm_base = "/sys/module/msm_perfmon/parameters";
    const char *msm_files[] = {"touch_boost_enable", "touch_boost_freq"};
    raco_bulk(msm_base, msm_files, 2, "0", 0);

    rakakikomi("0", "/sys/module/msm_performance/parameters/touchboost"); // Enable Touchboost
    rakakikomi("Y", "/sys/module/adreno_idler/parameters/adreno_idler_active"); // Set Adreno Idl

    snapdragon_core_ctl_apply("0", 0);

    // ==============================
    // GPU & FREQ TWEAKS
    // ==============================

    snapdragon_devfreq_apply(1);
    devfreq_release("/sys/class/kgsl/kgsl-3d0/devfreq");
}

// =================================================================
// MINOR CHIPSETS HELPER FUNCTIONS (Exynos, Unisoc, Tensor, Tegra)
// =================================================================

void scan_minor_devfreq_and_apply(const char *target, int mode) {
    if (config.device_mitigation == 1) return;

    DIR *dir;
    struct dirent *ent;

    if ((dir = opendir("/sys/class/devfreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strstr(ent->d_name, target)) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/class/devfreq/%s", ent->d_name);

                if (mode == 0) devfreq_max(path);
                else if (mode == 1) devfreq_release(path);
                else if (mode == 2) devfreq_mid_perf(path);
                else if (mode == 3) devfreq_min_perf(path);
            }
        }
        closedir(dir);
    }
}

void set_custom_gpu_bounds(const char *base, const char *avail, const char *max_f, const char *min_f, int mode) {
    char avail_path[256], max_path[256], min_path[256];
    snprintf(avail_path, sizeof(avail_path), "%s/%s", base, avail);
    snprintf(max_path, sizeof(max_path), "%s/%s", base, max_f);
    snprintf(min_path, sizeof(min_path), "%s/%s", base, min_f);

    FreqData f_max = get_target_freq(avail_path, 0);
    FreqData f_min = get_target_freq(avail_path, 1);
    FreqData f_mid = get_target_freq(avail_path, 2);

    if (f_max.freq == -1) return;

    char v_max[32], v_min[32], v_mid[32];
    snprintf(v_max, sizeof(v_max), "%ld", f_max.freq);
    snprintf(v_min, sizeof(v_min), "%ld", f_min.freq);
    snprintf(v_mid, sizeof(v_mid), "%ld", f_mid.freq);

    if (mode == 0) {
        rawrite(v_max, max_path); rawrite(v_max, min_path);
    } else if (mode == 1) {
        rakakikomi(v_max, max_path); rakakikomi(v_min, min_path);
    } else if (mode == 2) {
        rawrite(v_max, max_path); rawrite(v_mid, min_path);
    } else if (mode == 3) {
        rawrite(v_min, max_path); rawrite(v_min, min_path);
    }
}

// ==============================
// EXYNOS DEVICES
// ==============================

void exynos_awaken() {
    DIR *dir; struct dirent *ent;
    if ((dir = opendir("/sys/devices/platform")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strstr(ent->d_name, ".mali")) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/platform/%s/power_policy", ent->d_name);
                rawrite("always_on", path); break;
            }
        }
        closedir(dir);
    }
    set_custom_gpu_bounds("/sys/kernel/gpu", "gpu_available_frequencies", "gpu_max_clock", "gpu_min_clock", 0);
    scan_minor_devfreq_and_apply("devfreq_mif", 0);
}

void exynos_balanced() {
    DIR *dir; struct dirent *ent;
    if ((dir = opendir("/sys/devices/platform")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strstr(ent->d_name, ".mali")) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/platform/%s/power_policy", ent->d_name);
                rakakikomi("coarse_demand", path); break;
            }
        }
        closedir(dir);
    }
    set_custom_gpu_bounds("/sys/kernel/gpu", "gpu_available_frequencies", "gpu_max_clock", "gpu_min_clock", 2);
    scan_minor_devfreq_and_apply("devfreq_mif", 2);
}

void exynos_normal() {
    DIR *dir; struct dirent *ent;
    if ((dir = opendir("/sys/devices/platform")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strstr(ent->d_name, ".mali")) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/platform/%s/power_policy", ent->d_name);
                rakakikomi("coarse_demand", path); break;
            }
        }
        closedir(dir);
    }
    set_custom_gpu_bounds("/sys/kernel/gpu", "gpu_available_frequencies", "gpu_max_clock", "gpu_min_clock", 1);
    scan_minor_devfreq_and_apply("devfreq_mif", 1);
}

void exynos_powersave() {
    set_custom_gpu_bounds("/sys/kernel/gpu", "gpu_available_frequencies", "gpu_max_clock", "gpu_min_clock", 1);   
}

// ==============================
// UNISOC DEVICES
// ==============================

void unisoc_awaken() { scan_minor_devfreq_and_apply(".gpu", 0); }
void unisoc_balanced() { scan_minor_devfreq_and_apply(".gpu", 2); }
void unisoc_normal() { scan_minor_devfreq_and_apply(".gpu", 1); }
void unisoc_powersave() { scan_minor_devfreq_and_apply(".gpu", 1); }

// ==============================
// TENSOR DEVICES
// ==============================

void tensor_awaken() {
    scan_minor_devfreq_and_apply("devfreq_mif", 0);
    DIR *dir; struct dirent *ent;
    if ((dir = opendir("/sys/devices/platform")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strstr(ent->d_name, ".mali")) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/platform/%s", ent->d_name);
                set_custom_gpu_bounds(path, "available_frequencies", "scaling_max_freq", "scaling_min_freq", 0);
            }
        }
        closedir(dir);
    }
}

void tensor_balanced() {
    scan_minor_devfreq_and_apply("devfreq_mif", 2);
    DIR *dir; struct dirent *ent;
    if ((dir = opendir("/sys/devices/platform")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strstr(ent->d_name, ".mali")) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/platform/%s", ent->d_name);
                set_custom_gpu_bounds(path, "available_frequencies", "scaling_max_freq", "scaling_min_freq", 2);
            }
        }
        closedir(dir);
    }
}

void tensor_normal() {
    scan_minor_devfreq_and_apply("devfreq_mif", 1);
    DIR *dir; struct dirent *ent;
    if ((dir = opendir("/sys/devices/platform")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strstr(ent->d_name, ".mali")) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/platform/%s", ent->d_name);
                set_custom_gpu_bounds(path, "available_frequencies", "scaling_max_freq", "scaling_min_freq", 1);
            }
        }
        closedir(dir);
    }
}

void tensor_powersave() {
    scan_minor_devfreq_and_apply("devfreq_mif", 1);
    DIR *dir; struct dirent *ent;
    if ((dir = opendir("/sys/devices/platform")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strstr(ent->d_name, ".mali")) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/platform/%s", ent->d_name);
                set_custom_gpu_bounds(path, "available_frequencies", "scaling_max_freq", "scaling_min_freq", 1);
            }
        }
        closedir(dir);
    }
}

// ==============================
// TEGRA DEVICES
// ==============================

void tegra_awaken() { set_custom_gpu_bounds("/sys/kernel/tegra_gpu", "available_frequencies", "gpu_cap_rate", "gpu_floor_rate", 0); }
void tegra_balanced() { set_custom_gpu_bounds("/sys/kernel/tegra_gpu", "available_frequencies", "gpu_cap_rate", "gpu_floor_rate", 2); }
void tegra_normal() { set_custom_gpu_bounds("/sys/kernel/tegra_gpu", "available_frequencies", "gpu_cap_rate", "gpu_floor_rate", 1); }
void tegra_powersave() { set_custom_gpu_bounds("/sys/kernel/tegra_gpu", "available_frequencies", "gpu_cap_rate", "gpu_floor_rate", 1); }