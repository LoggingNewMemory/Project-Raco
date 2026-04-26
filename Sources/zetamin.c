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
#include <stdint.h>
#include <glob.h>
#include <dirent.h>
#include "raco_utils.h"

int exec_get_int(const char *cmd, int default_val) {
    FILE *fp = popen(cmd, "r");
    if (!fp) return default_val;
    int val = default_val;
    if (fscanf(fp, "%d", &val) != 1) val = default_val;
    pclose(fp);
    return val;
}

void mask_val(const char *val, const char *path) {
    if (access(path, F_OK) == 0) {
        system("touch /data/local/tmp/mount_mask");
        char cmd[256];
        snprintf(cmd, sizeof(cmd), "umount %s 2>/dev/null", path);
        system(cmd);
        
        kakangku(val, path);
        
        snprintf(cmd, sizeof(cmd), "mount --bind /data/local/tmp/mount_mask %s 2>/dev/null", path);
        system(cmd);
    }
}

void change_task_cgroup(const char *pattern, const char *group, const char *type) {
    char cmd[256];
    snprintf(cmd, sizeof(cmd), "pgrep -f -i '%s'", pattern);
    FILE *fp = popen(cmd, "r");
    if (!fp) return;
    char pid_str[16];
    
    while (fgets(pid_str, sizeof(pid_str), fp)) {
        pid_str[strcspn(pid_str, "\n")] = 0;
        char task_dir_path[256];
        snprintf(task_dir_path, sizeof(task_dir_path), "/proc/%s/task", pid_str);
        
        DIR *task_dir = opendir(task_dir_path);
        if (task_dir) {
            struct dirent *task_entry;
            while ((task_entry = readdir(task_dir)) != NULL) {
                if (task_entry->d_name[0] >= '0' && task_entry->d_name[0] <= '9') {
                    char cg_path[256];
                    snprintf(cg_path, sizeof(cg_path), "/dev/%s/%s/tasks", type, group);
                    kakangku(task_entry->d_name, cg_path); 
                }
            }
            closedir(task_dir);
        }
    }
    pclose(fp);
}

void apply_sf_flux() {
    int max_rate = exec_get_int("cmd display dump 2>/dev/null | grep -Eo 'fps=[0-9.]+' | cut -f2 -d= | sort -nr | head -n1 | cut -d . -f 1", 60);

    if (max_rate > 60) {
        char cmd[128];
        snprintf(cmd, sizeof(cmd), "settings put system min_refresh_rate %d", max_rate); system(cmd);
        snprintf(cmd, sizeof(cmd), "settings put system peak_refresh_rate %d", max_rate); system(cmd);
        snprintf(cmd, sizeof(cmd), "resetprop ro.surface_flinger.game_default_frame_rate_override %d", max_rate); system(cmd);
    }

    int fps = exec_get_int("dumpsys display | grep -m1 \"mDefaultPeak\" | awk '{print int($2)}'", 60);
    if (fps <= 0) fps = 60;

    // Derived from Zetamin.sh frame-time calculations
    long long ft = 1000000000LL / fps;
    int base_const = (ft <= 13000000) ? 70 : 72;
    int thresh = (int)((ft / 1000000) + base_const + 2);
    long long next_vsync = (ft / 6) + (thresh * 4800);

    char cmd[128];
    snprintf(cmd, sizeof(cmd), "setprop debug.sf.set_idle_timer_ms %d", thresh); system(cmd);
    snprintf(cmd, sizeof(cmd), "setprop debug.sf.phase_offset_threshold_for_next_vsync_ns %lld", next_vsync); system(cmd);

    float threshold_multiplier = (ft <= 10000000) ? 0.85f : 0.75f;
    snprintf(cmd, sizeof(cmd), "setprop debug.sf.frame_rate_multiple_threshold %.6f", (ft / 1000000000.0) * threshold_multiplier); system(cmd);
}

