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
// Generic CPUFreq Setters
// ==========================================

void cpufreq_reset_limits() {
    glob_t globbuf;
    if (glob("/sys/devices/system/cpu/cpufreq/policy*", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) {
            char path_min[256], path_max[256], info_min[256], info_max[256];
            snprintf(path_min, sizeof(path_min), "%s/scaling_min_freq", globbuf.gl_pathv[i]);
            snprintf(path_max, sizeof(path_max), "%s/scaling_max_freq", globbuf.gl_pathv[i]);
            snprintf(info_min, sizeof(info_min), "%s/cpuinfo_min_freq", globbuf.gl_pathv[i]);
            snprintf(info_max, sizeof(info_max), "%s/cpuinfo_max_freq", globbuf.gl_pathv[i]);

            FILE *f; char hw_min[32] = {0}, hw_max[32] = {0};
            if ((f = fopen(info_min, "r"))) { fscanf(f, "%31s", hw_min); fclose(f); }
            if ((f = fopen(info_max, "r"))) { fscanf(f, "%31s", hw_max); fclose(f); }

            chmod(path_min, 0644); chmod(path_max, 0644);
            if (hw_min[0]) tweak(hw_min, path_min);
            if (hw_max[0]) tweak(hw_max, path_max);
        }
        globfree(&globbuf);
    }
}

void cpufreq_max_perf() {
    cpufreq_reset_limits();
    glob_t globbuf;
    if (glob("/sys/devices/system/cpu/cpufreq/policy*", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) {
            char path_min[256], path_max[256], info_max[256], avail[256];
            snprintf(path_min, sizeof(path_min), "%s/scaling_min_freq", globbuf.gl_pathv[i]);
            snprintf(path_max, sizeof(path_max), "%s/scaling_max_freq", globbuf.gl_pathv[i]);
            snprintf(info_max, sizeof(info_max), "%s/cpuinfo_max_freq", globbuf.gl_pathv[i]);
            snprintf(avail, sizeof(avail), "%s/scaling_available_frequencies", globbuf.gl_pathv[i]);

            FILE *f; char hw_max[32] = {0};
            if ((f = fopen(info_max, "r"))) { fscanf(f, "%31s", hw_max); fclose(f); }
            
            if (config.lite_mode == 0) {
                tweak(hw_max, path_min);
            } else {
                tweak(get_midfreq(avail), path_min);
            }
            tweak(hw_max, path_max);
        }
        globfree(&globbuf);
    }
}

void cpufreq_min_perf() {
    cpufreq_reset_limits();
    glob_t globbuf;
    if (glob("/sys/devices/system/cpu/cpufreq/policy*", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) {
            char path_min[256], path_max[256], info_min[256], avail[256];
            snprintf(path_min, sizeof(path_min), "%s/scaling_min_freq", globbuf.gl_pathv[i]);
            snprintf(path_max, sizeof(path_max), "%s/scaling_max_freq", globbuf.gl_pathv[i]);
            snprintf(info_min, sizeof(info_min), "%s/cpuinfo_min_freq", globbuf.gl_pathv[i]);
            snprintf(avail, sizeof(avail), "%s/scaling_available_frequencies", globbuf.gl_pathv[i]);

            FILE *f; char hw_min[32] = {0};
            if ((f = fopen(info_min, "r"))) { fscanf(f, "%31s", hw_min); fclose(f); }

            tweak(hw_min, path_min);
            if (config.better_powersave == 1) {
                tweak(get_midfreq(avail), path_max);
            } else {
                tweak(hw_min, path_max);
            }
        }
        globfree(&globbuf);
    }
}

// ==========================================
// Mode Executives
// ==========================================

