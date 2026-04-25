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
#include "raco.h"
#include "raco_utils.h"

void cpufreq_reset_limits() {
    glob_t globbuf;
    if (glob("/sys/devices/system/cpu/cpufreq/policy*", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) {
            char path_min[256], path_max[256], path_info_min[256], path_info_max[256];
            snprintf(path_min, sizeof(path_min), "%s/scaling_min_freq", globbuf.gl_pathv[i]);
            snprintf(path_max, sizeof(path_max), "%s/scaling_max_freq", globbuf.gl_pathv[i]);
            snprintf(path_info_min, sizeof(path_info_min), "%s/cpuinfo_min_freq", globbuf.gl_pathv[i]);
            snprintf(path_info_max, sizeof(path_info_max), "%s/cpuinfo_max_freq", globbuf.gl_pathv[i]);

            FILE *f;
            char min_val[32] = {0}, max_val[32] = {0};
            if ((f = fopen(path_info_min, "r"))) { fscanf(f, "%31s", min_val); fclose(f); }
            if ((f = fopen(path_info_max, "r"))) { fscanf(f, "%31s", max_val); fclose(f); }

            if (min_val[0]) tweak(min_val, path_min);
            if (max_val[0]) tweak(max_val, path_max);
        }
        globfree(&globbuf);
    }
}

void cpufreq_max_perf() {
    cpufreq_reset_limits();
    glob_t globbuf;
    if (glob("/sys/devices/system/cpu/cpufreq/policy*", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) {
            char path_max_info[256], path_min[256], path_max[256];
            snprintf(path_max_info, sizeof(path_max_info), "%s/cpuinfo_max_freq", globbuf.gl_pathv[i]);
            snprintf(path_min, sizeof(path_min), "%s/scaling_min_freq", globbuf.gl_pathv[i]);
            snprintf(path_max, sizeof(path_max), "%s/scaling_max_freq", globbuf.gl_pathv[i]);

            FILE *f = fopen(path_max_info, "r");
            if (f) {
                char max_val[32] = {0};
                fscanf(f, "%31s", max_val);
                fclose(f);
                if (max_val[0]) {
                    tweak(max_val, path_min);
                    tweak(max_val, path_max);
                }
            }
        }
        globfree(&globbuf);
    }
}

void mtk_perf() {
    tweak("1", "/proc/cpufreq/cpufreq_cci_mode");
    tweak("3", "/proc/cpufreq/cpufreq_power_mode");
    tweak("1", "/sys/devices/platform/boot_dramboost/dramboost/dramboost");
    tweak("0", "/sys/devices/system/cpu/eas/enable");
    tweak("stop 1", "/proc/mtk_batoc_throttling/battery_oc_protect_stop");
    
    tweak("1", "/sys/pnpmgr/mwn");
    tweak("1", "/sys/pnpmgr/boost_enable");
    tweak("turbo", "/sys/pnpmgr/boost_mode");
    tweak("1", "/sys/module/ged/parameters/gx_boost_on");
    tweak("1", "/sys/module/ged/parameters/gx_game_mode");
    tweak("100", "/sys/kernel/ged/hal/gpu_boost_level");
}

void qcom_perf() {
    tweak("3", "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost");
    tweak("Y", "/sys/module/adreno_idler/parameters/adreno_idler_active");
    tweak("0", "/sys/class/kgsl/kgsl-3d0/throttling");
    tweak("1", "/sys/class/kgsl/kgsl-3d0/default_pwrlevel");
}

void raco_kill_all() {
    sync();
    system("cmd activity kill-all > /dev/null 2>&1");
    system("pm trim-caches 100G > /dev/null 2>&1");
    kakangku("3", "/proc/sys/vm/drop_caches");
}

void set_block_iostats(const char *val, const char *ra_val) {
    glob_t globbuf;
    if (glob("/sys/block/*/queue/iostats", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) tweak(val, globbuf.gl_pathv[i]);
        globfree(&globbuf);
    }
    if (ra_val && glob("/sys/block/*/queue/read_ahead_kb", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) tweak(ra_val, globbuf.gl_pathv[i]);
        globfree(&globbuf);
    }
}

void performance_basic() {
    sync();
    set_block_iostats("0", "32");
    tweak("1", "/proc/sys/net/ipv4/tcp_low_latency");
    tweak("3", "/proc/sys/net/ipv4/tcp_fastopen");

    tweak("3", "/proc/sys/kernel/perf_cpu_time_max_percent");
    tweak("0", "/proc/sys/kernel/sched_schedstats");
    tweak("1", "/proc/sys/kernel/sched_child_runs_first");
    
    // Virtual Memory Tweaks (Combined)
    tweak("0", "/proc/sys/vm/page-cluster");
    tweak("15", "/proc/sys/vm/stat_interval");
    tweak("80", "/proc/sys/vm/vfs_cache_pressure");

    change_cpu_gov("performance");
    sleep(1);
    cpufreq_max_perf();

    switch (config.soc) {
        case 1: mtk_perf(); break;
        case 2: qcom_perf(); break;
        default: break;
    }

    corin_perf();
    if (config.kcpu_mitigate == 0) carcpu_perf();
}

void powersave_basic() {
    sync();
    tweak("100", "/proc/sys/vm/vfs_cache_pressure");
    cpufreq_reset_limits();
    change_cpu_gov("powersave");
    corin_powersave();
    if (config.kcpu_mitigate == 0) carcpu_battery();
}

void balanced_basic() {
    sync();
    set_block_iostats("1", NULL);
    kakangku("120", "/proc/sys/vm/vfs_cache_pressure");

    cpufreq_reset_limits();
    change_cpu_gov(config.default_cpu_gov);
    
    corin_balanced();
    if (config.kcpu_mitigate == 0) carcpu_balance();
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
            printf("Performance Mode Activated\n");
            break;
        case 2:
            balanced_basic();
            set_state(2);
            printf("Balanced Mode Activated\n");
            break;
        case 3:
            powersave_basic();
            set_state(3);
            printf("Powersave Mode Activated\n");
            break;
        case 4:
            performance_basic();
            raco_kill_all();
            set_state(4);
            printf("Gaming Pro Mode Activated\n");
            break;
        case 5:
            powersave_basic();
            printf("Cool Down initiated for 2 minutes...\n");
            sleep(120);
            balanced_basic();
            set_state(2);
            break;
        case 6:
            clear_cache(); 
            raco_kill_all();
            run_fstrim();  
            printf("Background cleared, Cache trimmed.\n");
            break;
        case 7:
            kobo_fast_charge(); 
            printf("Kobo Fast Charge variables locked.\n");
            break;
        default:
            printf("Invalid mode.\n");
            return 1;
    }
    return 0;
}