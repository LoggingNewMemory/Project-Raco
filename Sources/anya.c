/*
 * Project Raco - Performance and Gaming Optimization Suite
 * Copyright (C) 2026 Kanagawa Yamada <albert.wesley.dion@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#define _GNU_SOURCE
#include "raco.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <sys/wait.h>
#include <ctype.h>
#include <signal.h>

#define FAKE_TEMP_FILE "/data/adb/modules/ProjectRaco/fake_temp"
#define FAKE_ZERO_FILE "/data/adb/modules/ProjectRaco/fake_zero"
#define FAKE_TEMP_VALUE "30000\n"
#define FAKE_ZERO_VALUE "0\n"
#define THERMAL_DIR "/sys/class/thermal"

// ==========================================
// Gen 1 - Anya Kawaii & Anya Melfissa
// ==========================================

static void disable_fs_protections() {
    unlink("/data/vendor/thermal/config");
    unlink("/data/vendor/thermal/thermal.dump");
    unlink("/data/vendor/thermal/thermal_history.dump");
    DIR *dir = opendir("/data/vendor/thermal");
    if (dir) {
        struct dirent *ent;
        while ((ent = readdir(dir)) != NULL) {
            size_t len = strlen(ent->d_name);
            if ((len >= 5 && strcmp(ent->d_name + len - 5, ".dump") == 0) ||
                strcmp(ent->d_name, "config") == 0) {
                char dump_path[512];
                snprintf(dump_path, sizeof(dump_path), "/data/vendor/thermal/%s", ent->d_name);
                unlink(dump_path);
            }
        }
        closedir(dir);
    }
}

static void stop_thermal_init_services() {
    system("stop thermald 2>/dev/null; stop thermal_core 2>/dev/null; "
           "setprop ctl.stop thermald 2>/dev/null; setprop ctl.stop thermal_core 2>/dev/null;");
}

static void disable_thermal_zones() {
    DIR *dir = opendir("/sys/class/thermal");
    if (!dir) return;

    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL) {
        if (strncmp(ent->d_name, "thermal_zone", 12) == 0) {
            char path[512];
            snprintf(path, sizeof(path), "/sys/class/thermal/%s/mode", ent->d_name);
            rawrite("disabled", path);

            snprintf(path, sizeof(path), "/sys/class/thermal/%s/policy", ent->d_name);
            rawrite("user_space", path);
        }
    }
    closedir(dir);
}

static void reset_cooling_devices() {
    DIR *dir = opendir("/sys/class/thermal");
    if (!dir) return;

    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL) {
        if (strncmp(ent->d_name, "cooling_device", 14) == 0) {
            char cur_state[512];
            snprintf(cur_state, sizeof(cur_state), "/sys/class/thermal/%s/cur_state", ent->d_name);
            rawrite("0", cur_state);
        }
    }
    closedir(dir);
}

static void snapdragon_msm_thermal_apply(int mode) {
    const char *v_val = (mode == 0) ? "0" : "1";
    const char *v_chr = (mode == 0) ? "N" : "Y";

    // Dynamic module walk covers parameters/enabled, core_control/enabled, vdd_restriction/enabled, etc.
    DIR *dir = opendir("/sys/module/msm_thermal");
    if (dir) {
        struct dirent *ent;
        while ((ent = readdir(dir)) != NULL) {
            if (ent->d_name[0] == '.') continue;
            char subpath[512];
            snprintf(subpath, sizeof(subpath), "/sys/module/msm_thermal/%s/enabled", ent->d_name);
            rawrite(v_chr, subpath);
            rawrite(v_val, subpath);
        }
        closedir(dir);
    }

    // Direct kernel-level & module nodes fallback
    rawrite(v_chr, "/sys/module/msm_thermal/parameters/enabled");
    rawrite(v_val, "/sys/module/msm_thermal/parameters/enabled");
    rawrite(v_val, "/sys/kernel/msm_thermal/enabled");
    rawrite(v_val, "/sys/module/thermal/parameters/enabled");

    // Xiaomi thermal message sconfig (always reset to 0)
    rawrite("0", "/sys/devices/virtual/thermal/thermal_message/sconfig");
    rawrite("0", "/sys/class/thermal/thermal_message/sconfig");
}

// ----------------- Anya Melfissa Modules -----------------

static void disable_thermal_sysfs() {
    // 1. MSM Thermal
    snapdragon_msm_thermal_apply(0);
    system("find /sys/ -name enabled 2>/dev/null | grep 'msm_thermal' | while read -r msm; do echo N > \"$msm\" 2>/dev/null; echo 0 > \"$msm\" 2>/dev/null; done &");

    // 2. ZTE / Unisoc thermal control
    rakakikomi("0", "/sys/module/zte_misc/parameters/thermal_control_en");

    // 3. PPM Policy
    rakakikomi("1", "/proc/ppm/enabled");
    static const char *ppm_policies[] = {"2 0", "3 0", "4 0", "6 0", "7 0"};
    for (size_t i = 0; i < sizeof(ppm_policies) / sizeof(ppm_policies[0]); i++) {
        rakakikomi(ppm_policies[i], "/proc/ppm/policy_status");
    }

    // Disable specific modules
    const char *wq_base = "/sys/module/workqueue/parameters";
    const char *wq_files[] = {"power_efficient", "disable_numa"};
    int wq_count = sizeof(wq_files) / sizeof(wq_files[0]);
    raco_bulk(wq_base, wq_files, wq_count, "N", 1);

    // FPSGO & MTK
    rakakikomi("0", "/sys/kernel/fpsgo/fbt/thrm_enable");
    rakakikomi("0", "/sys/kernel/eara_thermal/enable");

    // KGSL & GPU Freq
    const char *kgsl_zero[] = {"throttling", "max_gpuclk", "thermal_pwrlevel"};
    int kgsl_zero_count = sizeof(kgsl_zero) / sizeof(kgsl_zero[0]);

    DIR *dir = opendir("/sys/class/kgsl");
    if (dir) {
        struct dirent *ent;
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "kgsl-3d", 7) == 0) {
                char kgsl_path[512];
                snprintf(kgsl_path, sizeof(kgsl_path), "/sys/class/kgsl/%s", ent->d_name);
                raco_bulk(kgsl_path, kgsl_zero, kgsl_zero_count, "0", 1);

                const char *kgsl_one[] = {"force_clk_on"};
                raco_bulk(kgsl_path, kgsl_one, 1, "1", 1);
            }
        }
        closedir(dir);
    } else {
        const char *kgsl_base = "/sys/class/kgsl/kgsl-3d0";
        raco_bulk(kgsl_base, kgsl_zero, kgsl_zero_count, "0", 1);

        const char *kgsl_one[] = {"force_clk_on"};
        raco_bulk(kgsl_base, kgsl_one, 1, "1", 1);
    }

    // Generic GPU Freq limits
    const char *gpufreq_base = "/proc/gpufreq";
    const char *gpufreq_zero[] = {"gpufreq_power_limited"};
    int gpufreq_zero_count = sizeof(gpufreq_zero) / sizeof(gpufreq_zero[0]);
    raco_bulk(gpufreq_base, gpufreq_zero, gpufreq_zero_count, "0", 1);

    const char *gpufreq_one[] = {"gpufreq_limited_thermal_ignore"};
    int gpufreq_one_count = sizeof(gpufreq_one) / sizeof(gpufreq_one[0]);
    raco_bulk(gpufreq_base, gpufreq_one, gpufreq_one_count, "1", 1);
}

// ----------------- Anya Kawaii Modules -----------------

static void restore_hardware() {
    // 1. Re-enable MSM Thermal
    snapdragon_msm_thermal_apply(1);
    system("find /sys/ -name enabled 2>/dev/null | grep 'msm_thermal' | while read -r msm; do echo Y > \"$msm\" 2>/dev/null; echo 1 > \"$msm\" 2>/dev/null; done &");

    // 2. Re-enable ZTE / Unisoc thermal control
    rakakikomi("1", "/sys/module/zte_misc/parameters/thermal_control_en");

    // 3. Re-enable GPU Throttling
    const char *kgsl_files[] = {"throttling", "thermal_pwrlevel"};
    int kgsl_count = sizeof(kgsl_files) / sizeof(kgsl_files[0]);

    DIR *kdir = opendir("/sys/class/kgsl");
    if (kdir) {
        struct dirent *ent;
        while ((ent = readdir(kdir)) != NULL) {
            if (strncmp(ent->d_name, "kgsl-3d", 7) == 0) {
                char kgsl_path[512];
                snprintf(kgsl_path, sizeof(kgsl_path), "/sys/class/kgsl/%s", ent->d_name);
                raco_bulk(kgsl_path, kgsl_files, kgsl_count, "1", 1);
            }
        }
        closedir(kdir);
    } else {
        const char *kgsl_base = "/sys/class/kgsl/kgsl-3d0";
        raco_bulk(kgsl_base, kgsl_files, kgsl_count, "1", 1);
    }
}

static void restore_thermal_zones() {
    DIR *dir = opendir("/sys/class/thermal");
    if (!dir) return;

    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL) {
        if (strncmp(ent->d_name, "thermal_zone", 12) == 0) {
            char path[512];
            snprintf(path, sizeof(path), "/sys/class/thermal/%s/mode", ent->d_name);
            rakakikomi("enabled", path);

            snprintf(path, sizeof(path), "/sys/class/thermal/%s/policy", ent->d_name);
            rakakikomi("step_wise", path);
        }
    }
    closedir(dir);
}

static void restore_services_kawaii() {
    // 1. Reset Android Framework ThermalService
    system("cmd thermalservice reset 2>/dev/null");

    // 2. Direct start for known Snapdragon / Xiaomi thermal daemons
    system("start thermal-engine 2>/dev/null; start mi_thermald 2>/dev/null; start thermald 2>/dev/null; start thermal_core 2>/dev/null; "
           "setprop ctl.start thermal-engine 2>/dev/null; setprop ctl.start mi_thermald 2>/dev/null; setprop ctl.start thermald 2>/dev/null; setprop ctl.start thermal_core 2>/dev/null;");

    // 3. Restart MIUI MQSAS thermal services
    system("if ! service check miui.mqsas.IMQSNative | grep -q 'not found'; then "
           "  for a in $(find /system/etc/init /vendor/etc/init /odm/etc/init -type f 2>/dev/null | xargs grep -Eh '^service (miui|.*thermal)' 2>/dev/null | awk '{print $2}'); do "
           "    service call miui.mqsas.IMQSNative 21 i32 1 s16 'start' i32 1 s16 \"$a\" s16 '/dev/null' i32 1 >/dev/null 2>&1; "
           "  done; "
           "fi");

    // 4. Query init services via getprop and start them
    system(
        "getprop | grep -Ei '^\\[init\\.svc\\..*thermal' | "
        "grep -vi 'hal' | "
        "sed 's/^\\[init\\.svc\\.\\([^]]*\\)\\].*/\\1/' | "
        "while read -r svc; do "
        "    if [ -n \"$svc\" ]; then "
        "        start \"$svc\" 2>/dev/null; "
        "        setprop ctl.start \"$svc\" 2>/dev/null; "
        "    fi; "
        "done"
    );
}

