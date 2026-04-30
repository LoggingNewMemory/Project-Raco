#ifndef RACO_H
#define RACO_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>

// Call Assembly Functions
extern int raco_write (const char *path, const char *val, unsigned int len);
extern int raco_kakikomi (const char *path, const char *val, unsigned int len);
extern int raco_read (const char *path);

// Config Structure
typedef struct {
    int soc;
    int lite_mode; // Supposed I need to refine how I should put ts
    int better_powersave;
    int anya;
    int include_anya; // TODO: Refine Anya Implementation. It doesn't make any sense
    int kcpu_mitigate;
    int legacy_notif;
    int silent_notif;
    int device_mitigation;
    int dnd;
    char default_gov[32]; // This is due handler of custom GOV. Fk, why not stick to schedutil
} RacoConfig;

extern RacoConfig config;

// Freq DataStruct
typedef struct {
    int index;
    long freq;
} FreqData;

// Tool of raco_tool.c Declaration
void rawrite(const char *val, const char *path);
void rakakikomi(const char *val, const char *path);
void raread(const char *path);

void load_config(const char *config_path);
void notification(const char *message);
void dnd_on();
void dnd_off();
void clear_slingshot();
void kill_all();
void anyamelfissa();
void anyakawaii();

// Tool of Frequency
FreqData get_target_freq(const char *path, int mode); // 0=Max 1=Min 2=Mid
void set_devfreq(const char *path, const char *mode);
void devfreq_max_perf(const char *path);
void devfreq_mid_perf(const char *path);
void devfreq_min_perf(const char *path);
void devfreq_unlock(const char *path);
void change_cpu_gov(const char *gov);
void cpufreq_max_perf();
void cpufreq_min_perf();
void cpufreq_unlock();

// Raco Device Specific. raco_devices.c 
void mediatek_performance();
void mediatek_normal();
void mediatek_powersave();

void snapdragon_performance();
void snapdragon_normal();
void snapdragon_powersave();

void exynos_performance();
void exynos_normal();
void exynos_powersave();

void unisoc_performance();
void unisoc_normal();
void unisoc_powersave();

void tensor_performance();
void tensor_normal();
void tensor_powersave();

void tegra_performance();
void tegra_normal();
void tegra_powersave();

#endif // RACO_H