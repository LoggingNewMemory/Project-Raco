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

// ==========================================
// ANYA MELFISSA (DISABLE THERMAL)
// ==========================================

void kill_thermal_services() {
    // 1. Universal dynamic kill 
    // Scans all processes for the word "thermal" (case-insensitive).
    // Safely excludes our own binary (anya_thermal) and the grep command itself.
    FILE *fp_ps = popen("ps -A | grep -i thermal | grep -v anya_thermal | grep -v grep | awk '{print $2}'", "r");
    if (fp_ps) {
        char pid[32];
        while (fgets(pid, sizeof(pid), fp_ps)) {
            pid[strcspn(pid, "\n")] = 0;
            if (strlen(pid) > 0) {
                char cmd[64];
                snprintf(cmd, sizeof(cmd), "kill -9 %s 2>/dev/null", pid);
                system(cmd);
            }
        }
        pclose(fp_ps);
    }
    
    // 2. Stop init.svc thermal processes
    FILE *fp = popen("getprop", "r");
    if (fp) {
        char line[256];
        while(fgets(line, sizeof(line), fp)) {
            if(strstr(line, "init.svc") && strstr(line, "thermal") && !strstr(line, "hal")) {
                char prop[128];
                if (sscanf(line, "[%127[^]]]", prop) == 1) {
                    char svc[128];
                    if (sscanf(prop, "init.svc.%127s", svc) == 1) {
                        char cmd[512];
                        snprintf(cmd, sizeof(cmd), "stop \"%s\"; setprop ctl.stop \"%s\"", svc, svc);
                        system(cmd);
                    }
                }
            }
        }
        pclose(fp);
    }
}

void disable_fs_protections() {
    system("mount -o bind /dev/null /vendor/bin/thermald 2>/dev/null");
    unlink("/data/vendor/thermal/config");
    
    glob_t globbuf;
    if (glob("/data/vendor/thermal/*.dump", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) unlink(globbuf.gl_pathv[i]);
        globfree(&globbuf);
    }
}

void disable_cpu_limits() {
    glob_t globbuf;
    if (glob("/sys/devices/system/cpu/cpu*/core_ctl/enable", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) tweak("0", globbuf.gl_pathv[i]); 
        globfree(&globbuf);
    }

    // Safely uses Linux 'find' to avoid C-recursive symlink infinite loop (Segfault)
    FILE *fp = popen("find /sys/ -type f -name enabled 2>/dev/null | grep 'msm_thermal'", "r");
    if (fp) {
        char path[512];
        while (fgets(path, sizeof(path), fp)) {
            path[strcspn(path, "\n")] = 0;
            if (strlen(path) > 0) {
                kakangku("N", path);
                kakangku("0", path);
            }
        }
        pclose(fp);
    }

    kakangku("1", "/proc/ppm/enabled");
    const char *ppm_policies[] = {"2 0", "3 0", "4 0", "6 0", "7 0"};
    for (int i = 0; i < 5; i++) kakangku(ppm_policies[i], "/proc/ppm/policy_status");

    kakangku("0", "/proc/sys/kernel/sched_boost");
    kakangku("0", "/proc/sys/kernel/panic");
    kakangku("0", "/proc/sys/kernel/panic_on_oops");
    
    kakangku("N", "/sys/module/workqueue/parameters/power_efficient");
    kakangku("N", "/sys/module/workqueue/parameters/disable_numa");
    kakangku("0", "/sys/kernel/fpsgo/fbt/thrm_enable");
    kakangku("0", "/sys/kernel/eara_thermal/enable");
}

void disable_gpu_limits() {
    if (access("/sys/class/kgsl/kgsl-3d0", F_OK) == 0) {
        kakangku("0", "/sys/class/kgsl/kgsl-3d0/throttling");
        kakangku("0", "/sys/class/kgsl/kgsl-3d0/max_gpuclk");
        kakangku("1", "/sys/class/kgsl/kgsl-3d0/force_clk_on");
        kakangku("0", "/sys/class/kgsl/kgsl-3d0/thermal_pwrlevel");
    }
    
    if (access("/proc/gpufreq", F_OK) == 0) {
        kakangku("0", "/proc/gpufreq/gpufreq_power_limited");
        kakangku("1", "/proc/gpufreq/gpufreq_limited_thermal_ignore");
    }
}

