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

#define CONFIG_FILE "/data/ProjectRaco/raco.txt"

// Local Configuration State
int include_sandev = 0;
int include_soc = 0;
int include_anya = 0;
int anya_val = 0;
int include_kobo = 0;
int include_zetamin = 0;
int legacy_notif = 0;
int silent_notif = 1;

void wait_for_boot() {
    char buf[128];
    while (1) {
        FILE *fp = popen("getprop sys.boot_completed", "r");
        if (fp) {
            if (fgets(buf, sizeof(buf), fp) && buf[0] == '1') {
                pclose(fp);
                break;
            }
            pclose(fp);
        }
        sleep(10);
    }
}

void load_service_config() {
    char buffer[2048] = {0};
    if (moco(CONFIG_FILE, buffer, sizeof(buffer)) <= 0) return;
    
    char *line = strtok(buffer, "\n");
    char key[64], value[64];
    
    while (line != NULL) {
        if (sscanf(line, "%63s %63s", key, value) == 2) {
            if (strcmp(key, "INCLUDE_SANDEV") == 0) include_sandev = atoi(value);
            else if (strcmp(key, "SOC") == 0) include_soc = atoi(value);
            else if (strcmp(key, "INCLUDE_ANYA") == 0) include_anya = atoi(value);
            else if (strcmp(key, "ANYA") == 0) anya_val = atoi(value);
            else if (strcmp(key, "INCLUDE_KOBO") == 0) include_kobo = atoi(value);
            else if (strcmp(key, "INCLUDE_ZETAMIN") == 0) include_zetamin = atoi(value);
            else if (strcmp(key, "LEGACY_NOTIF") == 0) legacy_notif = atoi(value);
            else if (strcmp(key, "SILENT_NOTIF") == 0) silent_notif = atoi(value);
        }
        line = strtok(NULL, "\n");
    }
}

void send_notif(const char *title, const char *message, const char *tag, const char *icon_path) {
    if (silent_notif == 0) {
        return;
    }

    char cmd[1024];
    if (legacy_notif == 1) {
        snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t '%s' '%s' '%s'\"", title, tag, message);
    } else {
        snprintf(cmd, sizeof(cmd), "su -lp 2000 -c \"cmd notification post -S bigtext -t '%s' -i file://%s -I file://%s '%s' '%s'\"", title, icon_path, icon_path, tag, message);
    }
    system(cmd);
}

void apply_mali_tweaks() {
    glob_t globbuf;
    if (glob("/sys/devices/platform/soc/*mali*/scheduling/serialize_jobs", 0, NULL, &globbuf) == 0) {
        kakangku("full", globbuf.gl_pathv[0]);
        globfree(&globbuf);
    }
    if (glob("/sys/devices/platform/soc/*mali*/js_ctx_scheduling_mode", 0, NULL, &globbuf) == 0) {
        kakangku("1", globbuf.gl_pathv[0]);
        globfree(&globbuf);
    }
}

void kamigo_tweaks() {
    kakangku("0", "/sys/kernel/fpsgo/fbt/enable_ceiling");
    kakangku("0", "/sys/kernel/fpsgo/fbt/limit_cfreq");
    kakangku("0", "/sys/kernel/fpsgo/fbt/limit_rfreq");
    kakangku("0", "/sys/kernel/fpsgo/fbt/limit_uclamp");
    kakangku("1", "/sys/module/mtk_fpsgo/parameters/bhr");
    kakangku("15", "/sys/module/mtk_fpsgo/parameters/bhr_opp");
    kakangku("1", "/sys/kernel/fpsgo/fbt/rescue_enable");
    kakangku("1", "/sys/kernel/fpsgo/fbt/ultra_rescue");
    kakangku("95", "/sys/module/mtk_fpsgo/parameters/rescue_percent");
    kakangku("1", "/sys/module/mtk_fpsgo/parameters/qr_enable");
    kakangku("0", "/sys/kernel/fpsgo/fstb/fstb_self_ctrl_fps_enable");
    kakangku("1", "/sys/kernel/fpsgo/fstb/margin_mode");
    kakangku("1", "/sys/pnpmgr/fpsgo_boost/boost_mode");
    kakangku("1", "/sys/kernel/fpsgo/fbt/boost_VIP");
    kakangku("1", "/sys/kernel/fpsgo/fbt/boost_ta");
}

