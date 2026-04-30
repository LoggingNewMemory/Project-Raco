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

    // Assembly usage of reading
    if (raread(path, file_content, sizeof(file_content)) <= 0) {
        return result; // Exit if empty
    }

    FreqData freqs[200];
    int count = 0;

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

    if (count == 0) return result;

    qsort(freqs, count, sizeof(FreqData), compare_freq_desc);

    if (mode == 0) return freqs[0]; // Maxfreq
    if (mode == 1) return freqs[count - 1]; // Minfreq
    if (mode == 2) return freqs[count / 2]; // Midfreq

    return result;
}

// Config Utilities

void load_config(const char *config_path) {
    // Set DEFAULTS
    config.soc = 0;
    config.anya = 0;
    config.include_anya = 0;
    config.legacy_notif = 0;
    config.silent_notif = 0;
    config.device_mitigation = 0;
    config.dnd = 0;
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
            else if (strcmp(key, "INCLUDE_ANYA") == 0 && parsed == 2) config.include_anya = atol(value);
            else if (strcmp(key, "LEGACY_NOTIF") == 0 && parsed == 2) config.legacy_notif = atol(value);
            else if (strcmp(key, "SILENT_NOTIF") == 0 && parsed == 2) config.silent_notif = atol(value);
            else if (strcmp(key, "DEVICE_MITIGATION") == 0 && parsed == 2) config.device_mitigation = atol(value);
            else if (strcmp(key, "DND") == 0 && parsed == 2) config.dnd = atol(value);
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
        if (config.legacy_notif == 1) {
            snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t 'Project Raco' TagRaco '%s'\" &", message);
        } else {
            snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t 'Project Raco' -i file:///data/local/tmp/logo.png TagRaco '%s'\" &", message);
        }
        system(cmd);
    }
}

void dnd_on() { if (config.dnd == 1) system("cmd notification set_dnd priority &"); }
void dnd_off() { if (config.dnd == 1) system("cmd notification set_dnd off &"); }

void clear_slingshot() {
    system("settings delete global angle_debug_package");
    system("settings delete global angle_gl_driver_all_angle");
    system("setprop debug.hwui.renderer none");
}

void anyamelfissa() {
    if (config.include_anya == 1 && config.anya == 1) {
    system("su -c /data/adb/modules/ProjectRaco/CoreSys/anya 1");
    }
}

void anyakawaii() {
    if (config.include_anya == 1 && config.anya == 1) {
    system("su -c /data/adb/modules/ProjectRaco/CoreSys/anya 0");
    }
}

void kill_all() {
    system("sync");
    system("cmd activity kill-all > /dev/null 2>&1");
    system("pm list packages -3 | cut -f 2 -d ':' | grep -v 'com.google.android.inputmethod.latin' | xargs -n1 am force-stop > /dev/null 2>&1 &");
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
        rawrite(v_max, min_p); rawrite(v_max, max_p);
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
void devfreq_release(const char *path) { set_devfreq(path, "release"); }

void change_cpu_gov(const char *gov) {
    DIR *dir;
    struct dirent *ent;
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

void cpufreq_awaken() {
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                char hw_max_path[256], min_path[256], max_path[256];
                snprintf(hw_max_path, sizeof(hw_max_path), "/sys/devices/system/cpu/cpufreq/%s/cpuinfo_max_freq", ent->d_name);
                snprintf(min_path, sizeof(min_path), "/sys/devices/system/cpu/cpufreq/%s/scaling_min_freq", ent->d_name);
                snprintf(max_path, sizeof(max_path), "/sys/devices/system/cpu/cpufreq/%s/scaling_max_freq", ent->d_name);
                
                char hw_max_val[32] = {0};

                if (raread(hw_max_path, hw_max_val, sizeof(hw_max_val)) > 0) {
                    hw_max_val[strcspn(hw_max_val, "\n")] = 0; // Clean up

                    rawrite(hw_max_val, min_path);
                    rawrite(hw_max_val, max_path);
                } 
            }
        }
        closedir(dir);
    }
}

void cpufreq_balanced() {
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                char avail_path[256], hw_max_path[256], min_path[256], max_path[256];
                snprintf(avail_path, sizeof(avail_path), "/sys/devices/system/cpu/cpufreq/%s/scaling_available_frequencies", ent->d_name);
                snprintf(hw_max_path, sizeof(hw_max_path), "/sys/devices/system/cpu/cpufreq/%s/cpuinfo_max_freq", ent->d_name);
                snprintf(min_path, sizeof(min_path), "/sys/devices/system/cpu/cpufreq/%s/scaling_min_freq", ent->d_name);
                snprintf(max_path, sizeof(max_path), "/sys/devices/system/cpu/cpufreq/%s/scaling_max_freq", ent->d_name);
                
                FreqData mid_f = get_target_freq(avail_path, 2);

                char hw_max_val[32] = {0};

                if (mid_f.freq != -1 && raread(hw_max_path, hw_max_val, sizeof(hw_max_val)) > 0) {
                    hw_max_val[strcspn(hw_max_val, "\n")] = 0; // Clean up

                    char mid_val[32];
                    snprintf(mid_val, sizeof(mid_val), "%ld", mid_f.freq);

                    rawrite(mid_val, min_path);
                    rawrite(hw_max_val, max_path);
                }
            }
        }
        closedir(dir);
    }
}

void cpufreq_normal() {
    DIR *dir;
    struct dirent *ent;
    if ((dir = opendir ("/sys/devices/system/cpu/cpufreq")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (strncmp(ent->d_name, "policy", 6) == 0) {
                char hw_min_path[256], hw_max_path[256], min_path[256], max_path[256];
                snprintf(hw_min_path, sizeof(hw_min_path), "/sys/devices/system/cpu/cpufreq/%s/cpuinfo_min_freq", ent->d_name);
                snprintf(hw_max_path, sizeof(hw_max_path), "/sys/devices/system/cpu/cpufreq/%s/cpuinfo_max_freq", ent->d_name);
                snprintf(min_path, sizeof(min_path), "/sys/devices/system/cpu/cpufreq/%s/scaling_min_freq", ent->d_name);
                snprintf(max_path, sizeof(max_path), "/sys/devices/system/cpu/cpufreq/%s/scaling_max_freq", ent->d_name);
                
                char hw_min_val[32] = {0};
                char hw_max_val[32] = {0};

                if (raread(hw_min_path, hw_min_val, sizeof(hw_min_val)) > 0 &&
                    raread(hw_max_path, hw_max_val, sizeof(hw_max_val)) >0) {
                    
                    // Clear
                    hw_min_val[strcspn(hw_min_val, "\n")] = 0;
                    hw_max_val[strcspn(hw_max_val, "\n")] = 0; 
                    
                    rakakikomi(hw_min_val, min_path);
                    rakakikomi(hw_max_val, max_path);
                } 
            }
        }
        closedir(dir);
    }
}