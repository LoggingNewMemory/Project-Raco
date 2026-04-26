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
    system("killall -9 thermald android.hardware.thermal@2.0-service 2>/dev/null");
    
    // FIXED: Exclude 'anya_thermal' so the binary doesn't kill itself!
    system("pgrep -f \"thermal\" | grep -v \"hal\" | grep -v \"anya_thermal\" | xargs -r kill -9 2>/dev/null");

    FILE *fp = popen("getprop | grep -E 'init.svc.*thermal' | grep -v \"hal\" | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]'", "r");
    if (fp) {
        char svc[128];
        while (fgets(svc, sizeof(svc), fp)) {
            svc[strcspn(svc, "\n")] = 0;
            if (strlen(svc) > 0) {
                char cmd[256];
                snprintf(cmd, sizeof(cmd), "stop \"%s\"; setprop ctl.stop \"%s\"", svc, svc);
                system(cmd);
            }
        }
        pclose(fp);
    }
}

void disable_fs_protections() {
    system("mount -o bind /dev/null /vendor/bin/thermald 2>/dev/null");
    system("rm -f /data/vendor/thermal/config /data/vendor/thermal/*.dump 2>/dev/null");
}

void disable_cpu_limits() {
    glob_t globbuf;
    if (glob("/sys/devices/system/cpu/cpu*/core_ctl/enable", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) {
            tweak("0", globbuf.gl_pathv[i]);
        }
        globfree(&globbuf);
    }

    FILE *fp = popen("find /sys/ -name enabled 2>/dev/null | grep 'msm_thermal'", "r");
    if (fp) {
        char path[256];
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
    kakangku("2 0", "/proc/ppm/policy_status");
    kakangku("3 0", "/proc/ppm/policy_status");
    kakangku("4 0", "/proc/ppm/policy_status");
    kakangku("6 0", "/proc/ppm/policy_status");
    kakangku("7 0", "/proc/ppm/policy_status");

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
    FILE *fp = popen("getprop | grep -E 'sys\\..*thermal|thermal_config' | grep -v 'hal' | cut -d: -f1 | tr -d '[]'", "r");
    if (fp) {
        char prop[128];
        while (fgets(prop, sizeof(prop), fp)) {
            prop[strcspn(prop, "\n")] = 0;
            if (strlen(prop) > 0) {
                char cmd[256];
                snprintf(cmd, sizeof(cmd), "resetprop -n \"%s\" \"0\"", prop);
                system(cmd);
            }
        }
        pclose(fp);
    }

    system("if resetprop debug.thermal.throttle.support | grep -q 'yes'; then resetprop -n -v debug.thermal.throttle.support no; fi");

    fp = popen("getprop | grep 'thermal' | grep -v 'hal' | cut -d '[' -f2 | cut -d ']' -f1", "r");
    if (fp) {
        char prop[128];
        while (fgets(prop, sizeof(prop), fp)) {
            prop[strcspn(prop, "\n")] = 0;
            if (strlen(prop) > 0) {
                char cmd[256];
                snprintf(cmd, sizeof(cmd), "resetprop -n \"%s\" \"running\"", prop);
                system(cmd);
            }
        }
        pclose(fp);
    }
}

// ==========================================
// ANYA KAWAII (RESTORE THERMAL)
// ==========================================

void restore_hardware() {
    glob_t globbuf;
    if (glob("/sys/devices/system/cpu/cpu*/core_ctl/enable", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) {
            kakangku("1", globbuf.gl_pathv[i]);
        }
        globfree(&globbuf);
    }

    FILE *fp = popen("find /sys/ -name enabled 2>/dev/null | grep 'msm_thermal'", "r");
    if (fp) {
        char path[256];
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
    
    system("umount /vendor/bin/thermald 2>/dev/null");
    restore_hardware();

    system("cmd thermalservice override-status 1 2>/dev/null");
    system("cmd thermalservice reset 2>/dev/null");

    FILE *fp = popen("getprop | grep -E 'init.svc(\\.vendor)?\\.thermal' | grep -v 'hal' | cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]'", "r");
    if (fp) {
        char svc[128];
        while (fgets(svc, sizeof(svc), fp)) {
            svc[strcspn(svc, "\n")] = 0;
            if (strlen(svc) > 0) {
                char cmd[256];
                snprintf(cmd, sizeof(cmd), "resetprop -n \"init.svc.%s\" \"stopped\"; start \"%s\"; setprop ctl.start \"%s\"", svc, svc, svc);
                system(cmd);
            }
        }
        pclose(fp);
    }

    fp = popen("getprop | grep 'thermal' | grep -v 'hal' | cut -d '[' -f2 | cut -d ']' -f1", "r");
    if (fp) {
        char prop[128];
        while (fgets(prop, sizeof(prop), fp)) {
            prop[strcspn(prop, "\n")] = 0;
            if (strlen(prop) > 0) {
                char cmd[256];
                snprintf(cmd, sizeof(cmd), "resetprop -n \"%s\" \"running\"", prop);
                system(cmd);
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

    if (strcmp(argv[1], "disable") == 0) {
        printf("[*] Initializing AnyaMelfissa (Disabling Thermal)...\n");
        kill_thermal_services();
        system("cmd thermalservice override-status 0 2>/dev/null");
        disable_fs_protections();
        disable_cpu_limits();
        disable_gpu_limits();
        spoof_running_status();
        printf("[+] Thermal successfully disabled.\n");
    } 
    else if (strcmp(argv[1], "restore") == 0 || strcmp(argv[1], "enable") == 0) {
        restore_thermal();
    } 
    else {
        printf("Error: Invalid argument '%s'\n", argv[1]);
        return 1;
    }
    
    return 0;
}