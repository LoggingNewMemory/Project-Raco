/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
 */

#include "raco.h"

// Generic IO Tweaks
void apply_io_tweaks(const char *iostats, const char *add_random, const char *read_ahead_kb, const char *nr_requests, int lock) {
    DIR *dir; struct dirent *ent;
    if ((dir = opendir("/sys/block")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (ent->d_name[0] != '.' && strncmp(ent->d_name, "loop", 4) != 0) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/block/%s/queue/iostats", ent->d_name);
                lock ? rawrite(iostats, path) : rakakikomi(iostats, path);
                
                snprintf(path, sizeof(path), "/sys/block/%s/queue/add_random", ent->d_name);
                lock ? rawrite(add_random, path) : rakakikomi(add_random, path);
                
                snprintf(path, sizeof(path), "/sys/block/%s/queue/read_ahead_kb", ent->d_name);
                lock ? rawrite(read_ahead_kb, path) : rakakikomi(read_ahead_kb, path);
                
                snprintf(path, sizeof(path), "/sys/block/%s/queue/nr_requests", ent->d_name);
                lock ? rawrite(nr_requests, path) : rakakikomi(nr_requests, path);
            }
        }
        closedir(dir);
    }
}

// Generic Network Tweaks
void apply_net_tweaks(const char *low_lat, const char *ecn, const char *fastopen, const char *timestamps, int lock) {
    const char *base = "/proc/sys/net/ipv4";
    char p[256];
    snprintf(p, sizeof(p), "%s/tcp_low_latency", base); lock ? rawrite(low_lat, p) : rakakikomi(low_lat, p);
    snprintf(p, sizeof(p), "%s/tcp_ecn", base); lock ? rawrite(ecn, p): rakakikomi (ecn, p);
    snprintf(p, sizeof(p), "%s/tcp_fastopen", base); lock ? rawrite(fastopen, p): rakakikomi (fastopen, p);
    snprintf(p, sizeof(p), "%s/tcp_timestamps", base); lock ? rawrite(timestamps, p): rakakikomi (timestamps, p);
}

// Routing of SOCs
void route_soc(int mode) {
    // 4 = Awaken, 3 = Balanced, 2 = Powersave, 1 = Normal
    switch(config.soc) {
        case 1: // Mediatek
            if (mode == 4) mediatek_awaken(); else if(mode == 3) mediatek_balanced();
            else if (mode == 2) mediatek_powersave(); else if (mode == 1) mediatek_normal(); break;
        case 2: // Snapdragon
            if (mode == 4) snapdragon_awaken(); else if(mode == 3) snapdragon_balanced();
            else if (mode == 2) snapdragon_powersave(); else if (mode == 1) snapdragon_normal(); break;
        case 3: // Exynos
            if (mode == 4) exynos_awaken(); else if(mode == 3) exynos_balanced();
            else if (mode == 2) exynos_powersave(); else if (mode == 1) exynos_normal(); break;
        case 4: // UniSoc
            if (mode == 4) unisoc_awaken(); else if(mode == 3) unisoc_balanced();
            else if (mode == 2) unisoc_powersave(); else if (mode == 1) unisoc_normal(); break;
        case 5: // Tensor
            if (mode == 4) tensor_awaken(); else if(mode == 3) tensor_balanced();
            else if (mode == 2) tensor_powersave(); else if (mode == 1) tensor_normal(); break;
        case 6: // Tegra
            if (mode == 4) tegra_awaken(); else if(mode == 3) tegra_balanced();
            else if (mode == 2) tegra_powersave(); else if (mode == 1) tegra_normal(); break;
    }
}

// Master Profiles
void mode_awaken() {
    system("sync");

    apply_io_tweaks("0", "0", "32", "32", 1);
    apply_net_tweaks("1", "1", "3", "0", 1);
    rawrite("0", "/proc/sys/kernel/split_lock_mitigate");
    rawrite("0", "/proc/sys/vm/page-cluster");
    rawrite("80", "/proc/sys/vm/vfs_cache_pressure");

    change_cpu_gov("performance");
    cpufreq_awaken();
    route_soc(4);

    dnd_on();
    clear_slingshot();
    anyamelfissa();
    notification("Awaken Mode Activated");
}

void mode_balanced() {
    system("sync");

    apply_io_tweaks("1", "1", "128", "128", 0);
    apply_net_tweaks("0", "2", "1", "1", 0);
    rakakikomi("1", "/proc/sys/kernel/split_lock_mitigate");
    rakakikomi("3", "/proc/sys/vm/page-cluster");
    rakakikomi("120", "/proc/sys/vm/vfs_cache_pressure");

    change_cpu_gov(config.default_gov);
    cpufreq_balanced();
    route_soc(3);

    dnd_off();
    clear_slingshot();
    anyakawaii();
    notification("Balanced Mode Activated");
}

void mode_powersave() {
    system("sync");

    apply_io_tweaks("1", "1", "128", "128", 0);
    apply_net_tweaks("0", "2", "1", "1", 0);
    rakakikomi("1", "/proc/sys/kernel/split_lock_mitigate");
    rakakikomi("3", "/proc/sys/vm/page-cluster");
    rakakikomi("100", "/proc/sys/vm/vfs_cache_pressure");

    change_cpu_gov("powersave");
    cpufreq_powersave();
    route_soc(2);

    dnd_off();
    clear_slingshot();
    anyakawaii();
    notification("Powersave Mode Activated");
}

void mode_normal() {
    system("sync");

    apply_io_tweaks("1", "1", "128", "128", 0);
    apply_net_tweaks("0", "2", "1", "1", 0);
    rakakikomi("1", "/proc/sys/kernel/split_lock_mitigate");
    rakakikomi("3", "/proc/sys/vm/page-cluster");
    rakakikomi("120", "/proc/sys/vm/vfs_cache_pressure");

    change_cpu_gov(config.default_gov);
    cpufreq_normal();
    route_soc(1);

    dnd_off();
    clear_slingshot();
    anyakawaii();
    notification("Normal State Activated");
}

// Main Execution

int main(int argc, char *argv[]) {
    if (argc < 2) {
        return 1;
    }

    int mode = atoi(argv[1]);

    load_config("/data/ProjectRaco/raco.txt");

    // Yamada: This has to be done, since my rakakikomi can't handle partially edit file
    // Therefore I supposed it can be done with normal fopen and write then fclose
    char state_cmd[256];
    snprintf(state_cmd, sizeof(state_cmd), "sed -i 's/^STATE.*/STATE %d/' /data/ProjectRaco/raco.txt", mode);
    system(state_cmd);

    switch (mode) {
        case 4:
            mode_awaken();
            break;
        case 3:
            mode_balanced();
            break;
        case 2:
            mode_powersave();
            break;
        case 1:
            mode_normal();
            break;
        default:
            printf("Error: Invalid mode '%d'. Mission aborted.\n", mode);
            return 1;
    }

    return 0;
}