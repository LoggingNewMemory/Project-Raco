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
    if (!max_freq || !max_freq[0]) return; // 'moco' failed to open the file

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
// MediaTek Profiles
// ==========================================

void mediatek_awaken() {
    tweak("1", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    tweak("0", "/sys/devices/system/cpu/eas/enable");
    tweak("0", "/sys/kernel/eara_thermal/enable");
    
    tweak("1", "/sys/pnpmgr/mwn");
    tweak("1", "/sys/pnpmgr/boost_enable");
    tweak("turbo", "/sys/pnpmgr/boost_mode");
    tweak("1", "/sys/module/ged/parameters/gx_boost_on");
    tweak("1", "/sys/module/ged/parameters/gx_game_mode");
    tweak("1", "/sys/module/ged/parameters/ged_smart_boost");
    tweak("1", "/sys/module/ged/parameters/enable_gpu_boost");
    tweak("1", "/sys/module/ged/parameters/ged_boost_enable");
    
    tweak("stop 1", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");
    tweak("0", "/proc/gpufreqv2/fix_target_opp_index");
    tweak("0", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");
    devfreq_max_perf("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}

void mediatek_balanced() {
    tweak("0", "/sys/pnpmgr/mwn");
    tweak("0", "/sys/pnpmgr/boost_enable");
    tweak("0", "/sys/pnpmgr/boost_mode");
    tweak("0", "/sys/module/ged/parameters/gx_boost_on");
    tweak("0", "/sys/module/ged/parameters/gx_game_mode");
    tweak("0", "/sys/module/ged/parameters/ged_smart_boost");

    devfreq_mid_perf("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}

void mediatek_powersave() {
    tweak("0", "/sys/pnpmgr/mwn");
    tweak("0", "/sys/pnpmgr/boost_enable");
    tweak("0", "/sys/pnpmgr/boost_mode");
    tweak("0", "/sys/module/ged/parameters/gx_boost_on");
    tweak("0", "/sys/module/ged/parameters/gx_game_mode");
    tweak("0", "/sys/module/ged/parameters/ged_smart_boost");

    devfreq_unlock("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}

void mediatek_normal() {
    tweak("0", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    tweak("2", "/sys/devices/system/cpu/eas/enable");
    tweak("stop 0", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");

    kakangku("-1", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");
    devfreq_unlock("/sys/class/devfreq/mtk-dvfsrc-devfreq");
    tweak("1", "/sys/kernel/eara_thermal/enable");

    tweak("0", "/sys/pnpmgr/mwn");
    tweak("0", "/sys/pnpmgr/boost_enable");
    tweak("0", "/sys/pnpmgr/boost_mode");
    tweak("0", "/sys/module/ged/parameters/gx_boost_on");
    tweak("0", "/sys/module/ged/parameters/gx_game_mode");
    tweak("0", "/sys/module/ged/parameters/ged_smart_boost");
}

// ==========================================
// Snapdragon Profiles
// ==========================================

void process_qcom_devfreqs(int mode) {
    const char *patterns[] = {
        "/sys/class/devfreq/*cpu*-lat", "/sys/class/devfreq/*cpu*-bw",
        "/sys/class/devfreq/*llccbw*", "/sys/class/devfreq/*bus_ddr*",
        "/sys/class/devfreq/*memlat*", "/sys/class/devfreq/*cpubw*", NULL
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

    devfreq_max_perf("/sys/class/kgsl/kgsl-3d0/devfreq");
    tweak("0", "/sys/class/kgsl/kgsl-3d0/bus_split");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/force_clk_on");
    
    tweak("3", "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost");
    tweak("Y", "/sys/module/adreno_idler/parameters/adreno_idler_active");
    tweak("0", "/sys/class/kgsl/kgsl-3d0/throttling");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/default_pwrlevel");
    tweak("1", "/sys/module/msm_perfmon/parameters/touch_boost_enable");
    tweak("1", "/sys/module/msm_performance/parameters/touchboost");
}

void snapdragon_balanced() {
    if (config.device_mitigation == 0) process_qcom_devfreqs(2);
    devfreq_mid_perf("/sys/class/kgsl/kgsl-3d0/devfreq");
    
    tweak("0", "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/throttling");
    tweak("0", "/sys/module/msm_perfmon/parameters/touch_boost_enable");
    tweak("0", "/sys/module/msm_performance/parameters/touchboost");
}

void snapdragon_powersave() {
    devfreq_unlock("/sys/class/kgsl/kgsl-3d0/devfreq");
    
    tweak("0", "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/throttling");
    tweak("0", "/sys/module/msm_perfmon/parameters/touch_boost_enable");
    tweak("0", "/sys/module/msm_performance/parameters/touchboost");
    
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
    
    tweak("0", "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/throttling");
    tweak("0", "/sys/module/msm_perfmon/parameters/touch_boost_enable");
    tweak("0", "/sys/module/msm_performance/parameters/touchboost");
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
}

void exynos_balanced() {
    char avail_path[256];
    snprintf(avail_path, sizeof(avail_path), "/sys/kernel/gpu/gpu_available_frequencies");
    char *max_freq = get_maxfreq(avail_path);
    char *mid_freq = get_midfreq(avail_path);
    if (max_freq && max_freq[0]) {
        tweak(max_freq, "/sys/kernel/gpu/gpu_max_clock");
        tweak(mid_freq, "/sys/kernel/gpu/gpu_min_clock");
    }
}

void exynos_powersave() {
    char avail_path[256];
    snprintf(avail_path, sizeof(avail_path), "/sys/kernel/gpu/gpu_available_frequencies");
    char *max_freq = get_maxfreq(avail_path);
    char *min_freq = get_minfreq(avail_path);
    if (max_freq && max_freq[0]) {
        kakangku(max_freq, "/sys/kernel/gpu/gpu_max_clock");
        kakangku(min_freq, "/sys/kernel/gpu/gpu_min_clock");
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

void unisoc_awaken() {
    process_unisoc_gpu(1);
}

void unisoc_balanced() {
    process_unisoc_gpu(0);
}

void unisoc_powersave() {
    process_unisoc_gpu(3);
}

void unisoc_normal() {
    process_unisoc_gpu(0);
}

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
    
    if (config.device_mitigation == 0) {
        process_tensor_mif(1);
    }
}

void tensor_balanced() {
    tensor_normal();
}

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
    
    if (config.device_mitigation == 0) {
        process_tensor_mif(0);
    }
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

void tegra_balanced() {
    tegra_normal();
}

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