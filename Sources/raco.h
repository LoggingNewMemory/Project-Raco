/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
 */

#ifndef RACO_H
#define RACO_H

// Game Monitoring Service
#define GAMESERVICE_SOCKET "@raco_gameservice"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>

// Call Assembly Functions
extern int raco_write (const char *path, const char *val, unsigned int len);
extern int raco_kakikomi (const char *path, const char *val, unsigned int len);
extern int raco_read (const char *path, char *out_buffer, unsigned int max_size);

// Config Structure
typedef struct {
    int soc;
    int anya;
    int legacy_notif;
    int silent_notif;
    int device_mitigation;
    // Service daemon feature flags — parsed once from raco.txt by load_config()
    // so raco_services.c doesn't need a second file read.
    int inc_kobo;
    int inc_zeta;
    int inc_sandev;
    int sandev_dur;
    char default_gov[32];
} RacoConfig;

extern RacoConfig config;

// Freq DataStruct
typedef struct {
    int index;
    long freq;
} FreqData;

// External Modules
void kobo_fast_charge();
void zetamin_optimize();
void exec_anya_melfissa();
void exec_anya_kawaii();

// Tool of raco_tool.c Declaration
void rawrite(const char *val, const char *path);
void rakakikomi(const char *val, const char *path);
int raread(const char *path, char *out_buffer, int max_size);
void raco_bulk(const char *base, const char **files, int count, const char *val, int is_kakikomi);

void load_config(const char *config_path);
void notification(const char *message);
void clear_slingshot();
void kill_all();
void anyamelfissa();
void anyakawaii();
int get_universal_fps(const char *pkg);

// Tool of Frequency
FreqData get_target_freq(const char *path, int mode); // 0=Max 1=Min 2=Mid
void set_devfreq(const char *path, const char *mode);
void devfreq_max(const char *path);
void devfreq_balanced(const char *path);
void devfreq_mid_perf(const char *path);
void devfreq_min_perf(const char *path);
void devfreq_release(const char *path);
void change_cpu_gov(const char *gov);
void cpufreq_awaken();
void cpufreq_balanced();
void cpufreq_normal();
void cpufreq_powersave();

// Raco Device Specific. raco_devices.c 
void mediatek_awaken();
void mediatek_normal();
void mediatek_powersave();
void mediatek_balanced();

void snapdragon_awaken();
void snapdragon_normal();
void snapdragon_powersave();
void snapdragon_balanced();

// Minor SOC
void scan_minor_devfreq_and_apply(const char *target, int mode);

void exynos_awaken();
void exynos_normal();
void exynos_powersave();
void exynos_balanced();

void unisoc_awaken();
void unisoc_normal();
void unisoc_powersave();
void unisoc_balanced();

void tensor_awaken();
void tensor_normal();
void tensor_powersave();
void tensor_balanced();

void tegra_awaken();
void tegra_normal();
void tegra_powersave();
void tegra_balanced();

#endif // RACO_H