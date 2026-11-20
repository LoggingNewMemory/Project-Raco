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
// Gen 1 - Anya Kawaii & Anya Melfissa (POSIX Implementation)
// ==========================================

// Pre-collect PIDs of all HAL services from getprop init.svc_debug_pid.*
static int get_hal_pids(pid_t *hal_pids, int max_pids) {
    int count = 0;
    FILE *fp = popen("getprop", "r");
    if (!fp) return 0;

    char line[1024];
    while (fgets(line, sizeof(line), fp)) {
        char *key_start = strchr(line, '[');
        if (!key_start) continue;
        key_start++;
        char *key_end = strchr(key_start, ']');
        if (!key_end) continue;
        *key_end = '\0';

        if (strncmp(key_start, "init.svc_debug_pid.", 19) != 0) continue;

        const char *svc_name = key_start + 19;
        if (strcasestr(svc_name, "hal") == NULL) {
            continue;
        }

        char *val_start = strchr(key_end + 1, '[');
        if (!val_start) continue;
        val_start++;
        char *val_end = strchr(val_start, ']');
        if (!val_end) continue;
        *val_end = '\0';

        pid_t pid = (pid_t)atoi(val_start);
        if (pid > 1 && count < max_pids) {
            hal_pids[count++] = pid;
        }
    }
    pclose(fp);
    return count;
}

static int is_hal_or_protected(pid_t pid, const char *cmdline, const char *comm,
                               const pid_t *hal_pids, int hal_pid_count) {
    for (int i = 0; i < hal_pid_count; i++) {
        if (pid == hal_pids[i]) return 1;
    }

    char lower_cmd[512] = {0};
    for (size_t i = 0; cmdline[i] && i < sizeof(lower_cmd) - 1; i++) {
        lower_cmd[i] = tolower((unsigned char)cmdline[i]);
    }
    char lower_comm[256] = {0};
    for (size_t i = 0; comm[i] && i < sizeof(lower_comm) - 1; i++) {
        lower_comm[i] = tolower((unsigned char)comm[i]);
    }

    // 1. Raco / Anya self-protection
    if (strstr(lower_cmd, "raco") || strstr(lower_cmd, "anya") ||
        strstr(lower_comm, "raco") || strstr(lower_comm, "anya")) {
        return 1;
    }

    // 2. HAL protection (literal "hal")
    if (strstr(lower_cmd, "hal") || strstr(lower_comm, "hal")) {
        return 1;
    }

    // 3. Inspect /proc/<pid>/exe target
    char exe_link[256];
    snprintf(exe_link, sizeof(exe_link), "/proc/%d/exe", pid);
    char exe_target[512] = {0};
    ssize_t len = readlink(exe_link, exe_target, sizeof(exe_target) - 1);
    if (len > 0) {
        exe_target[len] = '\0';
        char lower_exe[512] = {0};
        for (size_t i = 0; exe_target[i] && i < sizeof(lower_exe) - 1; i++) {
            lower_exe[i] = tolower((unsigned char)exe_target[i]);
        }
        if (strstr(lower_exe, "hal")) {
            return 1;
        }
    }

    // 4. Inspect SELinux domain (/proc/<pid>/attr/current)
    char attr_path[256];
    snprintf(attr_path, sizeof(attr_path), "/proc/%d/attr/current", pid);
    FILE *fa = fopen(attr_path, "r");
    if (fa) {
        char domain[256] = {0};
        if (fgets(domain, sizeof(domain), fa)) {
            if (strcasestr(domain, "hal_") != NULL || strcasestr(domain, "hal") != NULL) {
                fclose(fa);
                return 1;
            }
        }
        fclose(fa);
    }

    // 5. Check UID: Android user applications have UID >= 10000
    char status_path[256];
    snprintf(status_path, sizeof(status_path), "/proc/%d/status", pid);
    FILE *fs = fopen(status_path, "r");
    if (fs) {
        char sline[256];
        while (fgets(sline, sizeof(sline), fs)) {
            if (strncmp(sline, "Uid:", 4) == 0) {
                int ruid = 0;
                if (sscanf(sline + 4, "%d", &ruid) == 1 && ruid >= 10000) {
                    fclose(fs);
                    return 1;
                }
                break;
            }
        }
        fclose(fs);
    }

    return 0;
}

