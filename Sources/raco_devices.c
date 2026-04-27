/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <glob.h>
#include "raco_utils.h"
#include "raco_devices.h"

// ==========================================
// Frequency Helpers
// ==========================================

void devfreq_set_mode(const char *path, const char *mode) {
    char avail_path[256], min_path[256], max_path[256];
    snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", path);
    snprintf(min_path, sizeof(min_path), "%s/min_freq", path);
    snprintf(max_path, sizeof(max_path), "%s/max_freq", path);

    char *max_freq = get_maxfreq(avail_path);
    if (!max_freq || !max_freq[0]) return; 

    char *min_freq = get_minfreq(avail_path);
    char *mid_freq = get_midfreq(avail_path);

    if (strcmp(mode, "max") == 0) {
        tweak(max_freq, min_path);
        tweak(max_freq, max_path);
    } else if (strcmp(mode, "mid") == 0) {
        tweak(max_freq, max_path);
        tweak(mid_freq, min_path);
    } else if (strcmp(mode, "min") == 0) {
        tweak(min_freq, min_path);
        tweak(min_freq, max_path);
    } else if (strcmp(mode, "unlock") == 0) {
        kakangku(min_freq, min_path);
        kakangku(max_freq, max_path);
    }
}

void devfreq_max_perf(const char *path) { devfreq_set_mode(path, "max"); }
void devfreq_mid_perf(const char *path) { devfreq_set_mode(path, "mid"); }
void devfreq_min_perf(const char *path) { devfreq_set_mode(path, "min"); }
void devfreq_unlock(const char *path)   { devfreq_set_mode(path, "unlock"); }

void qcom_cpudcvs_max_perf(const char *path) {
    char avail_path[256], hw_max[256], hw_min[256];
    snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", path);
    snprintf(hw_max, sizeof(hw_max), "%s/hw_max_freq", path);
    snprintf(hw_min, sizeof(hw_min), "%s/hw_min_freq", path);
    
    char *freq = get_maxfreq(avail_path);
    if (freq && freq[0]) {
        tweak(freq, hw_max);
        tweak(freq, hw_min);
    }
}

void qcom_cpudcvs_mid_perf(const char *path) {
    char avail_path[256], hw_max[256], hw_min[256];
    snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", path);
    snprintf(hw_max, sizeof(hw_max), "%s/hw_max_freq", path);
    snprintf(hw_min, sizeof(hw_min), "%s/hw_min_freq", path);

    char *max_freq = get_maxfreq(avail_path);
    char *mid_freq = get_midfreq(avail_path);
    if (max_freq && max_freq[0]) {
        tweak(max_freq, hw_max);
        tweak(mid_freq, hw_min);
    }
}

void qcom_cpudcvs_unlock(const char *path) {
    char avail_path[256], hw_max[256], hw_min[256];
    snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", path);
    snprintf(hw_max, sizeof(hw_max), "%s/hw_max_freq", path);
    snprintf(hw_min, sizeof(hw_min), "%s/hw_min_freq", path);

    char *max_freq = get_maxfreq(avail_path);
    char *min_freq = get_minfreq(avail_path);
    if (max_freq && max_freq[0]) {
        kakangku(max_freq, hw_max);
        kakangku(min_freq, hw_min);
    }
}

// ==========================================
// MediaTek Legacy GPU Parsers
// ==========================================

static void mtkvest_perf() {
    if (access("/sys/kernel/ged/hal", F_OK) == 0) {
        tweak("2", "/sys/kernel/ged/hal/loading_base_dvfs_step");
        tweak("1", "/sys/kernel/ged/hal/loading_stride_size");
        tweak("16", "/sys/kernel/ged/hal/loading_window_size");
    }
}

static void mtkvest_normal() {
    if (access("/sys/kernel/ged/hal", F_OK) == 0) {
        tweak("4", "/sys/kernel/ged/hal/loading_base_dvfs_step");
        tweak("2", "/sys/kernel/ged/hal/loading_stride_size");
        tweak("8", "/sys/kernel/ged/hal/loading_window_size");
    }
}

