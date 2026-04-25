/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
This program is free software: you can redistribute it and/or modify it under the terms of 
the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. 

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
See the GNU General Public License for more details. 
You should have received a copy of the GNU General Public License along with this program. 

If not, see https://www.gnu.org/licenses/.
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

    if (access(avail_path, F_OK) != 0) return;

    char *max_freq = get_maxfreq(avail_path);
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
    if (access(avail_path, F_OK) == 0) {
        char *freq = get_maxfreq(avail_path);
        tweak(freq, hw_max);
        tweak(freq, hw_min);
    }
}

void qcom_cpudcvs_mid_perf(const char *path) {
    char avail_path[256], hw_max[256], hw_min[256];
    snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", path);
    snprintf(hw_max, sizeof(hw_max), "%s/hw_max_freq", path);
    snprintf(hw_min, sizeof(hw_min), "%s/hw_min_freq", path);
    if (access(avail_path, F_OK) == 0) {
        tweak(get_maxfreq(avail_path), hw_max);
        tweak(get_midfreq(avail_path), hw_min);
    }
}

void qcom_cpudcvs_unlock(const char *path) {
    char avail_path[256], hw_max[256], hw_min[256];
    snprintf(avail_path, sizeof(avail_path), "%s/available_frequencies", path);
    snprintf(hw_max, sizeof(hw_max), "%s/hw_max_freq", path);
    snprintf(hw_min, sizeof(hw_min), "%s/hw_min_freq", path);
    if (access(avail_path, F_OK) == 0) {
        kakangku(get_maxfreq(avail_path), hw_max);
        kakangku(get_minfreq(avail_path), hw_min);
    }
}

// ==========================================
// MediaTek Profiles
// ==========================================

void yanz_mtk_boost() {
    tweak("1", "/sys/pnpmgr/mwn");
    tweak("1", "/sys/pnpmgr/boost_enable");
    tweak("turbo", "/sys/pnpmgr/boost_mode");
    tweak("1", "/sys/module/ged/parameters/gx_boost_on");
    tweak("1", "/sys/module/ged/parameters/gx_game_mode");
    tweak("1", "/sys/module/ged/parameters/ged_smart_boost");
    tweak("1", "/sys/module/ged/parameters/enable_gpu_boost");
    tweak("1", "/sys/module/ged/parameters/ged_boost_enable");
    tweak("100", "/sys/kernel/ged/hal/gpu_boost_level");
}

void yanz_mtk_balance() {
    tweak("0", "/sys/pnpmgr/mwn");
    tweak("0", "/sys/pnpmgr/boost_enable");
    tweak("0", "/sys/pnpmgr/boost_mode");
    tweak("0", "/sys/module/ged/parameters/gx_boost_on");
    tweak("0", "/sys/module/ged/parameters/gx_game_mode");
    tweak("0", "/sys/module/ged/parameters/ged_smart_boost");
    tweak("-1", "/sys/kernel/ged/hal/gpu_boost_level");
}

