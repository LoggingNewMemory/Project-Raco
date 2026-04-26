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

int _get_cpu_load() {
    char buffer[512] = {0};
    unsigned long long u, n, s, i, iw, irq, sirq, steal;

    // First Read
    if (moco("/proc/stat", buffer, sizeof(buffer)) <= 0) return 0;
    sscanf(buffer, "cpu %llu %llu %llu %llu %llu %llu %llu %llu", &u, &n, &s, &i, &iw, &irq, &sirq, &steal);
    unsigned long long t1 = u + n + s + i + iw + irq + sirq + steal;
    unsigned long long i1 = i + iw;

    usleep(100000); 

    // Second Read
    if (moco("/proc/stat", buffer, sizeof(buffer)) <= 0) return 0;
    sscanf(buffer, "cpu %llu %llu %llu %llu %llu %llu %llu %llu", &u, &n, &s, &i, &iw, &irq, &sirq, &steal);
    unsigned long long t2 = u + n + s + i + iw + irq + sirq + steal;
    unsigned long long i2 = i + iw;

    if (t2 - t1 == 0) return 0;
    return (int)((100 * ((t2 - t1) - (i2 - i1))) / (t2 - t1));
}

void apply_carcpu(int hardlock) {
    int load = _get_cpu_load();
    int target = (load > hardlock) ? hardlock : load;
    char cmd[128];
    snprintf(cmd, sizeof(cmd), "setprop debug.hwui.target_cpu_time_percent %d", target);
    system(cmd);
    system("iorenice $$ 7 idle; renice -n 19 -p $$; taskset -ap 1 $$ >/dev/null 2>&1");
}

void carcpu_perf() { apply_carcpu(80); }
void carcpu_balance() { apply_carcpu(55); }
void carcpu_battery() { apply_carcpu(40); }

void clear_cache() {
    glob_t globbuf;
    if (glob("/data/data/*/cache/*", GLOB_NOSORT, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) remove(globbuf.gl_pathv[i]);
        globfree(&globbuf);
    }
    if (glob("/data/data/*/code_cache/*", GLOB_NOSORT, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) remove(globbuf.gl_pathv[i]);
        globfree(&globbuf);
    }
    
    system("pm trim-caches 1024G >/dev/null 2>&1");
    system("cmd stats clear-puller-cache");
    system("cmd activity clear-debug-app");
    system("cmd activity clear-watch-heap -a");
    system("cmd package art cleanup");
}

void run_fstrim() {
    system("busybox fstrim -v /data >/dev/null 2>&1");
    usleep(100000);
    system("busybox fstrim -v /cache >/dev/null 2>&1");
}

void corin_perf() {
    system("settings put secure high_priority 1; settings put secure low_priority 0");
    system("cmd power set-adaptive-power-saver-enabled false");
    system("cmd power set-fixed-performance-mode-enabled true");
    system("cmd looper_stats disable");
    system("cmd power set-mode 0; cmd power thermalservice override-status 0");
    system("atrace --async_stop >/dev/null 2>&1");
}

void corin_balanced() {
    system("settings put secure high_priority 1; settings put secure low_priority 0");
    system("cmd power set-adaptive-power-saver-enabled false");
    system("cmd power set-fixed-performance-mode-enabled false");
    system("cmd looper_stats enable");
    system("cmd power set-mode 0; cmd power thermalservice override-status 0");
}

void corin_powersave() {
    system("settings put secure high_priority 0; settings put secure low_priority 1");
    system("cmd power set-adaptive-power-saver-enabled true");
    system("cmd power set-fixed-performance-mode-enabled false");
    system("cmd power set-mode 1; cmd power thermalservice override-status 3");
}

void raco_kill_all() {
    sync();

    system("cmd activity kill-all > /dev/null 2>&1");

    FILE *fp = popen("pm list packages -3 | cut -f 2 -d ':'", "r");
    if (fp) {
        char pkg[256];
        while (fgets(pkg, sizeof(pkg), fp)) {
            pkg[strcspn(pkg, "\n")] = 0;
            
            if (strcmp(pkg, "com.google.android.inputmethod.latin") != 0 && strlen(pkg) > 0) {
                char cmd[512];
                snprintf(cmd, sizeof(cmd), "am force-stop \"%s\" > /dev/null 2>&1", pkg);
                system(cmd);
            }
        }
        pclose(fp);
    }

    system("pm trim-caches 100G > /dev/null 2>&1");
    tweak("3", "/proc/sys/vm/drop_caches");

    system("logcat -c");
    system("logcat -b all -c");
}