static char* get_mtk_legacy_gpu_maxfreq() {
    static char freq[32] = "";
    char buffer[4096] = {0};
    
    if (moco("/proc/gpufreq/gpufreq_opp_dump", buffer, sizeof(buffer)) <= 0) return NULL;
    
    char *line = strtok(buffer, "\n");
    while (line != NULL) {
        char *freq_ptr = strstr(line, "freq = ");
        if (freq_ptr) {
            freq_ptr += 7;
            int i = 0;
            while (freq_ptr[i] >= '0' && freq_ptr[i] <= '9' && i < 31) {
                freq[i] = freq_ptr[i];
                i++;
            }
            freq[i] = '\0';
            return freq; // First occurrence is max freq
        }
        line = strtok(NULL, "\n");
    }
    return NULL;
}

static char* get_mtk_legacy_gpu_minfreq() {
    static char last_freq[32] = "";
    char buffer[4096] = {0};
    
    if (moco("/proc/gpufreq/gpufreq_opp_dump", buffer, sizeof(buffer)) <= 0) return NULL;
    
    char *line = strtok(buffer, "\n");
    while (line != NULL) {
        char *freq_ptr = strstr(line, "freq = ");
        if (freq_ptr) {
            freq_ptr += 7;
            int i = 0;
            char temp_freq[32];
            while (freq_ptr[i] >= '0' && freq_ptr[i] <= '9' && i < 31) {
                temp_freq[i] = freq_ptr[i];
                i++;
            }
            temp_freq[i] = '\0';
            strcpy(last_freq, temp_freq);
        }
        line = strtok(NULL, "\n");
    }
    return strlen(last_freq) > 0 ? last_freq : NULL;
}

// ==========================================
// MediaTek Profiles
// ==========================================

