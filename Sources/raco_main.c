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
// CPUFreq Setters
// ==========================================

void apply_cpufreq_policy(const char *policy_path, int mode) {
    char min_path[256], max_path[256], hw_min_path[256], hw_max_path[256];
    char hw_min[32] = {0}, hw_max[32] = {0};

    // Construct paths using Tenebrion's logic pattern
    snprintf(hw_min_path, sizeof(hw_min_path), "%s/cpuinfo_min_freq", policy_path);
    snprintf(hw_max_path, sizeof(hw_max_path), "%s/cpuinfo_max_freq", policy_path);
    snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", policy_path);
    snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", policy_path);

    // Read hardware frequency limits using Assembly
    moco(hw_min_path, hw_min, sizeof(hw_min));
    moco(hw_max_path, hw_max, sizeof(hw_max));

    // Strip trailing newlines typical of sysfs nodes
    hw_min[strcspn(hw_min, "\n")] = 0;
    hw_max[strcspn(hw_max, "\n")] = 0;

    // Safety check to ensure we obtained valid frequencies
    if (!hw_min[0] || !hw_max[0]) return;

    chmod(min_path, 0644); 
    chmod(max_path, 0644);

    if (mode == 1) {
        // Mode 1: Max Performance
        tweak(config.lite_mode ? hw_min : hw_max, min_path); 
        tweak(hw_max, max_path);
    } else if (mode == 2) {
        // Mode 2: Minimum Performance / Powersave
        tweak(hw_min, min_path);
        tweak(config.better_powersave ? hw_max : hw_min, max_path); 
    }
}

void execute_cpufreq_mode(int mode) {
    glob_t globbuf;
    if (glob("/sys/devices/system/cpu/cpufreq/policy*", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) {
            // Directly apply the bounds
            apply_cpufreq_policy(globbuf.gl_pathv[i], mode);
        }
        globfree(&globbuf);
    }
}

// Simplified function calls
void cpufreq_max_perf()     { execute_cpufreq_mode(1); }
void cpufreq_min_perf()     { execute_cpufreq_mode(2); }

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