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
#include <dirent.h>
#include <sys/stat.h>
#include <glob.h>
#include "raco_utils.h"

RacoConfig config;
#define RACO_CONFIG "/data/ProjectRaco/raco.txt"

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
        if (stat(path, &statbuf) == 0) {
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
        if (sscanf(line, "%63[^=]=%63s", key, value) == 2) {
            if (strcmp(key, "SOC") == 0) config.soc = atoi(value);
            else if (strcmp(key, "LITE_MODE") == 0) config.lite_mode = atoi(value);
            else if (strcmp(key, "BETTER_POWERSAVE") == 0) config.better_powersave = atoi(value);
            else if (strcmp(key, "DEVICE_MITIGATION") == 0) config.device_mitigation = atoi(value);
            else if (strcmp(key, "ANYA") == 0) config.anya = atoi(value);
            else if (strcmp(key, "INCLUDE_ANYA") == 0) config.include_anya = atoi(value);
        }
        line = strtok(NULL, "\n");
    }
}

void set_state(int new_state) {
    config.state = new_state;
}