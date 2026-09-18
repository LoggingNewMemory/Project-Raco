/*
Project Raco - Anya Thermal Control
Copyright (C) 2026 Kanagawa Yamada 
 */

#include "raco.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <sys/mount.h>
#include <ctype.h>
#include <signal.h>

#define FAKE_TEMP_FILE "/data/adb/modules/ProjectRaco/fake_temp"
#define FAKE_ZERO_FILE "/data/adb/modules/ProjectRaco/fake_zero"
#define FAKE_TEMP_VALUE "30000\n"
#define FAKE_ZERO_VALUE "0\n"
#define THERMAL_DIR "/sys/class/thermal"

// ==========================================
// Gen 1 - POSIX Implementation
// ==========================================

static void kill_thermal_processes() {
    DIR *dir = opendir("/proc");
    if (!dir) return;

    struct dirent *ent;
    while ((ent = readdir(dir)) != NULL) {
        if (!isdigit(ent->d_name[0])) continue;

        int pid = atoi(ent->d_name);
        char cmdline_path[256];
        snprintf(cmdline_path, sizeof(cmdline_path), "/proc/%d/cmdline", pid);

        FILE *f = fopen(cmdline_path, "r");
        if (f) {
            char cmdline[256] = {0};
            size_t bytes_read = fread(cmdline, 1, sizeof(cmdline) - 1, f);
            fclose(f);
            
            if (bytes_read > 0) {
                for (size_t i = 0; i < bytes_read; i++) {
                    if (cmdline[i] == '\0') cmdline[i] = ' ';
                }
                
                char lower_cmd[256];
                strncpy(lower_cmd, cmdline, sizeof(lower_cmd));
                for(int i = 0; lower_cmd[i]; i++) {
                    lower_cmd[i] = tolower(lower_cmd[i]);
                }
                
                if (strstr(lower_cmd, "thermal")) {
                    if (!strstr(lower_cmd, "hal") && !strstr(lower_cmd, "hardware.thermal")) {
                        kill(pid, SIGKILL);
                    }
                }
            }
        }
    }
    closedir(dir);
}


void exec_anya_kawaii() {
    pid_t pid = fork();
    if (pid != 0) return;
    printf("Anya Kawaii Start\n");

    system("getprop | grep -E '^\\[init\\.svc\\..*thermal' | grep -v -iE 'hal|hardware\\.thermal' | "
           "cut -d: -f1 | tr -d '[]' | sed 's/init\\.svc\\.//g' | "
           "while read -r svc; do resetprop -n \"init.svc.$svc\" \"stopped\"; start \"$svc\"; done");

    exit(0);
}

void exec_anya_melfissa() {
    pid_t pid = fork();
    if (pid != 0) return;
    printf("Anya Melfissa Start...\n");

    system("getprop | grep -E '^\\[init\\.svc\\..*thermal' | grep -v -iE 'hal|hardware\\.thermal' | "
           "cut -d: -f1 | tr -d '[]' | sed 's/init\\.svc\\.//g' | "
           "while read -r svc; do stop \"$svc\"; done");

    kill_thermal_processes();

    exit(0);
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
    printf("Anya Kawaii Gen 2 Start\n");
    restore_thermal_gen2();
    exit(0);
}

void exec_anya_melfissa_gen2() {
    pid_t pid = fork();
    if (pid != 0) return;
    printf("Anya Melfissa Gen 2 Start...\n");
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