static void kill_thermal_processes() {
    pid_t hal_pids[64];
    int hal_pid_count = get_hal_pids(hal_pids, 64);

    DIR *dir = opendir("/proc");
    if (!dir) return;

    pid_t my_pid = getpid();
    pid_t my_ppid = getppid();

    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL) {
        if (!isdigit(ent->d_name[0])) continue;

        int pid = atoi(ent->d_name);
        if (pid <= 1 || pid == my_pid || pid == my_ppid) continue;

        char path[256];
        snprintf(path, sizeof(path), "/proc/%d/cmdline", pid);

        char cmdline[512] = {0};
        FILE *f = fopen(path, "r");
        if (f) {
            size_t bytes_read = fread(cmdline, 1, sizeof(cmdline) - 1, f);
            fclose(f);
            for (size_t i = 0; i < bytes_read; i++) {
                if (cmdline[i] == '\0') cmdline[i] = ' ';
            }
        }

        char comm[256] = {0};
        snprintf(path, sizeof(path), "/proc/%d/comm", pid);
        FILE *fc = fopen(path, "r");
        if (fc) {
            if (fgets(comm, sizeof(comm), fc)) {
                comm[strcspn(comm, "\r\n")] = '\0';
            }
            fclose(fc);
        }

        if (cmdline[0] == '\0' && comm[0] == '\0') continue;

        if (is_hal_or_protected(pid, cmdline, comm, hal_pids, hal_pid_count)) {
            continue;
        }

        char lower_cmd[512] = {0};
        for (size_t i = 0; cmdline[i] && i < sizeof(lower_cmd) - 1; i++) {
            lower_cmd[i] = tolower((unsigned char)cmdline[i]);
        }
        char lower_comm[256] = {0};
        for (size_t i = 0; comm[i] && i < sizeof(lower_comm) - 1; i++) {
            lower_comm[i] = tolower((unsigned char)comm[i]);
        }

        if (strstr(lower_cmd, "thermal") || strstr(lower_comm, "thermal")) {
            // Strictly avoid any thermal service or process that includes hal
            if (strstr(lower_cmd, "hal") || strstr(lower_comm, "hal")) {
                continue;
            }
            kill(pid, SIGKILL);
        }
    }
    closedir(dir);
}

static void stop_thermal_init_services() {
    FILE *fp = popen("getprop", "r");
    if (!fp) return;

    char line[1024];
    while (fgets(line, sizeof(line), fp)) {
        char *key_start = strchr(line, '[');
        if (!key_start) continue;
        key_start++;
        char *key_end = strchr(key_start, ']');
        if (!key_end) continue;
        *key_end = '\0';

        const char *prop = key_start;
        if (strncmp(prop, "init.svc.", 9) != 0) continue;
        const char *svc = prop + 9;

        // MUST avoid any thermal service that includes hal
        if (strcasestr(prop, "hal") != NULL || strcasestr(svc, "hal") != NULL) {
            continue;
        }

        if (strcasestr(svc, "thermal") != NULL) {
            char cmd[512];
            snprintf(cmd, sizeof(cmd), "stop '%s'; setprop ctl.stop '%s'", svc, svc);
            system(cmd);
        }
    }
    pclose(fp);
}

static void set_msm_thermal(const char *val1, const char *val2) {
    const char *msm_mod_base = "/sys/module/msm_thermal";
    const char *msm_mod_files[] = {
        "parameters/enabled",
        "core_control/enabled",
        "vdd_restriction/enabled"
    };
    int msm_mod_count = sizeof(msm_mod_files) / sizeof(msm_mod_files[0]);
    raco_bulk(msm_mod_base, msm_mod_files, msm_mod_count, val1, 1);
    if (val2) {
        raco_bulk(msm_mod_base, msm_mod_files, msm_mod_count, val2, 1);
    }

    rakakikomi(val1, "/sys/kernel/msm_thermal/enabled");
    if (val2) rakakikomi(val2, "/sys/kernel/msm_thermal/enabled");

    rakakikomi(val1, "/sys/devices/virtual/thermal/thermal_message/sconfig");
    if (val2) rakakikomi(val2, "/sys/devices/virtual/thermal/thermal_message/sconfig");

    DIR *dir = opendir("/sys/module/msm_thermal");
    if (dir) {
        struct dirent *ent;
        while ((ent = readdir(dir)) != NULL) {
            if (ent->d_name[0] == '.') continue;
            char subpath[512];
            snprintf(subpath, sizeof(subpath), "/sys/module/msm_thermal/%s", ent->d_name);
            const char *enabled_file[] = {"enabled"};
            raco_bulk(subpath, enabled_file, 1, val1, 1);
            if (val2) raco_bulk(subpath, enabled_file, 1, val2, 1);
        }
        closedir(dir);
    }
}

// ----------------- Anya Melfissa Modules -----------------

static void disable_fs_protections() {
    // Delete Cache
    unlink("/data/vendor/thermal/config");
    DIR *dir = opendir("/data/vendor/thermal");
    if (dir) {
        struct dirent *ent;
        while ((ent = readdir(dir)) != NULL) {
            size_t len = strlen(ent->d_name);
            if (len >= 5 && strcmp(ent->d_name + len - 5, ".dump") == 0) {
                char dump_path[512];
                snprintf(dump_path, sizeof(dump_path), "/data/vendor/thermal/%s", ent->d_name);
                unlink(dump_path);
            }
        }
        closedir(dir);
    }
}