void facur_tweaks() {
    system("device_config put activity_manager proactive_kills_enabled false >/dev/null 2>&1");
    system("atrace --async_stop >/dev/null 2>&1");
    system("cmd window tracing stop >/dev/null 2>&1");
    
    kakangku("0", "/sys/kernel/tracing/tracing_on");
    kakangku("0", "/sys/kernel/debug/tracing/tracing_on");

    glob_t globbuf;
    if (glob("/sys/block/*/queue/scheduler", 0, NULL, &globbuf) == 0) {
        for (size_t i = 0; i < globbuf.gl_pathc; i++) kakangku("none", globbuf.gl_pathv[i]);
        globfree(&globbuf);
    }

    kakangku("1", "/sys/module/workqueue/parameters/power_efficient");
    kakangku("60", "/proc/sys/vm/swappiness");
    kakangku("10", "/proc/sys/vm/vfs_cache_pressure");
    kakangku("256", "/proc/sys/kernel/random/read_wakeup_threshold");
    kakangku("128", "/proc/sys/kernel/random/write_wakeup_threshold");
}

void ghenna_optimize_tasks() {
    const char *task_script = 
        "change_task_opt() {\n"
        "  ps_ret=$(ps -A 2>/dev/null || ps 2>/dev/null)\n"
        "  for temp_pid in $(echo \"$ps_ret\" | grep -i -E \"$1\" | grep -v \"PID\" | awk '{print $1}'); do\n"
        "    if [ -d \"/proc/$temp_pid\" ]; then\n"
        "      for temp_tid in $(ls \"/proc/$temp_pid/task/\" 2>/dev/null); do\n"
        "        if [ -n \"$2\" ]; then taskset -p \"$2\" \"$temp_tid\" 2>/dev/null || echo \"$temp_tid\" > \"/dev/cpuset/top-app/tasks\" 2>/dev/null; fi\n"
        "        if [ -n \"$3\" ]; then renice -n +40 -p \"$temp_tid\" 2>/dev/null; renice -n -19 -p \"$temp_tid\" 2>/dev/null; renice -n \"$3\" -p \"$temp_tid\" 2>/dev/null; fi\n"
        "      done\n"
        "    fi\n"
        "  done\n"
        "}\n"
        "change_task_opt 'kswapd' '7f' '-2'\n"
        "change_task_opt 'oom_reaper' '7f' '-2'\n"
        "change_task_opt 'kcompactd' '' '-5'\n"
        "change_task_opt 'kthreadd' '' '-5'\n"
        "change_task_opt 'writeback' '' '-5'\n";
    system(task_script);
}