void apply_facur() {
    int fps = exec_get_int("dumpsys display | grep -m1 \"mDefaultPeak\" | awk '{print int($2)}'", 60);
    if (fps <= 0) fps = 60;

    long long vsync_ns = 1000000000LL / fps;
    long long val_e = (vsync_ns * 80) / 100;
    long long val_f = (vsync_ns * 60) / 100;
    long long val_g = -val_e;
    long long val_h = -val_f;

    char cmd[512];
    
    const char *prop_e[] = {
        "debug.sf.early.app.duration", "debug.sf.earlyGl.app.duration",
        "debug.sf.high_fps.early.app.duration", "debug.sf.high_fps.earlyGl.app.duration",
        "debug.sf.high_fps.late.app.duration", "debug.sf.late.app.duration"
    };
    for (int i = 0; i < 6; i++) {
        snprintf(cmd, sizeof(cmd), "setprop %s %lld", prop_e[i], val_e); system(cmd);
    }

    const char *prop_f[] = {
        "debug.sf.early.sf.duration", "debug.sf.earlyGl.sf.duration",
        "debug.sf.high_fps.early.sf.duration", "debug.sf.high_fps.earlyGl.sf.duration",
        "debug.sf.high_fps.late.sf.duration", "debug.sf.late.sf.duration"
    };
    for (int i = 0; i < 6; i++) {
        snprintf(cmd, sizeof(cmd), "setprop %s %lld", prop_f[i], val_f); system(cmd);
    }

    const char *prop_g[] = {
        "debug.sf.earlyGl_app_phase_offset_ns", "debug.sf.early_app_phase_offset_ns",
        "debug.sf.high_fps_earlyGl_app_phase_offset_ns", "debug.sf.high_fps_early_app_phase_offset_ns",
        "debug.sf.high_fps_late_app_phase_offset_ns", "debug.sf.late_app_phase_offset_ns"
    };
    const char *prop_h[] = {
        "debug.sf.earlyGl_phase_offset_ns", "debug.sf.early_phase_offset_ns",
        "debug.sf.high_fps_earlyGl_phase_offset_ns", "debug.sf.high_fps_early_phase_offset_ns",
        "debug.sf.high_fps_late_phase_offset_ns", "debug.sf.late_phase_offset_ns"
    };
    
    for (int i = 0; i < 6; i++) {
        snprintf(cmd, sizeof(cmd), "setprop %s %lld", prop_g[i], val_g); system(cmd);
        snprintf(cmd, sizeof(cmd), "setprop %s %lld", prop_h[i], val_h); system(cmd);
    }

    system("setprop debug.sf.prime_shader_cache.solid_layers true");
    system("setprop debug.sf.prime_shader_cache.image_layers true");
    system("setprop debug.sf.prime_shader_cache.shadow_layers true");
    
    FILE *f = fopen("/proc/sys/kernel/perf_cpu_time_max_percent", "r");
    int b = 25;
    if (f) { fscanf(f, "%d", &b); fclose(f); }
    if (b <= 0) b = 25;

    float load1 = 0.0f;
    f = fopen("/proc/loadavg", "r");
    if (f) { fscanf(f, "%f", &load1); fclose(f); }

    float n = load1 / b;
    int target = (int)(35 + (n * 15) / (1 + n));
    snprintf(cmd, sizeof(cmd), "setprop debug.hwui.target_cpu_time_percent %d", target); system(cmd);
}

