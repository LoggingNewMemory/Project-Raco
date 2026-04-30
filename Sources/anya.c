#include "raco.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
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

// Anya Kawaii
void restore_fs() {
    system("umount /vendor/bin/thermald 2>/dev/null");
}

void restore_hardware() {
    DIR *dir;
    struct dirent *ent;

    if ((dir = opendir("/sys/devices/system/cpu")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "cpu", 3) == 0) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/%s/core_ctl/enable", ent->d_name);
                raco_val(path, "1", 0);
            }
        } 
        closedir(dir);
    }
    system("find /sys/ -name enabled | grep 'msm_thermal' | while read -r msm; do echo 'Y' > \"$msm\" 2>/dev/null; echo '1' > \"$msm\" 2>/dev/null; done");

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

    system("cmd thermalservice override-status 1 2>/dev/null");
    system("cmd thermalservice reset 2>/dev/null");

    system("getprop | grep -E 'init.svc(\\.vendor)?\\.thermal' | grep -v \"hal\" | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]' | while read -r svc; do resetprop -n \"init.svc.$svc\" \"stopped\"; start \"$svc\"; setprop ctl.start \"$svc\"; done");
    system("getprop | grep 'thermal' | grep -v \"hal\" | cut -d '[' -f2 | cut -d ']' -f1 | while read -r prop; do if [ -n \"$prop\" ]; then resetprop -n \"$prop\" \"running\"; fi; done");
}

// Anya Melfissa

void disable_fs_protections() {
    system("mount -o bind /dev/null /vendor/bin/thermald 2>/dev/null");
    system("rm -f /data/vendor/thermal/config /data/vendor/thermal/*.dump 2>/dev/null");
}

void disable_cpu_limits() {
    DIR *dir;
    struct dirent *ent;

    if ((dir = opendir("/sys/devices/system/cpu")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "cpu", 3) == 0) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/%s/core_ctl/enable", ent->d_name);
                raco_val(path, "0", 1);
            }
        } 
        closedir(dir);
    }

    // MSM Thermal
    system("find /sys/ -name enabled | grep 'msm_thermal' | while read -r msm; do echo 'N' > \"$msm\" 2>/dev/null; echo '0' > \"$msm\" 2>/dev/null; done");

    // PPM Policy
    raco_val("/proc/ppm/enabled", "1", 0);

    const char *ppm_policies[] = {"2 0", "3 0", "4 0", "6 0", "7 0"};
    int ppm_count = sizeof(ppm_policies) / sizeof(ppm_policies[0]);

    for (int i = 0; i < ppm_count; i++) {
        raco_val("/proc/ppm/policy_status", ppm_policies[i], 0);
    }

    // Disable Kernel Panic
    const char *kernel_base = "/proc/sys/kernel";
    const char *kernel_files[] = {"sched_boost", "panic", "panic_on_oops"};
    int kernel_count = sizeof(kernel_files) / sizeof(kernel_files[0]);

    for (int i = 0; i < kernel_count; i++) {
        char full_path[256];
        snprintf(full_path, sizeof(full_path), "%s/%s", kernel_base, kernel_files[i]);
        raco_val(full_path, "0", 0);
    }
    // Workqueue Modules
    const char *wq_base = "/sys/module/workqueue/parameters";
    const char *wq_files[] = {"power_efficient", "disable_numa"};
    int wq_count = sizeof(wq_files) / sizeof(wq_files[0]);

    for (int i = 0; i < wq_count; i++) {
        char full_path[256];
        snprintf(full_path, sizeof(full_path), "%s/%s", wq_base, wq_files[i]);
        raco_val(full_path, "N", 0);
    }

    // Some Tweaks
    raco_val("/sys/kernel/fpsgo/fbt/thrm_enable", "0", 0);
    raco_val("/sys/kernel/eara_thermal/enable", "0", 0);
}

void disable_gpu_limits() {
    const char *gpu_base = "/sys/class/kgsl/kgsl-3d0";
    const char *gpu_files[] = {"throttling", "max_gpuclk", "thermal_pwrlevel"};
    int gpu_count = sizeof(gpu_files) / sizeof(gpu_files[0]);

    for (int i = 0; i < gpu_count; i++) {
        char full_path[256];
        snprintf(full_path, sizeof(full_path), "%s/%s", gpu_base, gpu_files[i]);
        raco_val(full_path, "0", 0);
    }
    raco_val("/sys/class/kgsl/kgsl-3d0/force_clk_on", "1", 0);

    raco_val("/proc/gpufreq/gpufreq_power_limited", "0", 0);
    raco_val("/proc/gpufreq/gpufreq_limited_thermal_ignore", "1", 0);
}

void spoof_run() {
    system("for prop in $(getprop | grep -E 'sys\\..*thermal|thermal_config' | grep -v \"hal\" | cut -d: -f1 | tr -d '[]'); do resetprop -n \"$prop\" \"0\"; done");
    
    // Transsion/Infinix check
    system("if resetprop debug.thermal.throttle.support | grep -q 'yes'; then resetprop -n -v debug.thermal.throttle.support no; fi");

    // The Running Spoof
    system("getprop | grep 'thermal' | grep -v \"hal\" | cut -d '[' -f2 | cut -d ']' -f1 | while read -r prop; do if [ -n \"$prop\" ]; then resetprop -n \"$prop\" \"running\"; fi; done");
}

void exec_anya_melfissa() {
    printf("Anya Melfissa Start...\n");

    system("killall -9 thermald android.hardware.thermal@2.0-service 2>/dev/null");
    system("pgrep -f \"thermal\" | grep -v \"hal\" | xargs -r kill -9 2>/dev/null");
    system("getprop | grep -E 'init.svc.*thermal' | grep -v \"hal\" | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]' | while read -r svc; do stop \"$svc\"; setprop ctl.stop \"$svc\"; done");
    system("cmd thermalservice override-status 0 2>/dev/null");

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

int main(int argc, char *argv[]) {
    // Check argument
    if (argc != 2) {
        printf("1 = Off Thermal, 0 = On Thermal\n");
        return 1;
    }

    int mode = atoi(argv[1]);

    if (mode == 1) {
    exec_anya_melfissa();
    } else if (mode == 0) {
    exec_anya_kawaii();
    } else {
        printf("INVALID! 1 = Off Thermal, 0 = On Thermal\n");
        return 1;
    }
    return 0;
}