/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
 */

#include "raco.h"

RacoConfig config;
const char *RACO_CONFIG = "/data/ProjectRaco/raco.txt";

// The Assembly Wrappers

void rawrite(const char *val, const char *path) {
    raco_write(path, val, strlen(val));
}


void rakakikomi(const char *val, const char *path) {
    raco_kakikomi(path, val, strlen(val));
}

int raread(const char *path, char *out_buffer, int max_size) {
    int bytes_read = raco_read(path, out_buffer, max_size);

    // Add Null Terminator so C knows where string ends
    if (bytes_read > 0 && bytes_read < max_size) {
        out_buffer[bytes_read] = '\0';
    } else if (bytes_read == max_size) {
        out_buffer[max_size - 1] = '\0';
    } else {
        out_buffer[0] = '\0'; // Return empty if error
    }

    // Strip trailing newline
    if (bytes_read > 0) {
        int last_char_idx = (bytes_read == max_size) ? max_size - 2 : bytes_read - 1;
        if (last_char_idx >= 0 && out_buffer[last_char_idx] == '\n') {
            out_buffer[last_char_idx] = '\0';
        }
    }

    return bytes_read;
}


/*
Bulk Writer, Why? Either I'm smart to not write one by one path and value
Or I'm lazy because I don't want to write one by one path and value
*/
void raco_bulk(const char *base, const char **files, int count, const char *val, int is_kakikomi) {
    if (!base || !files || count <= 0 || !val) return;

    size_t base_len = strlen(base);
    int needs_slash = (base_len > 0 && base[base_len - 1] != '/');

    char path[512];
    for (int i = 0; i < count; i++) {
        if (!files[i]) continue;
        if (needs_slash) {
            snprintf(path, sizeof(path), "%s/%s", base, files[i]);
        } else {
            snprintf(path, sizeof(path), "%s%s", base, files[i]);
        }

        if (is_kakikomi) {
            rakakikomi(val, path);
        } else {
            rawrite(val, path);
        }
    }
}

// FREQ Parser & Quick Sort

int compare_freq_desc (const void *a, const void *b) {
    FreqData *fa = (FreqData *)a;
    FreqData *fb = (FreqData *)b;

    if (fb->freq > fa->freq) return 1;
    if (fb->freq < fa->freq) return -1;
    return 0;
}

FreqData get_target_freq(const char *path, int mode) {
    FreqData result = {-1, -1};
    char file_content[4096];

    if (raread(path, file_content, sizeof(file_content)) <= 0) {
        return result;
    }

    FreqData freqs[200];
    int count = 0;

    if (strstr(path, "time_in_state")) {
        char *saveptr_line;
        char *line = strtok_r(file_content, "\n", &saveptr_line);
        while (line != NULL && count < 200) {
            long frq = 0;
            if (sscanf(line, "%ld", &frq) == 1 && frq > 0) {
                freqs[count].index = count;
                freqs[count].freq = frq;
                count++;
            }
            line = strtok_r(NULL, "\n", &saveptr_line);
        }
    } else {
        char *saveptr_token;
        char *token = strtok_r(file_content, " \t\n", &saveptr_token);
        while (token != NULL && count < 200) {
            long frq = atol(token);
            if (frq > 0) {
                freqs[count].index = count;
                freqs[count].freq = frq;
                count++;
            }
            token = strtok_r(NULL, " \t\n", &saveptr_token);
        }
    }

    if (count == 0) return result;

    qsort(freqs, count, sizeof(FreqData), compare_freq_desc);

    if (mode == 0) return freqs[0]; // Maxfreq
    if (mode == 1) return freqs[count - 1]; // Minfreq
    if (mode == 2) return freqs[count / 2]; // Midfreq
    if (mode == 3) {
        if (count > 2) return freqs[2]; // 3rd highest
        else return freqs[count - 1]; // Fallback
    }

    return result;
}

// Config Utilities

