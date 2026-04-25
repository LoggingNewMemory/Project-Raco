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

#ifndef RACO_UTILS_H
#define RACO_UTILS_H

#include <stdint.h>

// External ARM64 Assembly bindings
extern void tweak(const char *value, const char *path);
extern void kakangku(const char *value, const char *path);
extern int moco(const char *path, char *buffer, int size);

// Global Configuration
typedef struct {
    int soc;
    int lite_mode;
    int better_powersave;
    int anya;
    int include_anya;
    int kcpu_mitigate;
    int legacy_notif;
    int silent_notif;
    int device_mitigation;
    int dnd;
    int bypass_enable;
    char default_cpu_gov[32];
    int state;
} RacoConfig;

extern RacoConfig config;

// Shared Utility Prototypes
void load_config();
void set_state(int new_state);
void find_and_tweak(const char *dir, const char *name, const char *val, int lock);
void find_and_tweak_filter(const char *dir, const char *name, const char *filter, const char *val, int lock);
char* get_maxfreq(const char *path);
char* get_minfreq(const char *path);
char* get_midfreq(const char *path);
void change_cpu_gov(const char *gov);

// Module Prototypes
void carcpu_perf();
void carcpu_balance();
void carcpu_battery();
void clear_cache();
void run_fstrim();
void corin_perf();
void corin_balanced();
void corin_powersave();
void kobo_fast_charge();
void raco_kill_all();

#endif // RACO_UTILS_H