void ghenna_tweaks() {
    system("rm -f /storage/emulated/0/*.log 2>/dev/null");
    system("rm -f /data/log/*.log 2>/dev/null; rm -f /cache/*.log 2>/dev/null");
    system("dumpsys deviceidle reset 2>/dev/null");
    system("dumpsys deviceidle enable light 2>/dev/null");
    system("dumpsys deviceidle enable deep 2>/dev/null");
    system("settings put global device_idle_constants light_after_inactive_to=15000,light_pre_idle_to=30000,light_idle_to=300000,light_max_idle_to=900000,inactive_to=1800000,idle_after_inactive_to=0,idle_pending_to=300000,max_idle_pending_to=600000,idle_to=3600000,max_idle_to=21600000 2>/dev/null");
    system("pm trim-caches 999999999 2>/dev/null");

    system("su -c \"pm set-inactive com.google.android.gms true\" 2>/dev/null");
    system("su -c \"dumpsys deviceidle whitelist -com.google.android.gms\" 2>/dev/null");
    system("su -c \"dumpsys deviceidle tempwhitelist -c com.google.android.gms\" 2>/dev/null");

    system("cmd accessibility stop-trace 2>/dev/null; cmd input_method tracing stop 2>/dev/null");
    system("cmd window tracing size 0 2>/dev/null; cmd window tracing stop 2>/dev/null");
    system("cmd statusbar tracing stop 2>/dev/null; cmd memory_trace disable 2>/dev/null");
    system("cmd animation tracing stop 2>/dev/null; cmd package tracing stop 2>/dev/null");
    system("cmd wm tracing stop 2>/dev/null; cmd activity tracing stop 2>/dev/null");
    system("cmd broadcast tracing disable 2>/dev/null; atrace --async_stop >/dev/null 2>&1");

    system("logcat -c 2>/dev/null; logcat -G 16K 2>/dev/null");
    system("setprop persist.sys.usb.config adb 2>/dev/null");
    system("setprop ro.logd.size.stats 0 2>/dev/null");
    system("setprop ro.logdumpd.enabled false 2>/dev/null");
    kakangku("0", "/proc/sys/kernel/printk_ratelimit");
    kakangku("0", "/proc/sys/kernel/sysctl_writes_strict");
    kakangku("0", "/sys/kernel/debug/tracing/tracing_on");
    kakangku("nop", "/sys/kernel/debug/tracing/current_tracer");
    kakangku("0", "/sys/kernel/debug/tracing/events/enable");
    system("setprop debug.atrace.tags.enableflags 0 2>/dev/null");
    system("setprop debug.force_rtl false 2>/dev/null");

    ghenna_optimize_tasks();

    kakangku("1", "/sys/kernel/rcu_normal");
    kakangku("0", "/sys/kernel/rcu_expedited");
    kakangku("1", "/proc/sys/kernel/timer_migration");
    kakangku("0", "/sys/devices/system/cpu/isolated");
    kakangku("120", "/proc/sys/kernel/hung_task_timeout_secs");
    kakangku("0", "/dev/stune/top-app/schedtune.boost");
    kakangku("1", "/dev/stune/top-app/schedtune.prefer_idle");
    kakangku("NEXT_BUDDY", "/sys/kernel/debug/sched_features");
    kakangku("TTWU_QUEUE", "/sys/kernel/debug/sched_features");
    kakangku("ENERGY_AWARE", "/sys/kernel/debug/sched_features");

    kakangku("1", "/proc/sys/kernel/sched_energy_aware");
    kakangku("32", "/proc/sys/kernel/sched_nr_migrate");
    kakangku("1", "/proc/sys/kernel/sched_child_runs_first");
    kakangku("4000000", "/proc/sys/kernel/sched_latency_ns");
    kakangku("0", "/proc/sys/kernel/sched_autogroup_enabled");
    kakangku("50000", "/proc/sys/kernel/sched_migration_cost_ns");
    kakangku("1000000", "/proc/sys/kernel/sched_min_granularity_ns");
    kakangku("1500000", "/proc/sys/kernel/sched_wakeup_granularity_ns");

    kakangku("0", "/sys/module/mmc_core/parameters/use_spi_crc");
    kakangku("0", "/sys/module/cpufreq_bouncing/parameters/enable");
    kakangku("819", "/sys/module/tcp_cubic/parameters/beta");
    kakangku("1", "/sys/module/tcp_cubic/parameters/fast_convergence");
    kakangku("1000000", "/sys/module/timer/parameters/sample_period");

    kakangku("0 0 0 0", "/proc/sys/kernel/printk");
    kakangku("off", "/proc/sys/kernel/printk_devkmsg");
    kakangku("0", "/sys/module/printk/parameters/pid");
    kakangku("0", "/sys/module/printk/parameters/cpu");
    kakangku("N", "/sys/module/sync/parameters/fsync_enabled");
    kakangku("0", "/sys/module/printk/parameters/printk_ratelimit");

    const char *panic_nodes[] = {
        "/proc/sys/kernel/panic", "/proc/sys/kernel/panic_on_oops",
        "/proc/sys/kernel/panic_on_warn", "/proc/sys/kernel/panic_on_rcu_stall",
        "/sys/module/kernel/parameters/panic", "/sys/module/kernel/parameters/panic_on_warn",
        "/sys/module/kernel/parameters/pause_on_oops", "/sys/module/kernel/panic_on_rcu_stall"
    };
    for (int i = 0; i < 8; i++) kakangku("0", panic_nodes[i]);
    
    glob_t gbuf;
    if (glob("/proc/sys/kernel/*panic*", 0, NULL, &gbuf) == 0) {
        for (size_t i = 0; i < gbuf.gl_pathc; i++) kakangku("0", gbuf.gl_pathv[i]);
        globfree(&gbuf);
    }
    if (glob("/sys/module/*/parameters/*panic*", 0, NULL, &gbuf) == 0) {
        for (size_t i = 0; i < gbuf.gl_pathc; i++) kakangku("0", gbuf.gl_pathv[i]);
        globfree(&gbuf);
    }

    kakangku("3", "/proc/sys/vm/drop_caches");
    kakangku("1", "/proc/sys/vm/compact_memory");
    kakangku("0", "/proc/sys/debug/exception-trace");
    kakangku("80", "/proc/sys/vm/vfs_cache_pressure");
    kakangku("60", "/proc/sys/vm/swappiness");

    kakangku("0", "/sys/kernel/debug/dri/0/debug/enable");
    kakangku("1", "/sys/module/spurious/parameters/noirqdebug");
    kakangku("0", "/sys/kernel/debug/gpu/enable");
    kakangku("1", "/sys/kernel/debug/hwcomposer/disable_debug");
    kakangku("0", "/sys/kernel/debug/gpumemdebug");

    system("setprop debug.sf.hw 1");
    system("setprop debug.sf.latch_unsignaled 1");
    system("setprop debug.hwui.drop_shadow_cache_size 6");
    system("setprop debug.hwui.texture_cache_flushrate 0.4");
    system("setprop ro.hwui.render_ahead_lines 2");
    system("setprop ro.hwui.texture_cache_size 72");

    kakangku("1024,2048,4096,8192,12288,16384", "/sys/module/lowmemorykiller/parameters/minfree");
    kakangku("32", "/sys/module/lowmemorykiller/parameters/cost");
    kakangku("256", "/proc/sys/kernel/random/read_wakeup_threshold");
    kakangku("128", "/proc/sys/kernel/random/write_wakeup_threshold");
}

