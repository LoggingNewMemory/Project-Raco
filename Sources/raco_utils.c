/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
*/

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>
#include <glob.h>
#include "raco_utils.h"

RacoConfig config;
#define RACO_CONFIG "/data/ProjectRaco/raco.txt"

int r_silent_notif = 1;
int r_legacy_notif = 0;

int cmp_int(const void *a, const void *b) {
    return (*(int*)a - *(int*)b);
}

int get_freqs(const char *path, int *freqs, int max_size) {
    char buffer[4096] = {0};
    if (moco(path, buffer, sizeof(buffer)) <= 0) return 0;
    
    int count = 0;
    char *token = strtok(buffer, " \n");
    while (token != NULL && count < max_size) {
        freqs[count++] = atoi(token);
        token = strtok(NULL, " \n");
    }
    
    qsort(freqs, count, sizeof(int), cmp_int);
    return count;
}

char* get_maxfreq(const char *path) {
    static char res[32];
    int freqs[64];
    int count = get_freqs(path, freqs, 64);
    if (count > 0) snprintf(res, sizeof(res), "%d", freqs[count - 1]);
    else strcpy(res, "");
    return res;
}

char* get_minfreq(const char *path) {
    static char res[32];
    int freqs[64];
    int count = get_freqs(path, freqs, 64);
    if (count > 0) snprintf(res, sizeof(res), "%d", freqs[0]);
    else strcpy(res, "");
    return res;
}

char* get_midfreq(const char *path) {
    static char res[32];
    int freqs[64];
    int count = get_freqs(path, freqs, 64);
    if (count > 0) snprintf(res, sizeof(res), "%d", freqs[count / 2]);
    else strcpy(res, "");
    return res;
}

// Native C recursive search replacing `popen("find ...")`
void find_and_tweak_filter_recursive(const char *base_path, const char *target_name, const char *filter, const char *val, int lock) {
    DIR *dir = opendir(base_path);
    if (!dir) return;
    struct dirent *entry;
    char path[512];
    
    while ((entry = readdir(dir)) != NULL) {
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) continue;
        
        snprintf(path, sizeof(path), "%s/%s", base_path, entry->d_name);
        struct stat statbuf;
        
        // Use lstat() to avoid following symlink loops in sysfs
        if (lstat(path, &statbuf) == 0) {
            if (S_ISDIR(statbuf.st_mode)) {
                find_and_tweak_filter_recursive(path, target_name, filter, val, lock);
            } else if (S_ISREG(statbuf.st_mode) && strcmp(entry->d_name, target_name) == 0) {
                if (!filter || strstr(path, filter)) {
                    if (lock) tweak(val, path);
                    else kakangku(val, path);
                }
            }
        }
    }
    closedir(dir);
}

void find_and_tweak(const char *dir, const char *name, const char *val, int lock) {
    find_and_tweak_filter_recursive(dir, name, NULL, val, lock);
}

void find_and_tweak_filter(const char *dir, const char *name, const char *filter, const char *val, int lock) {
    find_and_tweak_filter_recursive(dir, name, filter, val, lock);
}

void change_cpu_gov(const char *gov) {
    glob_t globbuf;
    if (glob("/sys/devices/system/cpu/cpufreq/policy*/scaling_governor", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) {
            tweak(gov, globbuf.gl_pathv[i]);
        }
        globfree(&globbuf);
    }
}

void load_config() {
    char buffer[1024] = {0};
    if (moco(RACO_CONFIG, buffer, sizeof(buffer)) <= 0) return;
    
    char *line = strtok(buffer, "\n");
    char key[64], value[64];
    
    while (line != NULL) {
        if (sscanf(line, "%63s %63s", key, value) == 2) {
            if (strcmp(key, "SOC") == 0) config.soc = atoi(value);
            else if (strcmp(key, "BETTER_POWERSAVE") == 0) config.better_powersave = atoi(value);
            else if (strcmp(key, "DEVICE_MITIGATION") == 0) config.device_mitigation = atoi(value);
            else if (strcmp(key, "ANYA") == 0) config.anya = atoi(value);
            else if (strcmp(key, "INCLUDE_ANYA") == 0) config.include_anya = atoi(value);
            else if (strcmp(key, "SILENT_NOTIF") == 0) r_silent_notif = atoi(value);
            else if (strcmp(key, "LEGACY_NOTIF") == 0) r_legacy_notif = atoi(value);
        }
        line = strtok(NULL, "\n");
    }
}

void set_state(int new_state) {
    config.state = new_state;
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "if grep -q '^STATE ' %s; then sed -i 's/^STATE .*/STATE %d/' %s; else echo 'STATE %d' >> %s; fi", RACO_CONFIG, new_state, RACO_CONFIG, new_state, RACO_CONFIG);
    system(cmd);
}

void notification(const char *message) {
    if (r_silent_notif == 0) {
        return; // Muted via user setting
    }

    char cmd[1024];
    if (r_legacy_notif == 1) {
        snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t 'Project Raco' TagRaco '%s' &\"", message);
    } else {
        snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t 'Project Raco' -i file:///data/local/tmp/logo.png -I file:///data/local/tmp/logo.png TagRaco '%s' &\"", message);
    }
    system(cmd);
}