void mediatek_awaken() {
    tweak("1", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    tweak("0", "/sys/devices/system/cpu/eas/enable");
    tweak("0", "/sys/kernel/eara_thermal/enable");
    
    yanz_mtk_boost();
    tweak("stop 1", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");

    tweak("0", "/proc/gpufreqv2/fix_target_opp_index");
    tweak("0", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");
    devfreq_max_perf("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}

void mediatek_balanced() {
    yanz_mtk_balance();
    devfreq_mid_perf("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}

void mediatek_powersave() {
    yanz_mtk_balance();
    devfreq_unlock("/sys/class/devfreq/mtk-dvfsrc-devfreq");
}

void mediatek_normal() {
    tweak("0", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    tweak("2", "/sys/devices/system/cpu/eas/enable");
    tweak("stop 0", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");

    kakangku("-1", "/sys/kernel/helio-dvfsrc/dvfsrc_force_vcore_dvfs_opp");
    devfreq_unlock("/sys/class/devfreq/mtk-dvfsrc-devfreq");
    tweak("1", "/sys/kernel/eara_thermal/enable");

    yanz_mtk_balance();
}

// ==========================================
// Snapdragon Profiles
// ==========================================

void yanz_snapdragon_boost() {
    tweak("3", "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost");
    tweak("Y", "/sys/module/adreno_idler/parameters/adreno_idler_active");
    tweak("0", "/sys/class/kgsl/kgsl-3d0/throttling");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/default_pwrlevel");
    tweak("1", "/sys/module/msm_perfmon/parameters/touch_boost_enable");
    tweak("1", "/sys/module/msm_performance/parameters/touchboost");
}

void yanz_snapdragon_balance() {
    tweak("0", "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/throttling");
    tweak("0", "/sys/module/msm_perfmon/parameters/touch_boost_enable");
    tweak("0", "/sys/module/msm_performance/parameters/touchboost");
}

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
    yanz_snapdragon_boost();
}

void snapdragon_balanced() {
    if (config.device_mitigation == 0) process_qcom_devfreqs(2);
    devfreq_mid_perf("/sys/class/kgsl/kgsl-3d0/devfreq");
    yanz_snapdragon_balance();
}

void snapdragon_powersave() {
    // Flowchart requires GPU Set Release (No Clock Lock) for Powersave
    devfreq_unlock("/sys/class/kgsl/kgsl-3d0/devfreq");
    yanz_snapdragon_balance();
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
    yanz_snapdragon_balance();
}

// ==========================================
// Exynos Profiles
// ==========================================

void exynos_awaken() {
    char *gpu_path = "/sys/kernel/gpu";
    if (access(gpu_path, F_OK) == 0) {
        char avail_path[256];
        snprintf(avail_path, sizeof(avail_path), "%s/gpu_available_frequencies", gpu_path);
        char *max_freq = get_maxfreq(avail_path);
        tweak(max_freq, "/sys/kernel/gpu/gpu_max_clock");
        tweak(max_freq, "/sys/kernel/gpu/gpu_min_clock");
    }
}

void exynos_balanced() {
    char *gpu_path = "/sys/kernel/gpu";
    if (access(gpu_path, F_OK) == 0) {
        char avail_path[256];
        snprintf(avail_path, sizeof(avail_path), "%s/gpu_available_frequencies", gpu_path);
        tweak(get_maxfreq(avail_path), "/sys/kernel/gpu/gpu_max_clock");
        tweak(get_midfreq(avail_path), "/sys/kernel/gpu/gpu_min_clock");
    }
}

void exynos_powersave() {
    char *gpu_path = "/sys/kernel/gpu";
    if (access(gpu_path, F_OK) == 0) {
        char avail_path[256];
        snprintf(avail_path, sizeof(avail_path), "%s/gpu_available_frequencies", gpu_path);
        // Release Lock
        kakangku(get_maxfreq(avail_path), "/sys/kernel/gpu/gpu_max_clock");
        kakangku(get_minfreq(avail_path), "/sys/kernel/gpu/gpu_min_clock");
    }
}

void exynos_normal() {
    char *gpu_path = "/sys/kernel/gpu";
    if (access(gpu_path, F_OK) == 0) {
        char avail_path[256];
        snprintf(avail_path, sizeof(avail_path), "%s/gpu_available_frequencies", gpu_path);
        kakangku(get_maxfreq(avail_path), "/sys/kernel/gpu/gpu_max_clock");
        kakangku(get_minfreq(avail_path), "/sys/kernel/gpu/gpu_min_clock");
    }
}

// Stubs for Unisoc, Tensor, Tegra to match logic flow
void unisoc_awaken() {}
void unisoc_balanced() {}
void unisoc_powersave() {}
void unisoc_normal() {}

void tensor_awaken() {}
void tensor_balanced() {}
void tensor_powersave() {}
void tensor_normal() {}

void tegra_awaken() {}
void tegra_balanced() {}
void tegra_powersave() {}
void tegra_normal() {}