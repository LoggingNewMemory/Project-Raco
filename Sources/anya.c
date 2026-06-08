/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
 */

#include "raco.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/wait.h>

// Helper function

void raco_val(const char *path, const char *val, int lock) {
    if (access(path, F_OK) == 0) {
        if (lock == 1) {
            rawrite(val, path);
        } else {
            rakakikomi(val, path);
        }
    }
}

// Shared helper: iterate /sys/devices/system/cpu/cpu*/core_ctl/enable
static void set_core_ctl(const char *val, int lock) {
    DIR *dir;
    struct dirent *ent;

    if ((dir = opendir("/sys/devices/system/cpu")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "cpu", 3) == 0 && isdigit(ent->d_name[3])) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/%s/core_ctl/enable", ent->d_name);
                raco_val(path, val, lock);
            }
        }
        closedir(dir);
    }
}

// Shared helper: MSM Thermal toggle
static void set_msm_thermal(const char *val) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd),
        "find /sys/ -name enabled 2>/dev/null | grep 'msm_thermal' | while read -r msm; do "
        "echo '%s' > \"$msm\" 2>/dev/null; done", val);
    system(cmd);
}

// Shared helper: Spoof thermal props to a target state
static void spoof_thermal_state(const char *state) {
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
        "getprop | grep 'thermal' | grep -v \"hal\" | cut -d '[' -f2 | cut -d ']' -f1 | "
        "while read -r prop; do [ -n \"$prop\" ] && resetprop -n \"$prop\" \"%s\"; done", state);
    system(cmd);
}

// Anya Kawaii
void restore_fs() {
    system("umount /vendor/bin/thermald 2>/dev/null");
}

void restore_hardware() {
    set_core_ctl("1", 0);
    set_msm_thermal("Y");

    raco_val("/sys/class/kgsl/kgsl-3d0/throttling", "1", 0);
    raco_val("/sys/class/kgsl/kgsl-3d0/thermal_pwrlevel", "1", 0);
}

void exec_anya_kawaii() {
    printf ("Anya Kawaii Start\n");

    pid_t pid1 = fork();
    if (pid1 == 0) { restore_fs(); exit(0); }

    pid_t pid2 = fork();
    if (pid2 == 0) { restore_hardware(); exit(0); }

    // Wait for finish
    waitpid(pid1, NULL, 0);
    waitpid(pid2, NULL, 0);

    system("getprop | grep -E 'init.svc(\\.vendor)?\\.thermal' | grep -v \"hal\" | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]' | while read -r svc; do resetprop -n \"init.svc.$svc\" \"stopped\"; start \"$svc\"; done");
    spoof_thermal_state("running");
}

// Anya Melfissa

void disable_fs_protections() {
    system("mount -o bind /dev/null /vendor/bin/thermald 2>/dev/null");
    system("rm -f /data/vendor/thermal/config /data/vendor/thermal/*.dump 2>/dev/null");
}

void disable_cpu_limits() {
    set_core_ctl("0", 1);
    set_msm_thermal("N");

    // PPM Policy
    raco_val("/proc/ppm/enabled", "1", 0);

    const char *ppm_policies[] = {"2 0", "3 0", "4 0", "6 0", "7 0"};
    int ppm_count = sizeof(ppm_policies) / sizeof(ppm_policies[0]);

    for (int i = 0; i < ppm_count; i++) {
        raco_val("/proc/ppm/policy_status", ppm_policies[i], 0);
    }

    // Disable Kernel Panic
    const char *kernel_files[] = {"sched_boost", "panic", "panic_on_oops"};
    raco_bulk("/proc/sys/kernel", kernel_files, 3, "0", 0);

    // Workqueue Modules
    const char *wq_files[] = {"power_efficient", "disable_numa"};
    raco_bulk("/sys/module/workqueue/parameters", wq_files, 2, "N", 0);

    // Some Tweaks
    raco_val("/sys/kernel/fpsgo/fbt/thrm_enable", "0", 0);
    raco_val("/sys/kernel/eara_thermal/enable", "0", 0);
}

void disable_gpu_limits() {
    const char *gpu_files[] = {"throttling", "max_gpuclk", "thermal_pwrlevel"};
    raco_bulk("/sys/class/kgsl/kgsl-3d0", gpu_files, 3, "0", 0);
    raco_val("/sys/class/kgsl/kgsl-3d0/force_clk_on", "1", 0);

    raco_val("/proc/gpufreq/gpufreq_power_limited", "0", 0);
    raco_val("/proc/gpufreq/gpufreq_limited_thermal_ignore", "1", 0);
}

void spoof_run() {
    system("for prop in $(getprop | grep -E 'sys\\..*thermal|thermal_config' | grep -v \"hal\" | cut -d: -f1 | tr -d '[]'); do resetprop -n \"$prop\" \"0\"; done");

    // Transsion/Infinix check
    system("if resetprop debug.thermal.throttle.support | grep -q 'yes'; then resetprop -n -v debug.thermal.throttle.support no; fi");

    // The Running Spoof
    spoof_thermal_state("running");
}

void exec_anya_melfissa() {
    printf("Anya Melfissa Start...\n");

    system("killall -9 thermald android.hardware.thermal@2.0-service 2>/dev/null");
    system("pgrep -f \"thermal\" | grep -v \"hal\" | xargs -r kill -9 2>/dev/null");
    system("getprop | grep -E 'init.svc.*thermal' | grep -v \"hal\" | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]' | while read -r svc; do stop \"$svc\"; done");

    // Exec Parallel
    pid_t pid1 = fork();
    if (pid1 == 0) { disable_fs_protections(); exit(0); }

    pid_t pid2 = fork();
    if (pid2 == 0) { disable_cpu_limits(); exit(0); }

    pid_t pid3 = fork();
    if (pid3 == 0) { disable_gpu_limits(); exit(0); }

    // Wait finish
    waitpid(pid1, NULL, 0);
    waitpid(pid2, NULL, 0);
    waitpid(pid3, NULL, 0);

    // Apply Spoof when done
    spoof_run();
}

#ifdef STANDALONE
int main(int argc, char *argv[]) {
    if (argc > 1) {
        if (strcmp(argv[1], "kawaii") == 0) {
            exec_anya_kawaii();
        } else if (strcmp(argv[1], "melfissa") == 0) {
            exec_anya_melfissa();
        } else {
            printf("Usage: anya [kawaii|melfissa]\n");
        }
    } else {
        printf("Usage: anya [kawaii|melfissa]\n");
    }
    return 0;
}
#endif