void load_config(const char *config_path) {
    // Set DEFAULTS
    config.soc = 0;
    config.anya = 0;
    config.legacy_notif = 0;
    config.silent_notif = 0;
    config.device_mitigation = 0;
    config.inc_kobo = 0;
    config.inc_zeta = 0;
    config.inc_sandev = 0;
    config.sandev_dur = 300;
    config.lite_powersave = 0;
    config.ultra_powersave = 0;
    config.lite_performance = 0;
    config.alter_cpu_method = 0;
    strcpy(config.default_gov, "schedutil");

    char file_content[4096];
    if (raread(config_path, file_content, sizeof(file_content)) <= 0) {
        printf("Error: Fail to read config file at %s\n", config_path);
        exit(1);
    }

    char *saveptr_line;
    char *line = strtok_r(file_content, "\n", &saveptr_line);

    while (line != NULL) {
        char key[128] = {0};
        char value[128] = {0};

        int parsed = sscanf(line, "%127s %127s", key, value);

        if (parsed >= 1) {
            if (strcmp(key, "SOC") == 0 && parsed == 2) config.soc = atol(value);
            else if (strcmp(key, "ANYA") == 0 && parsed == 2) config.anya = atol(value);
            else if (strcmp(key, "LEGACY_NOTIF") == 0 && parsed == 2) config.legacy_notif = atol(value);
            else if (strcmp(key, "SILENT_NOTIF") == 0 && parsed == 2) config.silent_notif = atol(value);
            else if (strcmp(key, "DEVICE_MITIGATION") == 0 && parsed == 2) config.device_mitigation = atol(value);
            else if (strcmp(key, "INCLUDE_KOBO") == 0 && parsed == 2) config.inc_kobo = atoi(value);
            else if (strcmp(key, "INCLUDE_ZETAMIN") == 0 && parsed == 2) config.inc_zeta = atoi(value);
            else if (strcmp(key, "INCLUDE_SANDEV") == 0 && parsed == 2) config.inc_sandev = atoi(value);
            else if (strcmp(key, "SANDEV_DUR") == 0 && parsed == 2) config.sandev_dur = atoi(value);
            else if (strcmp(key, "LITE_POWERSAVE") == 0 && parsed == 2) config.lite_powersave = atoi(value);
            else if (strcmp(key, "ULTRA_POWERSAVE") == 0 && parsed == 2) config.ultra_powersave = atoi(value);
            else if (strcmp(key, "LITE_PERFORMANCE") == 0 && parsed == 2) config.lite_performance = atoi(value);
            else if (strcmp(key, "GOV") == 0 && parsed == 2) strcpy(config.default_gov, value);
            else if (strcmp(key, "ALTER_CPU_METHOD") == 0 && parsed == 2) config.alter_cpu_method = atoi(value);
        }
        line = strtok_r(NULL, "\n", &saveptr_line);
    }

    if (config.soc < 1 || config.soc > 6) {
        printf("SOC Key is NULL, Exiting...");
        exit(1);
    }
}

// Basic Utilities
void notification(const char *message) {
    if (config.silent_notif == 0) {
        char cmd[1024];
        if (config.legacy_notif == 1) {
            snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t 'Project Raco' 'TagRaco' '%s'\" &", message);
        } else {
            snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t 'Project Raco' -i file:///data/local/tmp/logo.png -I file:///data/local/tmp/logo.png 'TagRaco' '%s'\" &", message);
        }
        system(cmd);
    }
}

void clear_slingshot() {
    system("settings delete global angle_debug_package");
    system("settings delete global angle_gl_driver_all_angle");
    system("setprop debug.hwui.renderer \"\"");
}

#ifndef STANDALONE
void anyamelfissa() {
    if (config.anya == 1) {
        exec_anya_melfissa();
    }
}

void anyakawaii() {
    if (config.anya == 1) {
        exec_anya_kawaii();
    }
}
#endif

void kill_all() {
    system("sync; "
           "cmd activity kill-all > /dev/null 2>&1; "
           "for pkg in $(pm list packages -3 | cut -f 2 -d ':'); do "
           "if [ \"$pkg\" != \"com.google.android.inputmethod.latin\" ]; then "
           "am force-stop \"$pkg\" > /dev/null 2>&1 & "
           "fi; done; wait; "
           "pm trim-caches 100G > /dev/null 2>&1; "
           "logcat -c; "
           "logcat -b all -c");
    rawrite("3", "/proc/sys/vm/drop_caches");
}

void run_fstrim() {
    system("busybox fstrim -v /data >/dev/null 2>&1");
    usleep(100000);
    system("busybox fstrim -v /cache >/dev/null 2>&1");
}

