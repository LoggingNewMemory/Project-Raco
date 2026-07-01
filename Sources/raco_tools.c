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
            else if (strcmp(key, "GOV") == 0 && parsed == 2) strcpy(config.default_gov, value);
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
    if (config.silent_notif == 1) {
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"am startservice -n com.kanagawa.yamada.project.raco/.ToastOverlayService --es msg '%s'\" >/dev/null 2>&1 &", message);
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
    system("sync");
    system("cmd activity kill-all > /dev/null 2>&1");
    system("pm trim-caches 100G > /dev/null 2>&1");
    rawrite("3", "/proc/sys/vm/drop_caches");
    system("logcat -b all -c");
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
    } else if (strcmp (mode, "release") == 0) {
        rakakikomi(v_min, min_p); rakakikomi(v_max, max_p);
    }
}

void devfreq_max(const char *path) { set_devfreq(path, "max"); }
void devfreq_balanced(const char *path) { set_devfreq(path, "mid"); }
void devfreq_mid_perf(const char *path) { set_devfreq(path, "mid"); }
void devfreq_release(const char *path) { set_devfreq(path, "release"); }
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

void get_clamped_freqs(const char *cpu_dir, long *out_max, long *out_min, long *out_mid, long *out_mid_low) {
    char path[256];
    char hw_min_buf[32] = {0}, hw_max_buf[32] = {0};
    long hw_min = -1, hw_max = -1;

    snprintf(path, sizeof(path), "%s/cpuinfo_min_freq", cpu_dir);
    if (raread(path, hw_min_buf, sizeof(hw_min_buf)) > 0) hw_min = atol(hw_min_buf);

    snprintf(path, sizeof(path), "%s/cpuinfo_max_freq", cpu_dir);
    if (raread(path, hw_max_buf, sizeof(hw_max_buf)) > 0) hw_max = atol(hw_max_buf);

    snprintf(path, sizeof(path), "%s/scaling_available_frequencies", cpu_dir);
    if (access(path, F_OK) != 0) {
        snprintf(path, sizeof(path), "%s/stats/time_in_state", cpu_dir);
    }

    FreqData f_max = get_target_freq(path, 0);
    FreqData f_min = get_target_freq(path, 1);
    FreqData f_mid = get_target_freq(path, 2);
    FreqData f_mid_low = get_target_freq(path, 3);

    long t_max = f_max.freq;
    long t_min = f_min.freq;
    long t_mid = f_mid.freq;
    long t_mid_low = f_mid_low.freq;

    if (hw_max > 0) {
        if (t_max > hw_max) t_max = hw_max;
        if (t_min > hw_max) t_min = hw_max;
        if (t_mid > hw_max) t_mid = hw_max;
        if (t_mid_low > hw_max) t_mid_low = hw_max;
    }
    if (hw_min > 0) {
        if (t_max > 0 && t_max < hw_min) t_max = hw_min;
        if (t_min > 0 && t_min < hw_min) t_min = hw_min;
        if (t_mid > 0 && t_mid < hw_min) t_mid = hw_min;
        if (t_mid_low > 0 && t_mid_low < hw_min) t_mid_low = hw_min;
    }

    if (out_max) *out_max = t_max > 0 ? t_max : hw_max;
    if (out_min) *out_min = t_min > 0 ? t_min : hw_min;
    if (out_mid) *out_mid = t_mid > 0 ? t_mid : hw_max;
    if (out_mid_low) *out_mid_low = t_mid_low > 0 ? t_mid_low : hw_min;
}

void set_cpufreq(const char *mode) {
    DIR *dir;
    struct dirent *ent;
    const char *base_paths[] = {"/sys/devices/system/cpu", "/sys/devices/system/cpu/cpufreq"};

    for (int i = 0; i < 2; i++) {
        if ((dir = opendir(base_paths[i])) != NULL) {
            while ((ent = readdir(dir)) != NULL) {
                int is_cpu = (i == 0 && strncmp(ent->d_name, "cpu", 3) == 0 && ent->d_name[3] >= '0' && ent->d_name[3] <= '9');
                int is_policy = (i == 1 && strncmp(ent->d_name, "policy", 6) == 0);
                
                if (is_cpu || is_policy) {
                    char cpu_dir[256], min_path[256], max_path[256];
                    if (is_cpu) {
                        snprintf(cpu_dir, sizeof(cpu_dir), "/sys/devices/system/cpu/%s/cpufreq", ent->d_name);
                    } else {
                        snprintf(cpu_dir, sizeof(cpu_dir), "/sys/devices/system/cpu/cpufreq/%s", ent->d_name);
                    }
                    
                    snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", cpu_dir);
                    snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", cpu_dir);

                    long hw_min = -1, hw_max = -1;
                    char hw_min_buf[32] = {0}, hw_max_buf[32] = {0};
                    char path_buf[256];
                    
                    snprintf(path_buf, sizeof(path_buf), "%s/cpuinfo_min_freq", cpu_dir);
                    if (raread(path_buf, hw_min_buf, sizeof(hw_min_buf)) > 0) hw_min = atol(hw_min_buf);
                    
                    snprintf(path_buf, sizeof(path_buf), "%s/cpuinfo_max_freq", cpu_dir);
                    if (raread(path_buf, hw_max_buf, sizeof(hw_max_buf)) > 0) hw_max = atol(hw_max_buf);

                    if (hw_min > 0 && hw_max > 0) {
                        // ALWAYS lower min first before raising max to avoid boundary errors
                        rawrite(hw_min_buf, min_path);
                        rawrite(hw_max_buf, max_path);
                    }

                    if (strcmp(mode, "reset") == 0) continue;

                    long t_max, t_min, t_mid, t_mid_low;
                    get_clamped_freqs(cpu_dir, &t_max, &t_min, &t_mid, &t_mid_low);

                    if (t_max <= 0 || t_min <= 0) continue;

                    char val1[32], val2[32];
                    
                    if (strcmp(mode, "awaken") == 0) {
                        snprintf(val1, sizeof(val1), "%ld", t_max);
                        rawrite(val1, max_path); // Max first, then min (raising range)
                        rawrite(val1, min_path);
                    } else if (strcmp(mode, "balanced") == 0) {
                        snprintf(val1, sizeof(val1), "%ld", t_max);
                        snprintf(val2, sizeof(val2), "%ld", t_mid);
                        rawrite(val1, max_path); // Max first, then min
                        rawrite(val2, min_path);
                    } else if (strcmp(mode, "normal") == 0) {
                        snprintf(val1, sizeof(val1), "%ld", t_max);
                        snprintf(val2, sizeof(val2), "%ld", t_min);
                        rakakikomi(val2, min_path); // Min first, then max (lowering range or normal limits)
                        rakakikomi(val1, max_path);
                    } else if (strcmp(mode, "powersave") == 0) {
                        snprintf(val1, sizeof(val1), "%ld", t_min);
                        snprintf(val2, sizeof(val2), "%ld", t_mid_low);
                        rawrite(val1, min_path); // Min first, then max (lowering range)
                        rawrite(val2, max_path);
                    }
                }
            }
            closedir(dir);
        }
    }
}

void cpufreq_reset_limits() { set_cpufreq("reset"); }
void cpufreq_awaken() { set_cpufreq("awaken"); }
void cpufreq_balanced() { set_cpufreq("balanced"); }
void cpufreq_normal() { set_cpufreq("normal"); }
void cpufreq_powersave() { set_cpufreq("powersave"); }