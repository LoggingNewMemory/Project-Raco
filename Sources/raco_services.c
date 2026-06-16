/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
*/

#define _GNU_SOURCE
#include "raco.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <ctype.h>
#include <glob.h>
#include <sched.h>
#include <sys/resource.h>

// Global Variables
int inc_kobo = 0;
int inc_zeta = 0;
int inc_sandev = 0;
int sandev_dur = 600;
char default_gov[64] = {0};

// Case-insensitive substring finder helper
char *my_strcasestr(const char *haystack, const char *needle) {
    if (!haystack || !needle) return NULL;
    for (; *haystack; haystack++) {
        const char *h = haystack, *n = needle;
        while (*h && *n && tolower((unsigned char)*h) == tolower((unsigned char)*n)) {
            h++;
            n++;
        }
        if (!*n) return (char *)haystack;
    }
    return NULL;
}


// Notification Helper
void send_notif(const char *title, const char *message, const char *tag, const char *icon_path) {
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"am startservice -n com.kanagawa.yamada.project.raco/.ToastOverlayService --es msg '%s: %s'\" >/dev/null 2>&1 &", title, message);
    system(cmd);
}

// Configuration parsing from /data/ProjectRaco/raco.txt
// NOTE: load_config() already reads raco.txt and now populates inc_kobo/inc_zeta/
// inc_sandev/sandev_dur/default_gov directly into the global `config` struct.
// This function exists only to copy those values into the legacy local globals
// used by the rest of raco_services.c, avoiding a second file read.
void parse_service_config() {
    load_config("/data/ProjectRaco/raco.txt");

    // Mirror the values load_config() already parsed into the local globals.
    inc_kobo    = config.inc_kobo;
    inc_zeta    = config.inc_zeta;
    inc_sandev  = config.inc_sandev;
    sandev_dur  = config.sandev_dur > 0 ? config.sandev_dur : 300;
    if (config.default_gov[0] != '\0') {
        strncpy(default_gov, config.default_gov, sizeof(default_gov) - 1);
    }
}

// Mali Scheduler Tweaks
void apply_mali_tweaks() {
    DIR *dir = opendir("/sys/devices/platform/soc");
    if (dir != NULL) {
        struct dirent *ent;
        char mali_dir_path[512] = {0};
        char mali1_dir_path[512] = {0};
        while ((ent = readdir(dir)) != NULL) {
            if (strstr(ent->d_name, "mali") != NULL) {
                snprintf(mali_dir_path, sizeof(mali_dir_path), "/sys/devices/platform/soc/%s/scheduling", ent->d_name);
                snprintf(mali1_dir_path, sizeof(mali1_dir_path), "/sys/devices/platform/soc/%s", ent->d_name);
                break;
            }
        }
        closedir(dir);

        if (mali_dir_path[0] != '\0') {
            char file_path[512];
            snprintf(file_path, sizeof(file_path), "%s/serialize_jobs", mali_dir_path);
            rawrite("full", file_path);
        }
        if (mali1_dir_path[0] != '\0') {
            char file_path[512];
            snprintf(file_path, sizeof(file_path), "%s/js_ctx_scheduling_mode", mali1_dir_path);
            rawrite("1", file_path);
        }
    }
}

