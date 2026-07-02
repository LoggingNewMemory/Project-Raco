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
    } else if (strcmp (mode, "normal") == 0) {
        rakakikomi(v_min, min_p); rakakikomi(v_max, max_p);
    }
}

void devfreq_max(const char *path) { set_devfreq(path, "max"); }
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

// Essential: Reset limits to hardware bounds to prevent "write error: Invalid Argument"
void cpufreq_reset_limits() {
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                char path[256], min_path[256], max_path[256], info_path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpufreq/%s", ent->d_name);
                snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", path);
                snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", path);

                char hw_min_buf[32] = {0}, hw_max_buf[32] = {0};

                snprintf(info_path, sizeof(info_path), "%s/cpuinfo_min_freq", path);
                if (raread(info_path, hw_min_buf, sizeof(hw_min_buf)) <= 0) continue;

                snprintf(info_path, sizeof(info_path), "%s/cpuinfo_max_freq", path);
                if (raread(info_path, hw_max_buf, sizeof(hw_max_buf)) <= 0) continue;

                // Widen the window: Set min to lowest, max to highest
                rakakikomi(hw_min_buf, min_path);
                rakakikomi(hw_max_buf, max_path);
            }
        }
        closedir(dir);
    }
}

void cpufreq_awaken() {
    // 1. Reset limits first
    cpufreq_reset_limits();

    // 2. Apply Max Perf
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                char path[256], min_path[256], max_path[256], info_path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpufreq/%s", ent->d_name);
                snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", path);
                snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", path);

                char hw_max_buf[32] = {0};

                snprintf(info_path, sizeof(info_path), "%s/cpuinfo_max_freq", path);
                if (raread(info_path, hw_max_buf, sizeof(hw_max_buf)) <= 0) continue;

                rawrite(hw_max_buf, max_path);
                rawrite(hw_max_buf, min_path);
            }
        }
        closedir(dir);
    }
}

void cpufreq_balanced() {
    // Unlocking is just resetting limits and leaving them writable
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                char path[256], min_path[256], max_path[256], info_path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpufreq/%s", ent->d_name);
                snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", path);
                snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", path);

                char hw_min_buf[32] = {0}, hw_max_buf[32] = {0};

                snprintf(info_path, sizeof(info_path), "%s/cpuinfo_min_freq", path);
                if (raread(info_path, hw_min_buf, sizeof(hw_min_buf)) <= 0) continue;

                snprintf(info_path, sizeof(info_path), "%s/cpuinfo_max_freq", path);
                if (raread(info_path, hw_max_buf, sizeof(hw_max_buf)) <= 0) continue;

                rakakikomi(hw_min_buf, min_path);
                rakakikomi(hw_max_buf, max_path);
            }
        }
        closedir(dir);
    }
}

// Normal mode uses the same unlock behavior as balanced
void cpufreq_normal() {
    cpufreq_balanced();
}

void cpufreq_powersave() {
    // 1. Reset limits first
    cpufreq_reset_limits();

    // 2. Apply Min Perf
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                char path[256], min_path[256], max_path[256], info_path[256];
                snprintf(path, sizeof(path), "/sys/devices/system/cpu/cpufreq/%s", ent->d_name);
                snprintf(min_path, sizeof(min_path), "%s/scaling_min_freq", path);
                snprintf(max_path, sizeof(max_path), "%s/scaling_max_freq", path);

                char hw_min_buf[32] = {0};

                snprintf(info_path, sizeof(info_path), "%s/cpuinfo_min_freq", path);
                if (raread(info_path, hw_min_buf, sizeof(hw_min_buf)) <= 0) continue;

                rawrite(hw_min_buf, min_path);
                rawrite(hw_min_buf, max_path);
            }
        }
        closedir(dir);
    }
}