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

// Carlotta CPU
void carlotta_cpu(int hardlock) {
    system("setprop debug.hwui.use_hint_manager true");
    system("setprop debug.sf.enable_adpf_cpu_hint true");

    long long u1 = 0, n1 = 0, s1 = 0, i1 = 0, io1 = 0, irq1 = 0, sirq1 = 0, st1 = 0;
    long long u2 = 0, n2 = 0, s2 = 0, i2 = 0, io2 = 0, irq2 = 0, sirq2 = 0, st2 = 0;
    int current_load = 0;
    char buffer[4096];

    if (raread("/proc/stat", buffer, sizeof(buffer)) > 0) {
        sscanf(buffer, "cpu %lld %lld %lld %lld %lld %lld %lld %lld", &u1, &n1, &s1, &i1, &io1, &irq1, &sirq1, &st1);

        usleep(100000); // Measure Delta

        if (raread("/proc/stat", buffer, sizeof(buffer)) > 0) {
            sscanf(buffer, "cpu %lld %lld %lld %lld %lld %lld %lld %lld", &u2, &n2, &s2, &i2, &io2, &irq2, &sirq2, &st2);

            long long total1 = u1 + n1 + s1 + i1 + io1 + irq1 + sirq1 + st1;
            long long idle1 = i1 + io1;

            long long total2 = u2 + n2 + s2 + i2 + io2 + irq2 + sirq2 + st2;
            long long idle2 = i2 + io2;

            long long diff_total = total2 - total1;
            long long diff_idle = idle2 - idle1;

            if (diff_total > 0) {
                long long load = (1000 * (diff_total - diff_idle)) / diff_total;
                int adjusted_load = load / 10;

                int num_cores = sysconf(_SC_NPROCESSORS_ONLN);
                if (num_cores < 1) num_cores = 1;

                if (num_cores > 8) {
                    adjusted_load = (adjusted_load * 8) / num_cores;
                }
                current_load = adjusted_load;
            }
        } 
    }
    int target_percent = (current_load > hardlock) ? hardlock : current_load;

    char cmd[256];
    snprintf(cmd, sizeof(cmd), "setprop debug.hwui.target_cpu_time_percent %d", target_percent);
    system(cmd);
    
    pid_t pid = getpid();
    snprintf(cmd, sizeof(cmd), "iorenice %d 7 idle >/dev/null 2>&1", pid); system(cmd); 
    snprintf(cmd, sizeof(cmd), "renice -n 19 -p %d >/dev/null 2>&1", pid); system(cmd); 
    snprintf(cmd, sizeof(cmd), "taskset -ap 1 %d >/dev/null 2>&1", pid); system(cmd); 
}

// Corin Function
void corin_storage(const char *sched, const char *rq) {
    DIR *dir; struct dirent *ent;
    if ((dir = opendir("/sys/block")) != NULL) {
        while ((ent = readdir(dir)) != NULL) {
            if (ent->d_name[0] != '.' && strncmp(ent->d_name, "loop", 4) != 0) {
                char path[256];
                snprintf(path, sizeof(path), "/sys/block/%s/queue/scheduler", ent->d_name);
                rawrite(sched, path);

                snprintf(path, sizeof(path), "/sys/block/%s/queue/rq_affinity", ent->d_name);
                rawrite(rq, path);
            }
        }
        closedir(dir);
    }
}

// Toast Helper
void app_toast(const char *msg) {
    char cmd[1024];
    if (config.legacy_notif == 1) {
        snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t 'Project Raco' 'TagRaco' '%s'\" >/dev/null 2>&1 &", msg);
    } else {
        snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t 'Project Raco' -i file:///data/local/tmp/logo.png -I file:///data/local/tmp/logo.png 'TagRaco' '%s'\" >/dev/null 2>&1 &", msg);
    }
    system(cmd);
}