void spoof_running_status() {
    FILE *fp = popen("getprop", "r");
    if (fp) {
        char line[256];
        while (fgets(line, sizeof(line), fp)) {
            if (strstr(line, "thermal") && !strstr(line, "hal")) {
                char prop[128];
                if (sscanf(line, "[%127[^]]]", prop) == 1) {
                    char cmd[512];
                    if (strncmp(prop, "sys.", 4) == 0 || strstr(prop, "thermal_config")) {
                        snprintf(cmd, sizeof(cmd), "resetprop -n \"%s\" \"0\"", prop);
                        system(cmd);
                    } else {
                        snprintf(cmd, sizeof(cmd), "resetprop -n \"%s\" \"running\"", prop);
                        system(cmd);
                    }
                }
            }
        }
        pclose(fp);
    }
    
    system("if resetprop debug.thermal.throttle.support | grep -q 'yes'; then resetprop -n -v debug.thermal.throttle.support no; fi");
}

void disable_thermal() {
    printf("[*] Initializing AnyaMelfissa (Disabling Thermal)...\n");
    kill_thermal_services();
    system("cmd thermalservice override-status 0 2>/dev/null");

    disable_fs_protections();
    disable_cpu_limits();
    disable_gpu_limits();
    spoof_running_status();
    
    printf("[+] Thermal successfully disabled.\n");
}

// ==========================================
// ANYA KAWAII (RESTORE THERMAL)
// ==========================================

void restore_filesystem() {
    system("umount /vendor/bin/thermald 2>/dev/null");
}

void restore_hardware() {
    glob_t globbuf;
    if (glob("/sys/devices/system/cpu/cpu*/core_ctl/enable", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) kakangku("1", globbuf.gl_pathv[i]);
        globfree(&globbuf);
    }

    FILE *fp = popen("find /sys/ -type f -name enabled 2>/dev/null | grep 'msm_thermal'", "r");
    if (fp) {
        char path[512];
        while (fgets(path, sizeof(path), fp)) {
            path[strcspn(path, "\n")] = 0;
            if (strlen(path) > 0) {
                kakangku("Y", path);
                kakangku("1", path);
            }
        }
        pclose(fp);
    }

    if (access("/sys/class/kgsl/kgsl-3d0", F_OK) == 0) {
        kakangku("1", "/sys/class/kgsl/kgsl-3d0/throttling");
        kakangku("1", "/sys/class/kgsl/kgsl-3d0/thermal_pwrlevel");
    }
}

void restore_thermal() {
    printf("[*] Initializing AnyaKawaii (Restoring Thermal)...\n");
    restore_filesystem();
    restore_hardware();

    system("cmd thermalservice override-status 1 2>/dev/null");
    system("cmd thermalservice reset 2>/dev/null");

    FILE *fp = popen("getprop", "r");
    if (fp) {
        char line[256];
        while(fgets(line, sizeof(line), fp)) {
            if(strstr(line, "init.svc") && strstr(line, "thermal") && !strstr(line, "hal")) {
                char prop[128];
                if (sscanf(line, "[%127[^]]]", prop) == 1) {
                    char svc[128];
                    if (sscanf(prop, "init.svc.%127s", svc) == 1) {
                        char cmd[512];
                        snprintf(cmd, sizeof(cmd), "resetprop -n \"%s\" \"stopped\"; start \"%s\"; setprop ctl.start \"%s\"", prop, svc, svc);
                        system(cmd);
                    }
                }
            } else if (strstr(line, "thermal") && !strstr(line, "hal") && !strstr(line, "init.svc")) {
                char prop[128];
                if (sscanf(line, "[%127[^]]]", prop) == 1) {
                    char cmd[512];
                    snprintf(cmd, sizeof(cmd), "resetprop -n \"%s\" \"running\"", prop);
                    system(cmd);
                }
            }
        }
        pclose(fp);
    }
    printf("[+] Thermal successfully restored.\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("AnyaThermal - Unified Thermal Control\n");
        printf("Usage: %s {disable|restore}\n", argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "disable") == 0) disable_thermal();
    else if (strcmp(argv[1], "restore") == 0 || strcmp(argv[1], "enable") == 0) restore_thermal();
    else {
        printf("Error: Invalid argument '%s'\n", argv[1]);
        return 1;
    }
    return 0;
}