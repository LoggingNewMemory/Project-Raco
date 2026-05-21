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
int sandev_dur = 300;
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

// Custom Process Tasks nice and affinity management
void optimize_memory_tasks(void) {
    DIR *proc_dir = opendir("/proc");
    if (proc_dir == NULL) return;

    struct dirent *proc_ent;
    while ((proc_ent = readdir(proc_dir)) != NULL) {
        if (proc_ent->d_name[0] >= '0' && proc_ent->d_name[0] <= '9') {
            char comm_path[512];
            snprintf(comm_path, sizeof(comm_path), "/proc/%s/comm", proc_ent->d_name);
            char comm_name[256] = {0};
            if (raread(comm_path, comm_name, sizeof(comm_name) - 1) > 0) {
                comm_name[strcspn(comm_name, "\n")] = 0;
                
                int is_kswapd = (my_strcasestr(comm_name, "kswapd") != NULL);
                int is_oom = (my_strcasestr(comm_name, "oom_reaper") != NULL);
                int is_kcompactd = (my_strcasestr(comm_name, "kcompactd") != NULL);
                int is_kthreadd = (my_strcasestr(comm_name, "kthreadd") != NULL);
                int is_writeback = (my_strcasestr(comm_name, "writeback") != NULL);
                
                if (is_kswapd || is_oom || is_kcompactd || is_kthreadd || is_writeback) {
                    char task_dir_path[512];
                    snprintf(task_dir_path, sizeof(task_dir_path), "/proc/%s/task", proc_ent->d_name);
                    DIR *task_dir = opendir(task_dir_path);
                    if (task_dir != NULL) {
                        struct dirent *task_ent;
                        while ((task_ent = readdir(task_dir)) != NULL) {
                            if (task_ent->d_name[0] >= '0' && task_ent->d_name[0] <= '9') {
                                int tid = atoi(task_ent->d_name);
                                
                                // Set Nice Value
                                int nice_val = 0;
                                if (is_kswapd || is_oom) nice_val = -2;
                                else if (is_kcompactd || is_kthreadd || is_writeback) nice_val = -5;
                                
                                setpriority(PRIO_PROCESS, tid, nice_val);
                                
                                // Set Affinity if kswapd or oom
                                if (is_kswapd || is_oom) {
                                    cpu_set_t cpuset;
                                    CPU_ZERO(&cpuset);
                                    unsigned long mask_val = 0x7f; // "7f" in hex
                                    for (size_t i = 0; i < 8 * sizeof(unsigned long); i++) {
                                        if ((mask_val >> i) & 1) {
                                            CPU_SET(i, &cpuset);
                                        }
                                    }
                                    if (sched_setaffinity(tid, sizeof(cpu_set_t), &cpuset) != 0) {
                                        // Fallback: write to /dev/cpuset/top-app/tasks
                                        char tid_str[32];
                                        snprintf(tid_str, sizeof(tid_str), "%d", tid);
                                        rawrite(tid_str, "/dev/cpuset/top-app/tasks");
                                    }
                                }
                            }
                        }
                        closedir(task_dir);
                    }
                }
            }
        }
    }
    closedir(proc_dir);
}

// Notification Helper
void send_notif(const char *title, const char *message, const char *tag, const char *icon_path) {
    char cmd[1024];
    if (config.legacy_notif == 1) {
        snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t '%s' '%s' '%s'\" &", title, tag, message);
    } else {
        snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t '%s' -i file://%s -I file://%s '%s' '%s'\" &", title, icon_path, icon_path, tag, message);
    }
    system(cmd);
}