void optimize_gpu() {
    int fps = exec_get_int("dumpsys display | grep -m1 \"mDefaultPeak\" | awk '{print int($2)}'", 60);
    char fps_str[16];
    snprintf(fps_str, sizeof(fps_str), "%d", fps);

    // Deep GED adjustments (Zetamin.sh specific)
    if (access("/sys/module/ged/parameters", F_OK) == 0) {
        kakangku("1000", "/sys/module/ged/parameters/ged_smart_boost");
        kakangku("100", "/sys/module/ged/parameters/boost_upper_bound");
        kakangku(fps_str, "/sys/module/ged/parameters/gx_dfps");
        kakangku("1", "/sys/module/ged/parameters/g_gpu_timer_based_emu");
        kakangku("1", "/sys/module/ged/parameters/boost_gpu_enable");
        kakangku("1", "/sys/module/ged/parameters/ged_boost_enable");
        kakangku("1", "/sys/module/ged/parameters/enable_gpu_boost");
        kakangku("1", "/sys/module/ged/parameters/gx_game_mode");
        kakangku("1", "/sys/module/ged/parameters/gx_boost_on");
        
        // Expanded GED properties from Bash script
        kakangku("1", "/sys/module/ged/parameters/boost_amp");
        kakangku("1", "/sys/module/ged/parameters/gx_3D_benchmark_on");
        kakangku("1", "/sys/module/ged/parameters/is_GED_KPI_enabled");
        kakangku("1", "/sys/module/ged/parameters/gpu_dvfs_enable");
        kakangku("0", "/sys/module/ged/parameters/ged_monitor_3D_fence_disable");
        kakangku("0", "/sys/module/ged/parameters/ged_monitor_3D_fence_debug");
        kakangku("0", "/sys/module/ged/parameters/ged_log_perf_trace_enable");
        kakangku("0", "/sys/module/ged/parameters/ged_log_trace_enable");
        kakangku("0", "/sys/module/ged/parameters/gpu_bw_err_debug");
        kakangku("0", "/sys/module/ged/parameters/gx_frc_mode");
        kakangku("0", "/sys/module/ged/parameters/gpu_idle");
        kakangku("0", "/sys/module/ged/parameters/gpu_debug_enable");
    }

    if (access("/sys/kernel/debug/ged/hal", F_OK) == 0) {
        kakangku("2", "/sys/kernel/debug/ged/hal/gpu_boost_level");
        kakangku("1", "/sys/kernel/debug/ged/hal/custom_upbound_gpu_freq");
    }
    
    // FPSGo Block boost
    if (access("/sys/kernel/debug/fpsgo/common/gpu_block_boost", F_OK) == 0) {
        kakangku("60 120 1", "/sys/kernel/debug/fpsgo/common/gpu_block_boost");
    }

    if (access("/proc/gpufreq", F_OK) == 0) {
        kakangku("1 1 1", "/proc/gpufreq/limit_table");
        kakangku("1", "/proc/gpufreq/gpufreq_limited_thermal_ignore");
        kakangku("1", "/proc/gpufreq/gpufreq_limited_oc_ignore");
        kakangku("1", "/proc/gpufreq/gpufreq_limited_low_batt_volume_ignore");
        kakangku("1", "/proc/gpufreq/gpufreq_limited_low_batt_volt_ignore");
        kakangku("0", "/proc/gpufreq/gpufreq_fixed_freq_volt");
        kakangku("0", "/proc/gpufreq/gpufreq_opp_stress_test");
        kakangku("0", "/proc/gpufreq/gpufreq_power_dump");
        kakangku("0", "/proc/gpufreq/gpufreq_power_limited");
    }

    if (access("/proc/gpufreqv2", F_OK) == 0) {
        kakangku("disable", "/proc/gpufreqv2/aging_mode");
    }

    // PVR Tuning
    if (access("/sys/module/pvrsrvkm/parameters", F_OK) == 0) {
        kakangku("2", "/sys/module/pvrsrvkm/parameters/gpu_power");
        kakangku("512", "/sys/module/pvrsrvkm/parameters/HTBufferSizeInKB");
        kakangku("1", "/sys/module/pvrsrvkm/parameters/DisableClockGating");
        kakangku("2", "/sys/module/pvrsrvkm/parameters/EmuMaxFreq");
        kakangku("1", "/sys/module/pvrsrvkm/parameters/EnableFWContextSwitch");
        kakangku("0", "/sys/module/pvrsrvkm/parameters/gPVRDebugLevel");
        kakangku("1", "/sys/module/pvrsrvkm/parameters/gpu_dvfs_enable");
    }

    // PVR Apphints
    if (access("/sys/kernel/debug/pvr/apphint", F_OK) == 0) {
        kakangku("1", "/sys/kernel/debug/pvr/apphint/CacheOpConfig");
        kakangku("512", "/sys/kernel/debug/pvr/apphint/CacheOpUMKMThresholdSize");
        kakangku("0", "/sys/kernel/debug/pvr/apphint/EnableFTraceGPU");
        kakangku("2", "/sys/kernel/debug/pvr/apphint/HTBOperationMode");
        kakangku("1", "/sys/kernel/debug/pvr/apphint/TimeCorrClock");
        kakangku("1", "/sys/kernel/debug/pvr/apphint/0/DisableFEDLogging");
        kakangku("0", "/sys/kernel/debug/pvr/apphint/0/EnableAPM");
    }

    // Adreno Tuning
    if (access("/sys/class/kgsl/kgsl-3d0", F_OK) == 0) {
        int pwrlvl = exec_get_int("cat /sys/class/kgsl/kgsl-3d0/num_pwrlevels", 1) - 1;
        char pwr_str[16];
        snprintf(pwr_str, sizeof(pwr_str), "%d", pwrlvl);

        mask_val(pwr_str, "/sys/class/kgsl/kgsl-3d0/default_pwrlevel");
        mask_val(pwr_str, "/sys/class/kgsl/kgsl-3d0/min_pwrlevel");
        mask_val("0", "/sys/class/kgsl/kgsl-3d0/max_pwrlevel");
        mask_val("1", "/sys/class/kgsl/kgsl-3d0/bus_split");
        mask_val("1", "/sys/class/kgsl/kgsl-3d0/force_clk_on");
        mask_val("1", "/sys/class/kgsl/kgsl-3d0/force_no_nap");
        mask_val("1", "/sys/class/kgsl/kgsl-3d0/force_rail_on");
        mask_val("0", "/sys/class/kgsl/kgsl-3d0/force_bus_on");
        mask_val("0", "/sys/class/kgsl/kgsl-3d0/thermal_pwrlevel");
        mask_val("0", "/sys/class/kgsl/kgsl-3d0/perfcounter");
        mask_val("0", "/sys/class/kgsl/kgsl-3d0/throttling");
        mask_val("0", "/sys/class/kgsl/kgsl-3d0/fsync_enable");
        mask_val("0", "/sys/class/kgsl/kgsl-3d0/vsync_enable");
    }
    
    mask_val("0", "/sys/class/kgsl/kgsl-3d0/devfreq/adrenoboost");
    kakangku("0", "/sys/kernel/debug/kgsl/kgsl-3d0/profiling/enable");
    kakangku("0", "/sys/module/adreno_idler/parameters/adreno_idler_active");
    kakangku("1", "/sys/module/msm_performance/parameters/touchboost");

    kakangku("1", "/proc/mali/dvfs_enable");
    kakangku("1", "/sys/devices/platform/gpu/dvfs_enable");
    kakangku("1", "/sys/devices/platform/gpu/gpu_busy");
    
    glob_t globbuf;
    if (glob("/sys/devices/platform/soc/*mali*/scheduling/serialize_jobs", 0, NULL, &globbuf) == 0) {
        if (globbuf.gl_pathc > 0) kakangku("full", globbuf.gl_pathv[0]);
        globfree(&globbuf);
    }
    if (glob("/sys/devices/platform/soc/*mali*/js_ctx_scheduling_mode", 0, NULL, &globbuf) == 0) {
        if (globbuf.gl_pathc > 0) kakangku("1", globbuf.gl_pathv[0]);
        globfree(&globbuf);
    }
    
    find_and_tweak("/sys/kernel/debug/tracing/events/pvr_fence", "enable", "0", 0);
    kakangku("0", "/sys/kernel/debug/tracing/events/mtk_events/enable");
    kakangku("0", "/proc/gpufreq/gpufreq_aging_enable");

    kakangku("0-3,4-7", "/dev/cpuset/foreground/cpus");
    kakangku("4-7", "/dev/cpuset/foreground/boost/cpus");
    kakangku("0-7", "/dev/cpuset/top-app/cpus");
}

void optimize_cgroups() {
    change_task_cgroup("surfaceflinger", "", "cpuset");
    change_task_cgroup("system_server", "foreground", "cpuset");
    change_task_cgroup("netd|allocator", "foreground", "cpuset");
    change_task_cgroup("hardware.media.c2|vendor.mediatek.hardware", "background", "cpuset");
    change_task_cgroup("aal_sof|kfps|dsp_send_thread|vdec_ipi_recv|mtk_drm_disp_id|disp_feature|hif_thread|main_thread|rx_thread|ged_", "background", "cpuset");
    change_task_cgroup("pp_event|crtc_", "background", "cpuset");
}

int main(int argc, char *argv[]) {
    printf("[*] Executing Zetamin Rendering Optimizations...\n");
    sync();
    apply_sf_flux();
    apply_facur();
    sync();
    optimize_gpu();
    optimize_cgroups();
    printf("[+] Zetamin applied successfully.\n");
    return 0;
}