// Master Profiles
void mode_awaken() {
    app_toast("Applying Awaken Profile...");
    system("sync");

    apply_io_tweaks("0", "0", "32", "32", 1);
    apply_net_tweaks("1", "1", "3", "0", 1);
    if (config.device_mitigation == 1) {
        rawrite("1", "/proc/sys/kernel/split_lock_mitigate");
    } else {
        rawrite("0", "/proc/sys/kernel/split_lock_mitigate");
    }
    rawrite("0", "/proc/sys/vm/page-cluster");
    rawrite("80", "/proc/sys/vm/vfs_cache_pressure");
    carlotta_cpu(80);

    corin_storage("deadline", "1");
    system("settings put secure high_priority 1; settings put secure low_priority 0; "
           "cmd power set-adaptive-power-saver-enabled false; "
           "cmd power set-fixed-performance-mode-enabled true; "
           "cmd looper_stats disable; "
           "cmd power set-mode 0 &");
    
    system("atrace --async_stop >/dev/null 2>&1; "
           "cmd looper_stats reset >/dev/null 2>&1; "
           "setprop debug.debuggerd.wait_for_debugger false; "
           "setprop debug.debuggerd.wait_for_gdb false; "
           "setprop debug.debuggerd.disable 1 &");

    system("dumpsys binder_calls_stats --reset >/dev/null 2>&1; "
           "dumpsys binder_calls_stats --disable >/dev/null 2>&1; "
           "dumpsys binder_calls_stats --disable-detailed-tracking >/dev/null 2>&1; "
           "dumpsys procstats --clear >/dev/null 2>&1; "
           "dumpsys procstats --stop-testing >/dev/null 2>&1 &");

    system("cmd display ab-logging-disable >/dev/null 2>&1; "
           "cmd display dwb-logging-disable >/dev/null 2>&1; "
           "cmd display dmd-logging-disable >/dev/null 2>&1; "
           "logcat -G 64K >/dev/null 2>&1; logcat -c >/dev/null 2>&1 &");

    change_cpu_gov("performance");
    cpufreq_awaken();
    route_soc(4);

    clear_slingshot();
    anyamelfissa();
    app_toast("Switched to Awaken Mode");
}

void mode_balanced() {
    app_toast("Applying Balanced Profile...");
    system("sync");

    apply_io_tweaks("1", "1", "128", "128", 0);
    apply_net_tweaks("0", "2", "1", "1", 0);
    rakakikomi("1", "/proc/sys/kernel/split_lock_mitigate");
    rakakikomi("3", "/proc/sys/vm/page-cluster");
    rakakikomi("120", "/proc/sys/vm/vfs_cache_pressure");
    carlotta_cpu(55);

    corin_storage("deadline", "1");
    system("settings put secure high_priority 1; settings put secure low_priority 0; "
           "cmd power set-adaptive-power-saver-enabled false; "
           "cmd power set-fixed-performance-mode-enabled false; "
           "cmd looper_stats enable; "
           "cmd power set-mode 0 &");

    system("atrace --async_stop >/dev/null 2>&1; "
           "cmd looper_stats reset >/dev/null 2>&1; "
           "cmd looper_stats disable >/dev/null 2>&1 &");

    system("for app in $(pm list packages | cut -d: -f2); do pm log-visibility --disable $app; done >/dev/null 2>&1 &");

    system("dumpsys binder_calls_stats --reset >/dev/null 2>&1; "
           "dumpsys binder_calls_stats --disable >/dev/null 2>&1; "
           "dumpsys binder_calls_stats --disable-detailed-tracking >/dev/null 2>&1; "
           "dumpsys procstats --clear >/dev/null 2>&1; "
           "dumpsys procstats --stop-testing >/dev/null 2>&1 &");

    system("cmd display ab-logging-disable >/dev/null 2>&1; "
           "cmd display dwb-logging-disable >/dev/null 2>&1; "
           "cmd display dmd-logging-disable >/dev/null 2>&1 &");

    system("for f in $(dumpsys window | grep \"^  Proto:\" | sed 's/^  Proto: //' | tr ' ' '\\n'; dumpsys window | grep \"^  Logcat:\" | sed 's/^  Logcat: //' | tr ' ' '\\n'); do wm logging disable \"$f\"; wm logging disable-text \"$f\"; done >/dev/null 2>&1 &");

    change_cpu_gov(config.default_gov);
    cpufreq_balanced();
    route_soc(3);

    clear_slingshot();
    anyakawaii();
    app_toast("Switched to Balanced Mode");
}