void performance_basic() {
    sync();
    
    // Block IO
    glob_t globbuf;
    if (glob("/sys/block/*/queue/iostats", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) tweak("0", globbuf.gl_pathv[i]);
        globfree(&globbuf);
    }
    if (glob("/sys/block/*/queue/read_ahead_kb", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) tweak("32", globbuf.gl_pathv[i]);
        globfree(&globbuf);
    }

    // Network & Kernel
    tweak("1", "/proc/sys/net/ipv4/tcp_low_latency");
    tweak("3", "/proc/sys/net/ipv4/tcp_fastopen");
    tweak("3", "/proc/sys/kernel/perf_cpu_time_max_percent");
    tweak("0", "/proc/sys/kernel/sched_schedstats");
    tweak("1", "/proc/sys/kernel/sched_child_runs_first");
    
    tweak("0", "/proc/sys/vm/page-cluster");
    tweak("15", "/proc/sys/vm/stat_interval");
    tweak("80", "/proc/sys/vm/vfs_cache_pressure");

    // Apply Profile CPU
    change_cpu_gov("performance");
    sleep(1);
    cpufreq_max_perf();

    switch (config.soc) {
        case 1: mediatek_performance(); break;
        case 2: snapdragon_performance(); break;
        case 3: exynos_performance(); break;
        case 4: unisoc_performance(); break;
        case 5: tensor_performance(); break;
        case 6: tegra_performance(); break;
    }

    corin_perf();
    if (config.kcpu_mitigate == 0) carcpu_perf();
    
    if (config.include_anya && config.anya) {
        system("sh /data/adb/modules/ProjectRaco/Scripts/AnyaMelfissa.sh &");
    }
}

void balanced_basic() {
    sync();

    // Reset Block IO
    glob_t globbuf;
    if (glob("/sys/block/*/queue/iostats", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) kakangku("1", globbuf.gl_pathv[i]);
        globfree(&globbuf);
    }
    if (glob("/sys/block/*/queue/read_ahead_kb", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) kakangku("128", globbuf.gl_pathv[i]);
        globfree(&globbuf);
    }

    kakangku("120", "/proc/sys/vm/vfs_cache_pressure");

    cpufreq_reset_limits();
    change_cpu_gov(config.default_cpu_gov);

    switch (config.soc) {
        case 1: mediatek_normal(); break;
        case 2: snapdragon_normal(); break;
        case 3: exynos_normal(); break;
        case 4: unisoc_normal(); break;
        case 5: tensor_normal(); break;
        case 6: tegra_normal(); break;
    }
    
    corin_balanced();
    if (config.kcpu_mitigate == 0) carcpu_balance();

    if (config.include_anya && config.anya) {
        system("sh /data/adb/modules/ProjectRaco/Scripts/AnyaKawaii.sh &");
    }
}

void powersave_basic() {
    sync();
    kakangku("100", "/proc/sys/vm/vfs_cache_pressure");

    cpufreq_reset_limits();
    change_cpu_gov("powersave");
    sleep(1);
    cpufreq_min_perf();

    switch (config.soc) {
        case 1: mediatek_powersave(); break;
        case 2: snapdragon_powersave(); break;
        case 3: exynos_powersave(); break;
        case 4: unisoc_powersave(); break;
        case 5: tensor_powersave(); break;
        case 6: tegra_powersave(); break;
    }

    corin_powersave();
    if (config.kcpu_mitigate == 0) carcpu_battery();

    if (config.include_anya && config.anya) {
        system("sh /data/adb/modules/ProjectRaco/Scripts/AnyaKawaii.sh &");
    }
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s <mode>\n", argv[0]);
        return 1;
    }

    load_config();
    int mode = atoi(argv[1]);

    switch (mode) {
        case 1:
            performance_basic();
            set_state(1);
            printf("Performance Mode Activated 🔥\n");
            break;
        case 2:
            balanced_basic();
            set_state(2);
            printf("Balanced Mode Activated ⚖️\n");
            break;
        case 3:
            powersave_basic();
            set_state(3);
            printf("Powersave Mode Activated 🔋\n");
            break;
        case 4:
            performance_basic();
            raco_kill_all();
            set_state(4);
            printf("Gaming Pro Mode Activated 🚀\n");
            break;
        case 5:
            powersave_basic();
            set_state(5);
            printf("Cool Down initiated for 2 minutes... ❄️\n");
            sleep(120);
            balanced_basic();
            set_state(2);
            printf("Cool Down finished. Switched to Balanced Mode.\n");
            break;
        case 6:
            raco_kill_all();
            printf("All background applications cleared. ✅\n");
            break;
        default:
            printf("Error: Invalid mode '%d'.\n", mode);
            return 1;
    }
    return 0;
}