// Configuration parsing from /data/ProjectRaco/raco.txt
void parse_service_config() {
    load_config("/data/ProjectRaco/raco.txt");

    inc_kobo = 0;
    inc_zeta = 0;
    inc_sandev = 0;
    sandev_dur = 300;
    default_gov[0] = '\0';

    char file_content[4096];
    if (raread("/data/ProjectRaco/raco.txt", file_content, sizeof(file_content)) <= 0) {
        return;
    }

    char *saveptr_line;
    char *line = strtok_r(file_content, "\n", &saveptr_line);

    while (line != NULL) {
        char *equal_pos = strchr(line, '=');
        if (equal_pos) {
            *equal_pos = ' ';
        }

        char key[128] = {0};
        char value[128] = {0};
        int parsed = sscanf(line, "%127s %127s", key, value);

        if (parsed >= 1) {
            if (strcmp(key, "INCLUDE_KOBO") == 0 && parsed == 2) inc_kobo = atoi(value);
            else if (strcmp(key, "INCLUDE_ZETAMIN") == 0 && parsed == 2) inc_zeta = atoi(value);
            else if (strcmp(key, "INCLUDE_SANDEV") == 0 && parsed == 2) inc_sandev = atoi(value);
            else if (strcmp(key, "SANDEV_DUR") == 0 && parsed == 2) sandev_dur = atoi(value);
            else if (strcmp(key, "GOV") == 0 && parsed == 2) strcpy(default_gov, value);
        }
        line = strtok_r(NULL, "\n", &saveptr_line);
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

// KamiGO FPSGo Tweaks
void apply_kamigo_tweaks() {
    {
        const char *fbt_base = "/sys/kernel/fpsgo/fbt/";
        const char *fbt_files_0[] = { "enable_ceiling", "limit_cfreq", "limit_rfreq", "limit_uclamp" };
        int fbt_count_0 = sizeof(fbt_files_0) / sizeof(fbt_files_0[0]);
        raco_bulk(fbt_base, fbt_files_0, fbt_count_0, "0", 0);

        const char *fbt_files_1[] = { "rescue_enable", "ultra_rescue", "boost_VIP", "boost_ta" };
        int fbt_count_1 = sizeof(fbt_files_1) / sizeof(fbt_files_1[0]);
        raco_bulk(fbt_base, fbt_files_1, fbt_count_1, "1", 0);
    }
    
    {
        const char *fpsgo_base = "/sys/module/mtk_fpsgo/parameters/";
        const char *fpsgo_files_1[] = { "bhr", "qr_enable" };
        int fpsgo_count_1 = sizeof(fpsgo_files_1) / sizeof(fpsgo_files_1[0]);
        raco_bulk(fpsgo_base, fpsgo_files_1, fpsgo_count_1, "1", 0);
        
        rawrite("15", "/sys/module/mtk_fpsgo/parameters/bhr_opp");
        rawrite("95", "/sys/module/mtk_fpsgo/parameters/rescue_percent");
    }
    
    rawrite("0", "/sys/kernel/fpsgo/fstb/fstb_self_ctrl_fps_enable");
    rawrite("1", "/sys/kernel/fpsgo/fstb/margin_mode");
    rawrite("1", "/sys/pnpmgr/fpsgo_boost/boost_mode");
}

// Consolidated and Scoped System Optimizations (Facur, GHenna, Yanz Merged)
void apply_system_optimizations() {
    // 1. Filesystem & I/O queue scheduler (Facur, GHenna, Yanz block queues)
    {
        DIR *dir = opendir("/sys/block");
        if (dir != NULL) {
            struct dirent *ent;
            while ((ent = readdir(dir)) != NULL) {
                if (ent->d_name[0] != '.' && strcmp(ent->d_name, "..") != 0) {
                    char path[512];
                    snprintf(path, sizeof(path), "/sys/block/%s/queue/scheduler", ent->d_name);
                    rawrite("none", path);
                }
            }
            closedir(dir);
        }
        
        rawrite("1", "/sys/module/workqueue/parameters/power_efficient");

        // Specific block devices optimization
        const char *devices[] = {
            "sda", "loop0", "loop1", "loop2", "loop3", "loop4", "loop5",
            "loop6", "loop7", "dm-0", "mmcblk0", "mmcblk1", "mmcblk0rpmb"
        };
        int dev_count = sizeof(devices) / sizeof(devices[0]);
        for (int i = 0; i < dev_count; i++) {
            const char *base = "/sys/block/";
            char path[512];
            
            snprintf(path, sizeof(path), "%s%s/queue/iostats", base, devices[i]);
            rawrite("0", path);

            snprintf(path, sizeof(path), "%s%s/queue/scheduler", base, devices[i]);
            rawrite("none", path);
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

    // 3. GHenna Universal Deep Sleep & GMS Doze
    {
        system("rm -f /storage/emulated/0/*.log /data/log/*.log /cache/*.log 2>/dev/null");
        system("dumpsys deviceidle reset 2>/dev/null");
        system("dumpsys deviceidle enable light 2>/dev/null");
        system("dumpsys deviceidle enable deep 2>/dev/null");
        system("settings put global device_idle_constants light_after_inactive_to=15000,light_pre_idle_to=30000,light_idle_to=300000,light_max_idle_to=900000,inactive_to=1800000,idle_after_inactive_to=0,idle_pending_to=300000,max_idle_pending_to=600000,idle_to=3600000,max_idle_to=21600000 2>/dev/null");
        system("pm trim-caches 999999999 2>/dev/null");

        system("pm set-inactive com.google.android.gms true 2>/dev/null");
        system("dumpsys deviceidle whitelist -com.google.android.gms 2>/dev/null");
        system("dumpsys deviceidle tempwhitelist -c com.google.android.gms 2>/dev/null");
    }

    // 4. GHenna disable tracing & logcat optimizations
    {
        system("cmd accessibility stop-trace 2>/dev/null");
        system("cmd input_method tracing stop 2>/dev/null");
        system("cmd window tracing size 0 2>/dev/null");
        system("cmd window tracing stop 2>/dev/null");
        system("cmd statusbar tracing stop 2>/dev/null");
        system("cmd memory_trace disable 2>/dev/null");
        system("cmd animation tracing stop 2>/dev/null");
        system("cmd package tracing stop 2>/dev/null");
        system("cmd wm tracing stop 2>/dev/null");
        system("cmd activity tracing stop 2>/dev/null");
        system("cmd broadcast tracing disable 2>/dev/null");
        system("atrace --async_stop >/dev/null 2>&1");
        
        const char *trace_on_files[] = { "/sys/kernel/tracing/tracing_on", "/sys/kernel/debug/tracing/tracing_on" };
        int trace_on_count = sizeof(trace_on_files) / sizeof(trace_on_files[0]);
        raco_bulk("", trace_on_files, trace_on_count, "0", 0);

        system("logcat -c 2>/dev/null");
        system("logcat -G 16K 2>/dev/null");
        system("setprop persist.sys.usb.config adb 2>/dev/null");
        system("setprop ro.logd.size.stats 0 2>/dev/null");
        system("setprop ro.logdumpd.enabled false 2>/dev/null");

        rawrite("0 0 0 0", "/proc/sys/kernel/printk");

        const char *kernel_base = "/proc/sys/kernel/";
        const char *k_printk_files[] = { "printk_ratelimit", "sysctl_writes_strict" };
        int k_printk_count = sizeof(k_printk_files) / sizeof(k_printk_files[0]);
        raco_bulk(kernel_base, k_printk_files, k_printk_count, "0", 0);

        const char *debug_trace_base = "/sys/kernel/debug/tracing/";
        const char *debug_trace_0[] = { "tracing_on", "events/enable" };
        int debug_trace_count = sizeof(debug_trace_0) / sizeof(debug_trace_0[0]);
        raco_bulk(debug_trace_base, debug_trace_0, debug_trace_count, "0", 0);
        rawrite("nop", "/sys/kernel/debug/tracing/current_tracer");

        system("setprop debug.atrace.tags.enableflags 0 2>/dev/null");
        system("setprop debug.force_rtl false 2>/dev/null");

        rawrite("0", "/proc/sys/kernel/printk_devkmsg");
        rawrite("0", "/sys/module/binder/parameters/debug_mask");

        const char *printk_base = "/sys/module/printk/parameters/";
        const char *printk_files_0[] = { "cpu", "pid", "time", "printk_ratelimit" };
        int printk_count_0 = sizeof(printk_files_0) / sizeof(printk_files_0[0]);
        raco_bulk(printk_base, printk_files_0, printk_count_0, "0", 0);

        const char *printk_files_1[] = { "console_suspend", "ignore_loglevel" };
        int printk_count_1 = sizeof(printk_files_1) / sizeof(printk_files_1[0]);
        raco_bulk(printk_base, printk_files_1, printk_count_1, "1", 0);

        rawrite("N", "/sys/module/sync/parameters/fsync_enabled");
    }

    // 5. GHenna Memory management task affinity & nice values (kswapd, oom_reaper, etc.)
    {
        optimize_memory_tasks();
    }

    // 6. RCU, Scheduler & Module parameters (GHenna & Yanz)
    {
        rawrite("1", "/sys/kernel/rcu_normal");
        
        const char *rcu_isolated[] = { "/sys/kernel/rcu_expedited", "/sys/devices/system/cpu/isolated" };
        int rcu_isolated_count = sizeof(rcu_isolated) / sizeof(rcu_isolated[0]);
        raco_bulk("", rcu_isolated, rcu_isolated_count, "0", 0);

        rawrite("0", "/dev/stune/top-app/schedtune.boost");
        rawrite("1", "/dev/stune/top-app/schedtune.prefer_idle");

        const char *features[] = { "NEXT_BUDDY", "TTWU_QUEUE", "ENERGY_AWARE" };
        int feat_count = sizeof(features) / sizeof(features[0]);
        for (int i = 0; i < feat_count; i++) {
            rawrite(features[i], "/sys/kernel/debug/sched_features");
        }

        const char *kernel_base = "/proc/sys/kernel/";
        const char *k_files_1[] = { "timer_migration", "sched_energy_aware", "sched_child_runs_first" };
        int k_count_1 = sizeof(k_files_1) / sizeof(k_files_1[0]);
        raco_bulk(kernel_base, k_files_1, k_count_1, "1", 0);
        
        rawrite("0", "/proc/sys/kernel/sched_autogroup_enabled");
        rawrite("120", "/proc/sys/kernel/hung_task_timeout_secs");
        rawrite("32", "/proc/sys/kernel/sched_nr_migrate");
        rawrite("4000000", "/proc/sys/kernel/sched_latency_ns");
        rawrite("50000", "/proc/sys/kernel/sched_migration_cost_ns");
        rawrite("1000000", "/proc/sys/kernel/sched_min_granularity_ns");
        rawrite("1500000", "/proc/sys/kernel/sched_wakeup_granularity_ns");

        // Module params
        const char *mod_files_0[] = {
            "/sys/module/mmc_core/parameters/use_spi_crc",
            "/sys/module/cpufreq_bouncing/parameters/enable"
        };
        int mod_count_0 = sizeof(mod_files_0) / sizeof(mod_files_0[0]);
        raco_bulk("", mod_files_0, mod_count_0, "0", 0);
        rawrite("1000000", "/sys/module/timer/parameters/sample_period");

        rawrite("819", "/sys/module/tcp_cubic/parameters/beta");
        rawrite("1", "/sys/module/tcp_cubic/parameters/fast_convergence");
    }

    // 7. GHenna Disable Kernel Panic (Glob search-based)
    {
        const char *panic_paths[] = {
            "/proc/sys/kernel/panic",
            "/proc/sys/kernel/panic_on_oops",
            "/proc/sys/kernel/panic_on_warn",
            "/proc/sys/kernel/panic_on_rcu_stall",
            "/sys/module/kernel/parameters/panic",
            "/sys/module/kernel/parameters/panic_on_warn",
            "/sys/module/kernel/parameters/pause_on_oops",
            "/sys/module/kernel/panic_on_rcu_stall"
        };
        int panic_count = sizeof(panic_paths) / sizeof(panic_paths[0]);
        for (int i = 0; i < panic_count; i++) {
            rawrite("0", panic_paths[i]);
        }

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

    // 8. GHenna & Yanz VM memory cache & Zram tuning
    {
        rawrite("3", "/proc/sys/vm/drop_caches");
        rawrite("1", "/proc/sys/vm/compact_memory");
        
        const char *vm_base = "/proc/sys/vm/";
        const char *vm_files_0[] = { "extra_free_kbytes", "oom_kill_allocating_task" };
        int vm_count_0 = sizeof(vm_files_0) / sizeof(vm_files_0[0]);
        raco_bulk(vm_base, vm_files_0, vm_count_0, "0", 0);
        rawrite("0", "/proc/sys/debug/exception-trace");
        
        rawrite("80", "/proc/sys/vm/vfs_cache_pressure");
        rawrite("60", "/proc/sys/vm/swappiness");
        rawrite("90", "/proc/sys/vm/overcommit_ratio");
        rawrite("3072", "/proc/sys/vm/min_free_kbytes");

        rawrite("1024,2048,4096,8192,12288,16384", "/sys/module/lowmemorykiller/parameters/minfree");
        rawrite("32", "/sys/module/lowmemorykiller/parameters/cost");
        rawrite("0", "/sys/module/lowmemorykiller/parameters/enable_adaptive_lmk");
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

        system("setprop debug.sf.hw 1");
        system("setprop debug.sf.latch_unsignaled 1");
        system("setprop debug.hwui.drop_shadow_cache_size 6");
        system("setprop debug.hwui.texture_cache_flushrate 0.4");
        system("setprop ro.hwui.render_ahead_lines 2");
        system("setprop ro.hwui.texture_cache_size 72");

        const char *mipi_base = "/sys/kernel/debug/mdss_panel_fb0/intf0/mipi/";
        const char *mipi_files[] = { "hw_vsync_mode", "vsync_enable" };
        int mipi_count = sizeof(mipi_files) / sizeof(mipi_files[0]);
        raco_bulk(mipi_base, mipi_files, mipi_count, "0", 0);
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

// Main execution routine
int main(int argc, char *argv[]) {
    // Safety check boot completed in case it runs super early
    while (1) {
        char boot_prop[92] = {0};
        FILE *fp = popen("getprop sys.boot_completed", "r");
        if (fp) {
            if (fgets(boot_prop, sizeof(boot_prop), fp)) {
                if (strstr(boot_prop, "1") != NULL) {
                    pclose(fp);
                    break;
                }
            }
            pclose(fp);
        }
        sleep(5);
    }

    // Reset STATE to empty
    system("sed -i 's/^STATE.*/STATE /' /data/ProjectRaco/raco.txt");

    // Parse Service Configuration
    parse_service_config();

    // CPU Governor to performance (if INCLUDE_SANDEV=1)
    if (inc_sandev == 1) {
        change_cpu_gov("performance");
    }

    // Mali Scheduler Tweaks
    apply_mali_tweaks();

    // KamiGO Tweaks
    if (config.soc == 1) {
        apply_kamigo_tweaks();
    }

    // Anya Melfissa
    if (config.include_anya == 1 && config.anya == 1) {
        anyamelfissa(); // executes thermal block via anya binary
        send_notif("Anya Melfissa", "Good Day! Thermal Is Dead BTW", "TagAnya", "/data/local/tmp/Anya.png");
    }

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

    // Final Startup Notification
    send_notif("Project Raco", "Project Raco - オンライン", "TagRaco", "/data/local/tmp/logo.png");

    // Sandevistan Durational CPU governor lock & background restore fork
    if (inc_sandev == 1) {
        pid_t pid = fork();
        if (pid == 0) {
            // Child process runs in background
            sleep(sandev_dur);

            char revert_gov[64] = {0};
            if (default_gov[0] != '\0') {
                strncpy(revert_gov, default_gov, sizeof(revert_gov) - 1);
            } else {
                char av_govs[1024] = {0};
                if (raread("/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_governors", av_govs, sizeof(av_govs) - 1) > 0) {
                    if (strstr(av_govs, "schedhorizon") != NULL) {
                        strcpy(revert_gov, "schedhorizon");
                    } else {
                        strcpy(revert_gov, "schedutil");
                    }
                } else {
                    strcpy(revert_gov, "schedutil");
                }
            }
            change_cpu_gov(revert_gov);
            exit(0);
        }
    }

    return 0;
}