void mode_powersave() {
    app_toast("Applying Eco Profile...");
    system("sync");

    apply_io_tweaks("1", "1", "128", "128", 0);
    apply_net_tweaks("0", "2", "1", "1", 0);
    rakakikomi("1", "/proc/sys/kernel/split_lock_mitigate");
    rakakikomi("3", "/proc/sys/vm/page-cluster");
    rakakikomi("100", "/proc/sys/vm/vfs_cache_pressure");
    carlotta_cpu(40);

    corin_storage("deadline", "2");
    system("settings put secure high_priority 0; settings put secure low_priority 1; "
           "cmd power set-adaptive-power-saver-enabled true; "
           "cmd power set-fixed-performance-mode-enabled false; "
           "cmd looper_stats enable; "
           "cmd power set-mode 1 &");

    system("atrace --async_stop >/dev/null 2>&1; "
           "cmd looper_stats reset >/dev/null 2>&1; "
           "cmd looper_stats disable >/dev/null 2>&1 &");

    system("for app in $(pm list packages | cut -d: -f2); do pm log-visibility --disable $app; done >/dev/null 2>&1 &");

    system("dumpsys binder_calls_stats --reset >/dev/null 2>&1; "
           "dumpsys binder_calls_stats --disable >/dev/null 2>&1; "
           "dumpsys binder_calls_stats --disable-detailed-tracking >/dev/null 2>&1; "
           "dumpsys procstats --clear >/dev/null 2>&1; "
           "dumpsys procstats --stop-testing >/dev/null 2>&1 &");

    system("cmd display ab-logging-disable >/dev/null 2>&1; "
           "cmd display dwb-logging-disable >/dev/null 2>&1; "
           "cmd display dmd-logging-disable >/dev/null 2>&1 &");

    system("for f in $(dumpsys window | grep \"^  Proto:\" | sed 's/^  Proto: //' | tr ' ' '\\n'; dumpsys window | grep \"^  Logcat:\" | sed 's/^  Logcat: //' | tr ' ' '\\n'); do wm logging disable \"$f\"; wm logging disable-text \"$f\"; done >/dev/null 2>&1 &");
    
    change_cpu_gov("powersave");
    cpufreq_powersave();
    route_soc(2);

    clear_slingshot();
    anyakawaii();
    app_toast("Switched to Eco Mode");
}

void mode_normal() {
    app_toast("Restoring Normal State...");
    system("sync");

    apply_io_tweaks("1", "1", "128", "128", 0);
    apply_net_tweaks("0", "2", "1", "1", 0);
    rakakikomi("1", "/proc/sys/kernel/split_lock_mitigate");
    rakakikomi("3", "/proc/sys/vm/page-cluster");
    rakakikomi("120", "/proc/sys/vm/vfs_cache_pressure");
    carlotta_cpu(55);

    corin_storage("deadline", "1");
    system("settings put secure high_priority 1; settings put secure low_priority 0; "
           "cmd power set-adaptive-power-saver-enabled false; "
           "cmd power set-fixed-performance-mode-enabled false; "
           "cmd looper_stats enable; "
           "cmd power set-mode 0 &");

    system("atrace --async_stop >/dev/null 2>&1; "
           "cmd looper_stats reset >/dev/null 2>&1; "
           "cmd looper_stats disable >/dev/null 2>&1 &");

    system("for app in $(pm list packages | cut -d: -f2); do pm log-visibility --disable $app; done >/dev/null 2>&1 &");

    system("dumpsys binder_calls_stats --reset >/dev/null 2>&1; "
           "dumpsys binder_calls_stats --disable >/dev/null 2>&1; "
           "dumpsys binder_calls_stats --disable-detailed-tracking >/dev/null 2>&1; "
           "dumpsys procstats --clear >/dev/null 2>&1; "
           "dumpsys procstats --stop-testing >/dev/null 2>&1 &");

    system("cmd display ab-logging-disable >/dev/null 2>&1; "
           "cmd display dwb-logging-disable >/dev/null 2>&1; "
           "cmd display dmd-logging-disable >/dev/null 2>&1 &");

    system("for f in $(dumpsys window | grep \"^  Proto:\" | sed 's/^  Proto: //' | tr ' ' '\\n'; dumpsys window | grep \"^  Logcat:\" | sed 's/^  Logcat: //' | tr ' ' '\\n'); do wm logging disable \"$f\"; wm logging disable-text \"$f\"; done >/dev/null 2>&1 &");

    change_cpu_gov(config.default_gov);
    cpufreq_normal();
    route_soc(1);

    clear_slingshot();
    anyakawaii();
    app_toast("Restored Normal State");
}

// Main Execution

int main(int argc, char *argv[]) {
    if (argc < 2) {
        return 1;
    }

    int mode = atoi(argv[1]);

    load_config("/data/ProjectRaco/raco.txt");

    // Yamada: PLEASE REMEMBER THIS.
    /*
    4 = Awaken
    3 = Balanced -> Keep in mind "Balanced" here is term of balanced performance, so half them minfreq
    2 = Powersave
    1 = Normal -> This is the one who restores all to default
    */

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