// ----------------- Public Entry Points (Gen 1) -----------------

void exec_anya_kawaii() {
    restore_hardware();
    restore_thermal_zones();
    restore_services_kawaii();
}

void exec_anya_melfissa() {
    stop_thermal_init_services();
    disable_fs_protections();
    disable_thermal_zones();
    reset_cooling_devices();
    disable_thermal_sysfs();
}

// ==========================================
// Gen 2 - Spoof temp and cdev
// ==========================================

static void umount_all(const char *path) {
    umount2(path, MNT_DETACH);
}

static void mount_bind(const char *src, const char *dest) {
    mount(src, dest, NULL, MS_BIND, NULL);
}

static void create_fake_temp_file() {
    int fd = open(FAKE_TEMP_FILE, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd >= 0) {
        write(fd, FAKE_TEMP_VALUE, strlen(FAKE_TEMP_VALUE));
        close(fd);
    }
}

static void create_fake_zero_file() {
    int fd = open(FAKE_ZERO_FILE, O_CREAT | O_WRONLY | O_TRUNC, 0644);
    if (fd >= 0) {
        write(fd, FAKE_ZERO_VALUE, strlen(FAKE_ZERO_VALUE));
        close(fd);
    }
}

static void spoof_thermal_gen2() {
    create_fake_temp_file();
    create_fake_zero_file();

    DIR *dir = opendir(THERMAL_DIR);
    if (!dir) return;

    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL) {
        if (strncmp(ent->d_name, "thermal_zone", 12) == 0) {
            char zone_path[512];
            snprintf(zone_path, sizeof(zone_path), "%s/%s", THERMAL_DIR, ent->d_name);
            
            char temp_path[512];
            snprintf(temp_path, sizeof(temp_path), "%s/temp", zone_path);

            umount_all(temp_path);
            mount_bind(FAKE_TEMP_FILE, temp_path);
            
            DIR *zdir = opendir(zone_path);
            if (zdir) {
                struct dirent *zent;
                while ((zent = readdir(zdir)) != NULL) {
                    if (strncmp(zent->d_name, "cdev", 4) == 0 && strstr(zent->d_name, "_trip_point") != NULL) {
                        char cdev_path[512];
                        snprintf(cdev_path, sizeof(cdev_path), "%s/%s", zone_path, zent->d_name);
                        umount_all(cdev_path);
                        mount_bind(FAKE_ZERO_FILE, cdev_path);
                    } else if (strncmp(zent->d_name, "cdev", 4) == 0 && strstr(zent->d_name, "_weight") != NULL) {
                        char weight_path[512];
                        snprintf(weight_path, sizeof(weight_path), "%s/%s", zone_path, zent->d_name);
                        umount_all(weight_path);
                        mount_bind(FAKE_ZERO_FILE, weight_path);
                    }
                }
                closedir(zdir);
            }
        }
    }
    closedir(dir);
}