void clear_cache() {
    system("for DIR in /data/data/*; do if [ -d \"${DIR}\" ]; then rm -rf ${DIR}/cache/* ${DIR}/no_backup/* ${DIR}/app_webview/* ${DIR}/code_cache/*; fi; done >/dev/null 2>&1; "
           "find /data/data/*/cache/* -delete 2>/dev/null; "
           "find /data/data/*/code_cache/* -delete 2>/dev/null; "
           "find /data/user_de/*/*/cache/* -delete 2>/dev/null; "
           "find /data/user_de/*/*/code_cache/* -delete 2>/dev/null; "
           "find /sdcard/Android/data/*/cache/* -delete 2>/dev/null; "
           "pm trim-caches 1024G >/dev/null 2>&1; "
           "cmd stats clear-puller-cache >/dev/null 2>&1; "
           "cmd activity clear-debug-app >/dev/null 2>&1; "
           "cmd activity clear-watch-heap -a >/dev/null 2>&1; "
           "cmd activity clear-exit-info >/dev/null 2>&1; "
           "cmd content reset-today-stats >/dev/null 2>&1; "
           "cmd companiondevice refresh-cache >/dev/null 2>&1; "
           "cmd companiondevice remove-inactive-associations >/dev/null 2>&1; "
           "cmd blob_store clear-all-blobs >/dev/null 2>&1; "
           "cmd blob_store clear-all-sessions >/dev/null 2>&1; "
           "cmd device_policy clear-freeze-period-record >/dev/null 2>&1; "
           "wm tracing size 0 >/dev/null 2>&1; "
           "cmd font clear >/dev/null 2>&1; "
           "cmd location_time_zone_manager clear_recorded_provider_states >/dev/null 2>&1; "
           "cmd lock_settings remove-cache >/dev/null 2>&1; "
           "cmd media.camera clear-stream-use-case-override >/dev/null 2>&1; "
           "cmd media.camera watch clear >/dev/null 2>&1; "
           "cmd safety_center clear-data >/dev/null 2>&1; "
           "cmd time_detector clear_network_time >/dev/null 2>&1; "
           "cmd time_detector clear_system_clock_network_time >/dev/null 2>&1; "
           "dumpsys procstats --clear >/dev/null 2>&1; "
           "cmd package art cleanup >/dev/null 2>&1");
}

// Frequency Control (Devfreq)

void set_devfreq(const char *path, const char *mode) {
    char avail[256], min_p[256], max_p[256];

    snprintf(avail, sizeof(avail), "%s/available_frequencies", path);
    snprintf(min_p, sizeof(min_p), "%s/min_freq", path);
    snprintf(max_p, sizeof(max_p), "%s/max_freq", path);

    FreqData f_max = get_target_freq(avail, 0);
    FreqData f_min = get_target_freq(avail, 1);
    FreqData f_mid = get_target_freq(avail, 2);

    if (f_max.freq == -1) return;

    char v_max[32], v_min[32], v_mid[32];
    snprintf(v_max, sizeof(v_max), "%ld", f_max.freq);
    snprintf(v_min, sizeof(v_min), "%ld", f_min.freq);
    snprintf(v_mid, sizeof(v_mid), "%ld", f_mid.freq);

    if (strcmp(mode, "max") == 0) {
        rawrite(v_max, max_p); rawrite(v_max, min_p);
    } else if (strcmp(mode, "mid") == 0) {
        rawrite(v_max, max_p); rawrite(v_mid, min_p);
    } else if (strcmp(mode, "min") == 0) {
        rawrite(v_min, min_p); rawrite(v_min, max_p);
    } else if (strcmp (mode, "normal") == 0) {
        rakakikomi(v_min, min_p); rakakikomi(v_max, max_p);
    }
}

void devfreq_max(const char *path) { 
    if (config.lite_performance == 1) set_devfreq(path, "mid");
    else set_devfreq(path, "max"); 
}
void devfreq_balanced(const char *path) { set_devfreq(path, "mid"); }
void devfreq_mid_perf(const char *path) { set_devfreq(path, "mid"); }
void devfreq_normal(const char *path) { set_devfreq(path, "normal"); }
void devfreq_min_perf(const char *path) { set_devfreq(path, "min"); }

void change_cpu_gov(const char *gov) {
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir("/sys/devices/system/cpu")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "cpu", 3) == 0 && ent->d_name[3] >= '0' && ent->d_name[3] <= '9') {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/%s/cpufreq/scaling_governor", ent->d_name);
                rawrite(gov, path);
            }
        }
        closedir(dir);
    }
    if ((dir = opendir("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpufreq/%s/scaling_governor", ent->d_name);
                rawrite(gov, path);
            }
        }
        closedir(dir);
    }
}

// Frequency Control (CPUFreq)
// 1:1 replicate of 5.0 method


void cpufreq_awaken() {
    if (config.alter_cpu_method == 1) return;
    
    // 2. Apply Max Perf
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                const char *cpu_idx = ent->d_name + 6;
                char path[256], min_path[256], max_path[256], info_path[256], avail_path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpufreq/%s", ent->d_name);
                snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", path);
                snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", path);
                snprintf(avail_path, sizeof(avail_path), "/sys/devices/system/cpu/cpu%s/cpufreq/scaling_available_frequencies", cpu_idx);

                char hw_max_buf[32] = {0};

                snprintf(info_path, sizeof(info_path), "/sys/devices/system/cpu/cpu%s/cpufreq/cpuinfo_max_freq", cpu_idx);
                if (raread(info_path, hw_max_buf, sizeof(hw_max_buf)) <= 0) continue;

                if (config.lite_performance == 1) {
                    FreqData mid_f = get_target_freq(avail_path, 2);
                    if (mid_f.freq != -1) {
                        char mid_val[32];
                        snprintf(mid_val, sizeof(mid_val), "%ld", mid_f.freq);
                        rawrite(hw_max_buf, max_path);
                        rawrite(mid_val, min_path);
                    } else {
                        rawrite(hw_max_buf, max_path);
                        rawrite(hw_max_buf, min_path);
                    }
                } else {
                    rawrite(hw_max_buf, max_path);
                    rawrite(hw_max_buf, min_path);
                }
            }
        }
        closedir(dir);
    }
}