void yanz_universal() {
    kakangku("64", "/proc/sys/kernel/random/read_wakeup/threshold");
    kakangku("128", "/proc/sys/kernel/random/write_wakeup/threshold");
    kakangku("128", "/proc/sys/kernel/random/read_wakeup_threshold");
    kakangku("1024", "/proc/sys/kernel/random/write_wakeup_threshold");

    kakangku("0 0 0 0", "/proc/sys/kernel/printk");
    kakangku("0", "/proc/sys/kernel/printk_devkmsg");
    kakangku("0", "/sys/module/binder/parameters/debug_mask");
    kakangku("0", "/sys/module/printk/parameters/cpu");
    kakangku("1", "/sys/module/printk/parameters/console_suspend");
    kakangku("1", "/sys/module/printk/parameters/ignore_loglevel");
    kakangku("0", "/sys/module/printk/parameters/pid");
    kakangku("0", "/sys/module/printk/parameters/time");
    kakangku("0", "/sys/module/printk/parameters/printk_ratelimit");

    kakangku("N", "/sys/module/sync/parameters/fsync_enabled");
    kakangku("0", "/sys/kernel/debug/mdss_panel_fb0/intf0/mipi/hw_vsync_mode");
    kakangku("0", "/sys/kernel/debug/mdss_panel_fb0/intf0/mipi/vsync_enable");
}

int main() {
    wait_for_boot();

    system("sed -i 's/^STATE=.*/STATE=/' " CONFIG_FILE);
    load_service_config();

    if (include_sandev == 1) {
        change_cpu_gov("performance"); 
    }

    apply_mali_tweaks();
    
    if (include_soc == 1) kamigo_tweaks();

    if (include_anya == 1 && anya_val == 1) {
        system("/data/adb/modules/ProjectRaco/Compiled/anya_thermal disable");
        send_notif("Anya Melfissa", "Good Day! Thermal Is Dead BTW", "TagAnya", "/data/local/tmp/Anya.png");
    }

    if (include_kobo == 1) {
        system("/data/adb/modules/ProjectRaco/Compiled/kobo_kanaeru");
    }
    
    if (include_zetamin == 1) {
        system("/data/adb/modules/ProjectRaco/Compiled/zetamin");
    }

    facur_tweaks();
    ghenna_tweaks();
    yanz_universal();

    send_notif("Project Raco", "Project Raco - オンライン", "TagRaco", "/data/local/tmp/logo.png");

    if (include_sandev == 1) {
        sleep(40); // Hardcoded 40 seconds
        change_cpu_gov("schedutil");
    }

    return 0;
}