static void restore_thermal_gen2() {
    DIR *dir = opendir(THERMAL_DIR);
    if (!dir) return;

    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL) {
        if (strncmp(ent->d_name, "thermal_zone", 12) == 0) {
            char zone_path[512];
            snprintf(zone_path, sizeof(zone_path), "%s/%s", THERMAL_DIR, ent->d_name);
            
            char temp_path[512];
            snprintf(temp_path, sizeof(temp_path), "%s/temp", zone_path);

            umount_all(temp_path);
            
            DIR *zdir = opendir(zone_path);
            if (zdir) {
                struct dirent *zent;
                while ((zent = readdir(zdir)) != NULL) {
                    if (strncmp(zent->d_name, "cdev", 4) == 0 && strstr(zent->d_name, "_trip_point") != NULL) {
                        char cdev_path[512];
                        snprintf(cdev_path, sizeof(cdev_path), "%s/%s", zone_path, zent->d_name);
                        umount_all(cdev_path);
                    } else if (strncmp(zent->d_name, "cdev", 4) == 0 && strstr(zent->d_name, "_weight") != NULL) {
                        char weight_path[512];
                        snprintf(weight_path, sizeof(weight_path), "%s/%s", zone_path, zent->d_name);
                        umount_all(weight_path);
                    }
                }
                closedir(zdir);
            }
        }
    }
    closedir(dir);
    
    unlink(FAKE_TEMP_FILE);
    unlink(FAKE_ZERO_FILE);
}

void exec_anya_kawaii_gen2() {
    pid_t pid = fork();
    if (pid != 0) return;
    restore_thermal_gen2();
    exit(0);
}

void exec_anya_melfissa_gen2() {
    pid_t pid = fork();
    if (pid != 0) return;
    restore_thermal_gen2();
    spoof_thermal_gen2();
    exit(0);
}

#ifdef STANDALONE
int main(int argc, char *argv[]) {
    if (argc > 1) {
        if (strcmp(argv[1], "kawaii") == 0) {
            exec_anya_kawaii();
        } else if (strcmp(argv[1], "melfissa") == 0) {
            exec_anya_melfissa();
        } else if (strcmp(argv[1], "kawaii_gen2") == 0) {
            exec_anya_kawaii_gen2();
        } else if (strcmp(argv[1], "melfissa_gen2") == 0) {
            exec_anya_melfissa_gen2();
        } else {
            printf("Usage: anya [kawaii|melfissa|kawaii_gen2|melfissa_gen2]\n");
        }
    } else {
        printf("Usage: anya [kawaii|melfissa|kawaii_gen2|melfissa_gen2]\n");
    }
    return 0;
}
#endif