void mediatek_awaken() {
    tweak("1", "/proc/cpufreq/cpufreq_cci_mode");
    tweak("3", "/proc/cpufreq/cpufreq_power_mode");
    tweak("1", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    tweak("0", "/sys/devices/system/cpu/eas/enable");
    tweak("0", "/sys/kernel/eara_thermal/enable");
    
    mtkvest_perf();
    
    // Inlined Yanz MTK Boost
    tweak("1", "/sys/pnpmgr/mwn");
    tweak("1", "/sys/pnpmgr/boost_enable");
    tweak("turbo", "/sys/pnpmgr/boost_mode");
    tweak("1", "/sys/module/ged/parameters/gx_boost_on");
    tweak("1", "/sys/module/ged/parameters/gx_game_mode");
    tweak("1", "/sys/module/ged/parameters/ged_smart_boost");
    tweak("1", "/sys/module/ged/parameters/enable_gpu_boost");
    tweak("1", "/sys/module/ged/parameters/ged_boost_enable");
    tweak("100", "/sys/kernel/ged/hal/gpu_boost_level");
    tweak("0", "/sys/module/ged/parameters/is_GED_KPI_enabled");
    tweak("1", "/sys/module/ged/parameters/gx_frc_mode");
    tweak("1", "/sys/module/ged/parameters/cpu_boost_policy");
    tweak("1", "/sys/module/ged/parameters/boost_extra");
    
    tweak("stop 1", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");
    
    if (access("/proc/gpufreq/gpufreq_power_limited", F_OK) == 0) {
        const char *limits[] = {"ignore_batt_oc 1\n", "ignore_batt_percent 1\n", "ignore_low_batt 1\n", "ignore_thermal_protect 1\n", "ignore_pbm_limited 1\n"};
        for (int i = 0; i < 5; i++) tweak(limits[i], "/proc/gpufreq/gpufreq_power_limited");
    }

    if (access("/proc/gpufreqv2", F_OK) == 0) {
        tweak("0\n", "/proc/gpufreqv2/fix_target_opp_index");
    } else {
        char *max_freq = get_mtk_legacy_gpu_maxfreq();
        if (max_freq) {
            char freq_nl[64]; 
            snprintf(freq_nl, sizeof(freq_nl), "%s\n", max_freq);
            tweak(freq_nl, "/proc/gpufreq/gpufreq_opp_freq");
        }
    }
    
    tweak("0", "/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp");
    tweak("0", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");
    devfreq_max_perf("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}

void mediatek_balanced() {
    tweak("0", "/proc/cpufreq/cpufreq_cci_mode");
    tweak("0", "/proc/cpufreq/cpufreq_power_mode");
    tweak("0", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    tweak("2", "/sys/devices/system/cpu/eas/enable");
    tweak("stop 0", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");

    kakangku("0\n", "/proc/gpufreq/gpufreq_opp_freq");
    kakangku("-1\n", "/proc/gpufreqv2/fix_target_opp_index");

    char *min_freq = get_mtk_legacy_gpu_minfreq();
    if (min_freq) tweak(min_freq, "/sys/kernel/ged/hal/custom_boost_gpu_freq");

    if (access("/proc/gpufreq/gpufreq_power_limited", F_OK) == 0) {
        const char *limits[] = {"ignore_batt_oc 0\n", "ignore_batt_percent 0\n", "ignore_low_batt 0\n", "ignore_thermal_protect 0\n", "ignore_pbm_limited 0\n"};
        for (int i = 0; i < 5; i++) tweak(limits[i], "/proc/gpufreq/gpufreq_power_limited");
    }

    kakangku("-1", "/sys/devices/platform/10012000.dvfsrc/helio-dvfsrc/dvfsrc_req_ddr_opp");
    kakangku("-1", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");
    devfreq_unlock("/sys/class/devfreq/mtk-dvfsrc-devfreq");
    tweak("1", "/sys/kernel/eara_thermal/enable");

    mtkvest_normal();
    
    // Inlined Yanz MTK Balance
    tweak("0", "/sys/pnpmgr/mwn");
    tweak("0", "/sys/pnpmgr/boost_enable");
    tweak("0", "/sys/pnpmgr/boost_mode");
    tweak("0", "/sys/module/ged/parameters/gx_boost_on");
    tweak("0", "/sys/module/ged/parameters/gx_game_mode");
    tweak("0", "/sys/module/ged/parameters/ged_smart_boost");
    tweak("0", "/sys/module/ged/parameters/enable_gpu_boost");
    tweak("0", "/sys/module/ged/parameters/ged_boost_enable");
    tweak("-1", "/sys/kernel/ged/hal/gpu_boost_level");
    tweak("1", "/sys/module/ged/parameters/is_GED_KPI_enabled");
    tweak("0", "/sys/module/ged/parameters/gx_frc_mode");
    tweak("0", "/sys/module/ged/parameters/cpu_boost_policy");
    tweak("0", "/sys/module/ged/parameters/boost_extra");
}

void mediatek_powersave() {
    tweak("1", "/proc/cpufreq/cpufreq_power_mode");
    
    if (access("/proc/gpufreqv2", F_OK) == 0) {
        tweak("-1\n", "/proc/gpufreqv2/fix_target_opp_index"); 
    } else {
        char *min_freq = get_mtk_legacy_gpu_minfreq();
        if (min_freq && min_freq[0]) {
            char freq_nl[64]; 
            snprintf(freq_nl, sizeof(freq_nl), "%s\n", min_freq);
            tweak(freq_nl, "/proc/gpufreq/gpufreq_opp_freq");
        }
    }
    
    // Inlined Yanz MTK Balance (used for powersave)
    tweak("0", "/sys/pnpmgr/mwn");
    tweak("0", "/sys/pnpmgr/boost_enable");
    tweak("0", "/sys/pnpmgr/boost_mode");
    tweak("0", "/sys/module/ged/parameters/gx_boost_on");
    tweak("0", "/sys/module/ged/parameters/gx_game_mode");
    tweak("0", "/sys/module/ged/parameters/ged_smart_boost");
    tweak("0", "/sys/module/ged/parameters/enable_gpu_boost");
    tweak("0", "/sys/module/ged/parameters/ged_boost_enable");
    tweak("-1", "/sys/kernel/ged/hal/gpu_boost_level");
    tweak("1", "/sys/module/ged/parameters/is_GED_KPI_enabled");
    tweak("0", "/sys/module/ged/parameters/gx_frc_mode");
    tweak("0", "/sys/module/ged/parameters/cpu_boost_policy");
    tweak("0", "/sys/module/ged/parameters/boost_extra");
}

void mediatek_normal() {
    mediatek_balanced();
}

// ==========================================
// Snapdragon Profiles
// ==========================================

void process_qcom_devfreqs(int mode) {
    const char *patterns[] = {
        "/sys/class/devfreq/*cpu*-lat", "/sys/class/devfreq/*cpu*-bw",
        "/sys/class/devfreq/*llccbw*", "/sys/class/devfreq/*bus_llcc*", 
        "/sys/class/devfreq/*bus_ddr*", "/sys/class/devfreq/*memlat*", 
        "/sys/class/devfreq/*cpubw*", "/sys/class/devfreq/*kgsl-ddr-qos*", NULL
    };
    
    glob_t globbuf;
    for (int i = 0; patterns[i] != NULL; i++) {
        if (glob(patterns[i], 0, NULL, &globbuf) == 0) {
            for (size_t j = 0; j < globbuf.gl_pathc; j++) {
                if (mode == 1) devfreq_max_perf(globbuf.gl_pathv[j]);
                else if (mode == 2) devfreq_mid_perf(globbuf.gl_pathv[j]);
                else devfreq_unlock(globbuf.gl_pathv[j]);
            }
            globfree(&globbuf);
        }
    }
}

void snapdragon_awaken() {
    if (config.device_mitigation == 0) {
        process_qcom_devfreqs(1);
        const char *dcvs[] = {"DDR", "LLCC", "L3"};
        for (int i = 0; i < 3; i++) {
            char path[256]; 
            snprintf(path, sizeof(path), "/sys/devices/system/cpu/bus_dcvs/%s", dcvs[i]);
            qcom_cpudcvs_max_perf(path);
        }
    }

    const char* gpu_path = "/sys/class/kgsl/kgsl-3d0/devfreq";
    devfreq_max_perf(gpu_path);
    
    tweak("0", "/sys/class/kgsl/kgsl-3d0/bus_split");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/force_clk_on");
    
    // Inlined Yanz Snapdragon Boost
    tweak("3", "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost");
    tweak("Y", "/sys/module/adreno_idler/parameters/adreno_idler_active");
    tweak("0", "/sys/class/kgsl/kgsl-3d0/throttling");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/default_pwrlevel");
    tweak("1", "/sys/module/msm_perfmon/parameters/touch_boost_enable");
    tweak("1", "/sys/module/msm_perfmon/parameters/touch_boost_freq");
    tweak("1", "/sys/module/msm_performance/parameters/touchboost");
    tweak("1", "/sys/power/pnpmgr/touch_boost");
    tweak("1", "/sys/devices/system/cpu/cpu0/core_ctl/enable");
    tweak("1", "/sys/devices/system/cpu/cpu4/core_ctl/enable");
}

void snapdragon_balanced() {
    snapdragon_normal();
}

void snapdragon_powersave() {
    devfreq_min_perf("/sys/class/kgsl/kgsl-3d0/devfreq");
    
    // Inlined Yanz Snapdragon Balance (used for powersave baseline)
    tweak("0", "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/throttling");
    tweak("0", "/sys/module/msm_perfmon/parameters/touch_boost_enable");
    tweak("0", "/sys/module/msm_perfmon/parameters/touch_boost_freq");
    tweak("0", "/sys/module/msm_performance/parameters/touchboost");
    tweak("0", "/sys/power/pnpmgr/touch_boost");
    
    tweak("Y", "/sys/module/adreno_idler/parameters/adreno_idler_active");
}

void snapdragon_normal() {
    if (config.device_mitigation == 0) {
        process_qcom_devfreqs(0);
        const char *dcvs[] = {"DDR", "LLCC", "L3"};
        for (int i = 0; i < 3; i++) {
            char path[256]; 
            snprintf(path, sizeof(path), "/sys/devices/system/cpu/bus_dcvs/%s", dcvs[i]);
            qcom_cpudcvs_unlock(path);
        }
    }

    devfreq_unlock("/sys/class/kgsl/kgsl-3d0/devfreq");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/bus_split");
    tweak("0", "/sys/class/kgsl/kgsl-3d0/force_clk_on");
    
    // Inlined Yanz Snapdragon Balance
    tweak("0", "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/throttling");
    tweak("0", "/sys/module/msm_perfmon/parameters/touch_boost_enable");
    tweak("0", "/sys/module/msm_perfmon/parameters/touch_boost_freq");
    tweak("0", "/sys/module/msm_performance/parameters/touchboost");
    tweak("0", "/sys/power/pnpmgr/touch_boost");
}

// ==========================================
// Exynos Profiles
// ==========================================

void exynos_awaken() {
    char avail_path[256];
    snprintf(avail_path, sizeof(avail_path), "/sys/kernel/gpu/gpu_available_frequencies");
    char *max_freq = get_maxfreq(avail_path);
    if (max_freq && max_freq[0]) {
        tweak(max_freq, "/sys/kernel/gpu/gpu_max_clock");
        tweak(max_freq, "/sys/kernel/gpu/gpu_min_clock");
    }
    
    glob_t globbuf;
    if (glob("/sys/devices/platform/*.mali/power_policy", 0, NULL, &globbuf) == 0 && globbuf.gl_pathc > 0) {
        tweak("always_on", globbuf.gl_pathv[0]);
        globfree(&globbuf);
    }

    if (config.device_mitigation == 0) {
        if (glob("/sys/class/devfreq/*devfreq_mif*", 0, NULL, &globbuf) == 0) {
            for (size_t i = 0; i < globbuf.gl_pathc; i++) {
                devfreq_max_perf(globbuf.gl_pathv[i]);
            }
            globfree(&globbuf);
        }
    }
}

void exynos_balanced() {
    exynos_normal();
}

void exynos_powersave() {
    char avail_path[256];
    snprintf(avail_path, sizeof(avail_path), "/sys/kernel/gpu/gpu_available_frequencies");
    char *min_freq = get_minfreq(avail_path);
    if (min_freq && min_freq[0]) {
        tweak(min_freq, "/sys/kernel/gpu/gpu_min_clock");
        tweak(min_freq, "/sys/kernel/gpu/gpu_max_clock");
    }
}

void exynos_normal() {
    char avail_path[256];
    snprintf(avail_path, sizeof(avail_path), "/sys/kernel/gpu/gpu_available_frequencies");
    char *max_freq = get_maxfreq(avail_path);
    char *min_freq = get_minfreq(avail_path);
    if (max_freq && max_freq[0]) {
        kakangku(max_freq, "/sys/kernel/gpu/gpu_max_clock");
        kakangku(min_freq, "/sys/kernel/gpu/gpu_min_clock");
    }
    
    glob_t globbuf;
    if (glob("/sys/devices/platform/*.mali/power_policy", 0, NULL, &globbuf) == 0 && globbuf.gl_pathc > 0) {
        tweak("coarse_demand", globbuf.gl_pathv[0]);
        globfree(&globbuf);
    }

    if (config.device_mitigation == 0) {
        if (glob("/sys/class/devfreq/*devfreq_mif*", 0, NULL, &globbuf) == 0) {
            for (size_t i = 0; i < globbuf.gl_pathc; i++) devfreq_unlock(globbuf.gl_pathv[i]);
            globfree(&globbuf);
        }
    }
}

// ==========================================
// Unisoc Profiles
// ==========================================

void process_unisoc_gpu(int mode) {
    glob_t globbuf;
    if (glob("/sys/class/devfreq/*.gpu", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) {
            if (mode == 1) devfreq_max_perf(globbuf.gl_pathv[i]);
            else if (mode == 2) devfreq_mid_perf(globbuf.gl_pathv[i]);
            else if (mode == 3) devfreq_min_perf(globbuf.gl_pathv[i]);
            else devfreq_unlock(globbuf.gl_pathv[i]);
        }
        globfree(&globbuf);
    }
}

void unisoc_awaken() { process_unisoc_gpu(1); }
void unisoc_balanced() { process_unisoc_gpu(0); }
void unisoc_powersave() { process_unisoc_gpu(3); }
void unisoc_normal() { process_unisoc_gpu(0); }

// ==========================================
// Tensor Profiles
// ==========================================

char* get_tensor_gpu_path() {
    static char path[256] = "";
    if (strlen(path) > 0) return path;
    glob_t globbuf;
    if (glob("/sys/devices/platform/*mali*", 0, NULL, &globbuf) == 0 && globbuf.gl_pathc > 0) {
        strcpy(path, globbuf.gl_pathv[0]);
        globfree(&globbuf);
    }
    return path;
}

void process_tensor_mif(int mode) {
    glob_t globbuf;
    if (glob("/sys/class/devfreq/*devfreq_mif*", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) {
            if (mode == 1) devfreq_max_perf(globbuf.gl_pathv[i]);
            else if (mode == 2) devfreq_mid_perf(globbuf.gl_pathv[i]);
            else devfreq_unlock(globbuf.gl_pathv[i]);
        }
        globfree(&globbuf);
    }
}

void tensor_awaken() {
    char *gpu_path = get_tensor_gpu_path();
    if (strlen(gpu_path) > 0) {
        char avail_path[256], max_path[256], min_path[256];
        snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", gpu_path);
        snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", gpu_path);
        snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", gpu_path);

        char *max_freq = get_maxfreq(avail_path);
        if (max_freq && max_freq[0]) {
            tweak(max_freq, max_path);
            tweak(max_freq, min_path);
        }
    }
    if (config.device_mitigation == 0) process_tensor_mif(1);
}

void tensor_balanced() { tensor_normal(); }

void tensor_powersave() {
    char *gpu_path = get_tensor_gpu_path();
    if (strlen(gpu_path) > 0) {
        char avail_path[256], max_path[256], min_path[256];
        snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", gpu_path);
        snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", gpu_path);
        snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", gpu_path);

        char *min_freq = get_minfreq(avail_path);
        if (min_freq && min_freq[0]) {
            tweak(min_freq, min_path);
            tweak(min_freq, max_path);
        }
    }
}

void tensor_normal() {
    char *gpu_path = get_tensor_gpu_path();
    if (strlen(gpu_path) > 0) {
        char avail_path[256], max_path[256], min_path[256];
        snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", gpu_path);
        snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", gpu_path);
        snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", gpu_path);

        char *max_freq = get_maxfreq(avail_path);
        char *min_freq = get_minfreq(avail_path);
        if (max_freq && max_freq[0]) {
            kakangku(max_freq, max_path);
            kakangku(min_freq, min_path);
        }
    }
    if (config.device_mitigation == 0) process_tensor_mif(0);
}

// ==========================================
// Tegra Profiles
// ==========================================

void tegra_awaken() {
    const char *gpu_path = "/sys/kernel/tegra_gpu";
    char avail_path[256], cap_path[256], floor_path[256];
    snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", gpu_path);
    snprintf(cap_path, sizeof(cap_path), "%s/gpu_cap_rate", gpu_path);
    snprintf(floor_path, sizeof(floor_path), "%s/gpu_floor_rate", gpu_path);

    char *max_freq = get_maxfreq(avail_path);
    if (max_freq && max_freq[0]) {
        tweak(max_freq, cap_path);
        tweak(max_freq, floor_path);
    }
}

void tegra_balanced() { tegra_normal(); }

void tegra_powersave() {
    const char *gpu_path = "/sys/kernel/tegra_gpu";
    char avail_path[256], cap_path[256], floor_path[256];
    snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", gpu_path);
    snprintf(cap_path, sizeof(cap_path), "%s/gpu_cap_rate", gpu_path);
    snprintf(floor_path, sizeof(floor_path), "%s/gpu_floor_rate", gpu_path);

    char *min_freq = get_minfreq(avail_path);
    if (min_freq && min_freq[0]) {
        tweak(min_freq, floor_path);
        tweak(min_freq, cap_path);
    }
}

void tegra_normal() {
    const char *gpu_path = "/sys/kernel/tegra_gpu";
    char avail_path[256], cap_path[256], floor_path[256];
    snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", gpu_path);
    snprintf(cap_path, sizeof(cap_path), "%s/gpu_cap_rate", gpu_path);
    snprintf(floor_path, sizeof(floor_path), "%s/gpu_floor_rate", gpu_path);

    char *max_freq = get_maxfreq(avail_path);
    char *min_freq = get_minfreq(avail_path);
    if (max_freq && max_freq[0]) {
        kakangku(max_freq, cap_path);
        kakangku(min_freq, floor_path);
    }
}