// Consolidated and Scoped System Optimizations (Facur, GHenna, Yanz Merged)
void apply_system_optimizations() {
    // 1. Filesystem & I/O optimizations (iostats only — scheduler left at kernel default)
    {
        rawrite("1", "/sys/module/workqueue/parameters/power_efficient");

        // Only disable iostats (safe), do NOT touch scheduler
        const char *devices[] = {
            "sda", "loop0", "loop1", "loop2", "loop3", "loop4", "loop5",
            "loop6", "loop7", "dm-0", "mmcblk0", "mmcblk1", "mmcblk0rpmb"
        };
        int dev_count = sizeof(devices) / sizeof(devices[0]);
        for (int i = 0; i < dev_count; i++) {
            char path[512];
            snprintf(path, sizeof(path), "/sys/block/%s/queue/iostats", devices[i]);
            rawrite("0", path);
        }
    }

    // 2. Entropy & Wakeup Thresholds (Facur, GHenna, Yanz)
    {
        const char *rand_base = "/proc/sys/kernel/random/";
        const char *thr_files_128[] = { "write_wakeup/threshold", "read_wakeup_threshold" };
        int thr_count_128 = sizeof(thr_files_128) / sizeof(thr_files_128[0]);
        
        rawrite("64", "/proc/sys/kernel/random/read_wakeup/threshold");
        raco_bulk(rand_base, thr_files_128, thr_count_128, "128", 0);
        rawrite("1024", "/proc/sys/kernel/random/write_wakeup_threshold");
    }



    // 6. RCU & safe module parameters
    {
        rawrite("1", "/sys/kernel/rcu_normal");
        rawrite("0", "/sys/kernel/rcu_expedited");

        // Schedtune (safe, no-op on non-EAS kernels)
        rawrite("0", "/dev/stune/top-app/schedtune.boost");
        rawrite("1", "/dev/stune/top-app/schedtune.prefer_idle");

        // Safe kernel params only
        rawrite("1", "/proc/sys/kernel/sched_energy_aware");
        rawrite("1", "/proc/sys/kernel/sched_child_runs_first");
        rawrite("0", "/proc/sys/kernel/sched_autogroup_enabled");

        // Safe module params
        rawrite("0", "/sys/module/mmc_core/parameters/use_spi_crc");
        rawrite("0", "/sys/module/cpufreq_bouncing/parameters/enable");

    }

    // 7. GHenna Disable Kernel Panic (Glob search-based)
    {
        const char *panic_proc_base = "/proc/sys/kernel/";
        const char *panic_proc_files[] = {
            "panic", "panic_on_oops", "panic_on_warn", "panic_on_rcu_stall"
        };

        int panic_proc_count = sizeof(panic_proc_files) / sizeof(panic_proc_files[0]);
        raco_bulk(panic_proc_base, panic_proc_files, panic_proc_count, "0", 0);

        const char *panic_mod_base = "/sys/module/kernel/parameters/";
        const char *panic_mod_files[] = {
            "panic", "panic_on_warn", "pause_on_oops"
        };
        int panic_mod_count = sizeof(panic_mod_files) / sizeof(panic_mod_files[0]);
        raco_bulk(panic_mod_base, panic_mod_files, panic_mod_count, "0", 0);

        rawrite("0", "/sys/module/kernel/panic_on_rcu_stall");

        glob_t gstruct;
        const char *panic_patterns[] = {
            "/proc/sys/kernel/*panic*",
            "/sys/module/*/parameters/*panic*",
            "/sys/module/*/parameters/*pause_on_oops*"
        };
        int pattern_count = sizeof(panic_patterns) / sizeof(panic_patterns[0]);
        for (int i = 0; i < pattern_count; i++) {
            if (glob(panic_patterns[i], 0, NULL, &gstruct) == 0) {
                for (size_t j = 0; j < gstruct.gl_pathc; j++) {
                    rawrite("0", gstruct.gl_pathv[j]);
                }
                globfree(&gstruct);
            }
        }
    }

    // 8. VM tuning
    {
        rawrite("0", "/proc/sys/vm/extra_free_kbytes");
        rawrite("0", "/proc/sys/vm/oom_kill_allocating_task");
        rawrite("0", "/proc/sys/debug/exception-trace");

    }

    // 9. GHenna GPU Debug disablement & HWUI tweaks & LMK & Vsync
    {
        const char *gpu_files_0[] = {
            "/sys/kernel/debug/dri/0/debug/enable",
            "/sys/kernel/debug/gpu/enable",
            "/sys/kernel/debug/gpumemdebug"
        };
        int gpu_count_0 = sizeof(gpu_files_0) / sizeof(gpu_files_0[0]);
        raco_bulk("", gpu_files_0, gpu_count_0, "0", 0);

        const char *gpu_files_1[] = {
            "/sys/module/spurious/parameters/noirqdebug",
            "/sys/kernel/debug/hwcomposer/disable_debug"
        };
        int gpu_count_1 = sizeof(gpu_files_1) / sizeof(gpu_files_1[0]);
        raco_bulk("", gpu_files_1, gpu_count_1, "1", 0);


    }

    // 10. GED Tweaks
    {
        const char *ged_base = "/sys/module/ged/parameters";
        const char *ged_files[] = {
            "gx_boost_on", "gx_game_mode", "ged_smart_boost", "enable_gpu_boost",
            "ged_boost_enable", "gx_frc_mode", "cpu_boost_policy", "boost_extra"
        };
        int ged_count = sizeof(ged_files) / sizeof(ged_files[0]);
        raco_bulk(ged_base, ged_files, ged_count, "0", 1);
    }
}

// Disable kernel panic FIRST before any other sysfs operations
static void disable_kernel_panic_early() {
    const char *panic_proc_base = "/proc/sys/kernel/";
    const char *panic_proc_files[] = {
        "panic", "panic_on_oops", "panic_on_warn", "panic_on_rcu_stall"
    };
    int panic_proc_count = sizeof(panic_proc_files) / sizeof(panic_proc_files[0]);
    raco_bulk(panic_proc_base, panic_proc_files, panic_proc_count, "0", 0);

    const char *panic_mod_base = "/sys/module/kernel/parameters/";
    const char *panic_mod_files[] = {
        "panic", "panic_on_warn", "pause_on_oops"
    };
    int panic_mod_count = sizeof(panic_mod_files) / sizeof(panic_mod_files[0]);
    raco_bulk(panic_mod_base, panic_mod_files, panic_mod_count, "0", 0);

    rawrite("0", "/sys/module/kernel/panic_on_rcu_stall");
}

// Main execution routine
int main(int argc, char *argv[]) {

    // CRITICAL: Disable kernel panic before anything else
    // Prevents sysfs write oops from triggering a reboot
    disable_kernel_panic_early();

    // Parse Service Configuration
    parse_service_config();

    // CPU Governor to performance (if INCLUDE_SANDEV=1)
    if (inc_sandev == 1) {
        change_cpu_gov("performance");
    }

    // Mali Scheduler Tweaks
    apply_mali_tweaks();


    // Kobo Fast Charge
    if (inc_kobo == 1) {
        kobo_fast_charge();
    }

    // Zetamin Optimization
    if (inc_zeta == 1) {
        zetamin_optimize();
    }

    // Apply System Optimizations (Consolidated Facur, GHenna, Yanz)
    apply_system_optimizations();

    // Sandevistan Durational CPU governor lock & background restore fork
    if (inc_sandev == 1) {
        pid_t pid = fork();
        if (pid == 0) {
            // Child process runs in background
            sleep(sandev_dur);

            change_cpu_gov(config.default_gov);
            exit(0);
        }
    }

    return 0;
}