void cpufreq_balanced() {
    if (config.alter_cpu_method == 1) return;
    
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                const char *cpu_idx = ent->d_name + 6;
                char path[256], avail_path[256], info_path[256], min_path[256], max_path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpufreq/%s", ent->d_name);
                snprintf(avail_path, sizeof(avail_path), "/sys/devices/system/cpu/cpu%s/cpufreq/scaling_available_frequencies", cpu_idx);
                snprintf(info_path, sizeof(info_path), "/sys/devices/system/cpu/cpu%s/cpufreq/cpuinfo_max_freq", cpu_idx);
                snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", path);
                snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", path);

                FreqData mid_f = get_target_freq(avail_path, 2);

                char hw_max_buf[32] = {0};

                if (mid_f.freq != -1 && raread(info_path, hw_max_buf, sizeof(hw_max_buf)) > 0) {
                    char mid_val[32];
                    snprintf(mid_val, sizeof(mid_val), "%ld", mid_f.freq);

                    rakakikomi(mid_val, min_path);
                    rakakikomi(hw_max_buf, max_path);
                }
            }
        }
        closedir(dir);
    }
}

void cpufreq_normal() {
    if (config.alter_cpu_method == 1) return;
    
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                const char *cpu_idx = ent->d_name + 6;
                char path[256], min_info[256], max_info[256], min_path[256], max_path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpufreq/%s", ent->d_name);
                snprintf(min_info, sizeof(min_info), "/sys/devices/system/cpu/cpu%s/cpufreq/cpuinfo_min_freq", cpu_idx);
                snprintf(max_info, sizeof(max_info), "/sys/devices/system/cpu/cpu%s/cpufreq/cpuinfo_max_freq", cpu_idx);
                snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", path);
                snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", path);

                char hw_min_buf[32] = {0};
                char hw_max_buf[32] = {0};

                if (raread(min_info, hw_min_buf, sizeof(hw_min_buf)) > 0 && raread(max_info, hw_max_buf, sizeof(hw_max_buf)) > 0) {
                    rakakikomi(hw_min_buf, min_path);
                    rakakikomi(hw_max_buf, max_path);
                }
            }
        }
        closedir(dir);
    }
}

void cpufreq_powersave() {
    if (config.alter_cpu_method == 1) return;
    
    // 2. Apply Min Perf
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                const char *cpu_idx = ent->d_name + 6;
                char path[256], avail_path[256], info_path[256], min_path[256], max_path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpufreq/%s", ent->d_name);
                snprintf(avail_path, sizeof(avail_path), "/sys/devices/system/cpu/cpu%s/cpufreq/scaling_available_frequencies", cpu_idx);
                snprintf(info_path, sizeof(info_path), "/sys/devices/system/cpu/cpu%s/cpufreq/cpuinfo_min_freq", cpu_idx);
                snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", path);
                snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", path);

                char hw_min_buf[32] = {0};

                if (config.ultra_powersave == 1) {
                    if (raread(info_path, hw_min_buf, sizeof(hw_min_buf)) > 0) {
                        rawrite(hw_min_buf, min_path);
                        rawrite(hw_min_buf, max_path);
                    }
                } else if (config.lite_powersave == 1) {
                    FreqData mid_f = get_target_freq(avail_path, 2);
                    if (mid_f.freq != -1 && raread(info_path, hw_min_buf, sizeof(hw_min_buf)) > 0) {
                        char mid_val[32];
                        snprintf(mid_val, sizeof(mid_val), "%ld", mid_f.freq);
                        rawrite(hw_min_buf, min_path);
                        rawrite(mid_val, max_path);
                    }
                } else {
                    FreqData mid_f = get_target_freq(avail_path, 3);
                    if (mid_f.freq != -1 && raread(info_path, hw_min_buf, sizeof(hw_min_buf)) > 0) {
                        char mid_val[32];
                        snprintf(mid_val, sizeof(mid_val), "%ld", mid_f.freq);
                        rawrite(hw_min_buf, min_path);
                        rawrite(mid_val, max_path);
                    }
                }
            }
        }
        closedir(dir);
    }
}