static void disable_thermal_sysfs() {
    // 1. MSM Thermal
    set_msm_thermal("N", "0");
    system("find /sys/ -name enabled 2>/dev/null | grep 'msm_thermal' | while read -r msm; do echo N > \"$msm\" 2>/dev/null; echo 0 > \"$msm\" 2>/dev/null; done &");

    // 2. ZTE / Unisoc thermal control
    rakakikomi("0", "/sys/module/zte_misc/parameters/thermal_control_en");

    // 3. PPM Policy
    rakakikomi("1", "/proc/ppm/enabled");
    static const char *ppm_policies[] = {"2 0", "3 0", "4 0", "6 0", "7 0"};
    for (size_t i = 0; i < sizeof(ppm_policies) / sizeof(ppm_policies[0]); i++) {
        rakakikomi(ppm_policies[i], "/proc/ppm/policy_status");
    }

    // Disable Logging/Debug/Panic
    const char *kernel_base = "/proc/sys/kernel";
    const char *kernel_files[] = {"sched_boost", "panic", "panic_on_oops"};
    int kernel_count = sizeof(kernel_files) / sizeof(kernel_files[0]);
    raco_bulk(kernel_base, kernel_files, kernel_count, "0", 1);

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
    set_msm_thermal("Y", "1");
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

static void restore_services_kawaii() {
    FILE *fp = popen("getprop", "r");
    if (!fp) return;

    char svc_list[64][128];
    int svc_count = 0;

    char line[1024];
    while (fgets(line, sizeof(line), fp)) {
        char *key_start = strchr(line, '[');
        if (!key_start) continue;
        key_start++;
        char *key_end = strchr(key_start, ']');
        if (!key_end) continue;
        *key_end = '\0';

        const char *prop = key_start;
        if (strncmp(prop, "init.svc.", 9) != 0) continue;
        const char *svc = prop + 9;

        // MUST avoid any service that includes 'hal'
        if (strcasestr(prop, "hal") != NULL || strcasestr(svc, "hal") != NULL) {
            continue;
        }

        // Collect init services: init.svc(\.vendor)?\.thermal
        if (strcasestr(svc, "thermal") != NULL) {
            if (svc_count < 64) {
                strncpy(svc_list[svc_count], svc, sizeof(svc_list[0]) - 1);
                svc_list[svc_count][sizeof(svc_list[0]) - 1] = '\0';
                svc_count++;
            }
        }
    }
    pclose(fp);

    // 1. Start Services genuinely first (Excluded 'hal')
    for (int i = 0; i < svc_count; i++) {
        char cmd[512];
        snprintf(cmd, sizeof(cmd),
                 "resetprop -n 'init.svc.%s' 'stopped'; start '%s'; setprop ctl.start '%s'",
                 svc_list[i], svc_list[i], svc_list[i]);
        system(cmd);
    }

    // 2. Ensure any HAL service that might have been stopped is running
    FILE *fphal = popen("getprop", "r");
    if (fphal) {
        char hline[1024];
        while (fgets(hline, sizeof(hline), fphal)) {
            char *k_start = strchr(hline, '[');
            if (!k_start) continue;
            k_start++;
            char *k_end = strchr(k_start, ']');
            if (!k_end) continue;
            *k_end = '\0';

            char *v_start = strchr(k_end + 1, '[');
            if (!v_start) continue;
            v_start++;
            char *v_end = strchr(v_start, ']');
            if (!v_end) continue;
            *v_end = '\0';

            if (strncmp(k_start, "init.svc.", 9) == 0 && strcasestr(k_start, "thermal") != NULL) {
                if (strcasestr(k_start, "hal") != NULL) {
                    if (strcmp(v_start, "running") != 0) {
                        const char *hal_svc = k_start + 9;
                        char cmd[512];
                        snprintf(cmd, sizeof(cmd), "start '%s'; setprop ctl.start '%s'", hal_svc, hal_svc);
                        system(cmd);
                    }
                }
            }
        }
        pclose(fphal);
    }
}

// ----------------- Public Entry Points (Gen 1) -----------------

void exec_anya_kawaii() {
    // 1. Restore Hardware
    restore_hardware();

    // 2. Start Services & Restore Status
    restore_services_kawaii();
}

void exec_anya_melfissa() {
    // 1. Kill and stop non-HAL thermal services
    kill_thermal_processes();
    stop_thermal_init_services();

    // 2. Disable thermal protections and limits
    disable_fs_protections();
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