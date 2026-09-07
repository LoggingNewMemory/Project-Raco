#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>

FILE* prop_f = NULL;

void resetprop(const char* prop, const char* val) {
    if (prop_f) {
        fprintf(prop_f, "%s=%s\n", prop, val);
    }
}

void resetprop_int(const char* prop, long val) {
    char buf[64];
    snprintf(buf, sizeof(buf), "%ld", val);
    resetprop(prop, buf);
}

void write_val(const char* path, const char* val) {
    FILE *f = fopen(path, "w");
    if (f) {
        fprintf(f, "%s\n", val);
        fclose(f);
    }
}

void write_val_dir(const char* dir, const char* file, const char* val) {
    char path[512];
    snprintf(path, sizeof(path), "%s/%s", dir, file);
    write_val(path, val);
}

void change_task_cgroup(const char* process_pattern, const char* cgroup_name, const char* cgroup_type) {
    char cmd[1024];
    snprintf(cmd, sizeof(cmd), 
        "for temp_pid in $(ps -Ao pid,args | grep -i -E \"%s\" | grep -v PID | awk '{print $1}'); do "
        "for temp_tid in $(ls /proc/$temp_pid/task/ 2>/dev/null); do "
        "echo $temp_tid > /dev/%s/%s/tasks 2>/dev/null; "
        "done; done", 
        process_pattern, cgroup_type, cgroup_name);
    system(cmd);
}

long get_cmd_output_long(const char* cmd) {
    FILE *fp = popen(cmd, "r");
    long val = 0;
    if (fp) {
        char buf[64];
        if (fgets(buf, sizeof(buf), fp)) {
            val = atol(buf);
        }
        pclose(fp);
    }
    return val;
}

void get_cmd_output_str(const char* cmd, char* out, size_t out_size) {
    FILE *fp = popen(cmd, "r");
    if (fp) {
        if (fgets(out, out_size, fp)) {
            out[strcspn(out, "\n")] = 0;
        } else {
            out[0] = '\0';
        }
        pclose(fp);
    } else {
        out[0] = '\0';
    }
}

long get_real_fps() {
    long fps = get_cmd_output_long("cmd display dump 2>/dev/null | grep -Eo 'fps=[0-9.]+' | cut -f2 -d= | sort -nr | head -n1 | cut -d . -f 1");
    if (fps > 0) return fps;
    
    fps = get_cmd_output_long("dumpsys display 2>/dev/null | grep -Eo 'fps=[0-9.]+' | cut -d= -f2 | sort -nr | head -n1 | cut -d . -f 1");
    if (fps > 0) return fps;
    
    fps = get_cmd_output_long("dumpsys display 2>/dev/null | grep -i 'mDefaultPeak' | grep -Eo '[0-9]{2,3}' | head -n1");
    if (fps > 0) return fps;

    fps = get_cmd_output_long("dumpsys SurfaceFlinger 2>/dev/null | grep -i 'refresh-rate' | grep -Eo '[0-9]{2,3}' | head -n1");
    if (fps > 0) return fps;

    fps = get_cmd_output_long("dumpsys display 2>/dev/null | grep -i 'DisplayDeviceInfo' | grep -Eo 'fps [0-9.]+' | grep -Eo '[0-9]+' | sort -nr | head -n1");
    if (fps > 0) return fps;

    return 60; // Absolute fallback if all detections fail
}

void surfaceflinger_autoset(long ft, long thresh) {
    resetprop_int("debug.sf.set_idle_timer_ms", thresh);
    resetprop_int("debug.sf.phase_offset_threshold_for_next_vsync_ns", (ft / 6) + (thresh * 4800));
}

void other(long ft) {
    resetprop("debug.sf.prime_shader_cache.solid_layers", "true");
    resetprop("debug.sf.prime_shader_cache.image_layers", "true");
    resetprop("debug.sf.prime_shader_cache.shadow_layers", "true");

    long b = 25;
    FILE* f_b = fopen("/proc/sys/kernel/perf_cpu_time_max_percent", "r");
    if (f_b) {
        if (fscanf(f_b, "%ld", &b) != 1 || b == 0) b = 25;
        fclose(f_b);
    }
    double load1 = 0;
    FILE* f_l = fopen("/proc/loadavg", "r");
    if (f_l) {
        fscanf(f_l, "%lf", &load1);
        fclose(f_l);
    }
    double n = load1 / b;
    long cpu_time = (long)(35.0 + (n * 15.0) / (1.0 + n));
    resetprop_int("debug.hwui.target_cpu_time_percent", cpu_time);

    char buf[64];
    double ft_f = (double)ft / 1000000000.0;
    double multiplier = (ft <= 10000000) ? 0.85 : 0.75;
    snprintf(buf, sizeof(buf), "%.6f", ft_f * multiplier);
    resetprop("debug.sf.frame_rate_multiple_threshold", buf);
}

void main_flux() {
    system("dumpsys SurfaceFlinger --latency-clear");
    usleep(100000); 
    
    long ft = get_cmd_output_long(
        "out=$(dumpsys SurfaceFlinger --latency 2>/dev/null | head -n 5); "
        "if echo \"$out\" | grep -Eq '^[0-9]+$|^[0-9]{10,}$'; then "
        "echo \"$out\" | head -n1 | grep -oE '[0-9]+'; "
        "else "
        "dumpsys SurfaceFlinger | grep -m1 -E \"VSYNC period|vsyncPeriod\" | awk '{print $7}' | grep -oE '[0-9]+'; "
        "fi"
    );

    long base_const, thresh;

    if (ft > 0) {
        base_const = (ft <= 13000000) ? 70 : 72;
        thresh = (ft / 1000000) + base_const + ((ft <= 13000000) ? 1 : 2);
    } else {
        ft = 16666667;
        base_const = 72;
        thresh = (ft / 1000000) + base_const + 2;
    }

    surfaceflinger_autoset(ft, thresh);
    other(ft);
}

void main_render(long max_rate) {
    long fps = max_rate;
    if (fps <= 0) fps = 60;
    char fps_str[32]; snprintf(fps_str, sizeof(fps_str), "%ld", fps);

    // additional_gpu_settings
    const char* ged = "/sys/module/ged/parameters";
    if (access(ged, F_OK) != -1) {
        write_val_dir(ged, "gx_dfps", fps_str);
        write_val_dir(ged, "gx_game_mode", "1");
        write_val_dir(ged, "gx_3D_benchmark_on", "1");
        write_val_dir(ged, "is_GED_KPI_enabled", "1");
        write_val_dir(ged, "gpu_dvfs_enable", "1");
        write_val_dir(ged, "ged_monitor_3D_fence_disable", "0");
        write_val_dir(ged, "ged_monitor_3D_fence_debug", "0");
        write_val_dir(ged, "ged_log_perf_trace_enable", "0");
        write_val_dir(ged, "ged_log_trace_enable", "0");
        write_val_dir(ged, "gpu_bw_err_debug", "0");
        write_val_dir(ged, "gx_frc_mode", "0");
        write_val_dir(ged, "gpu_idle", "0");
        write_val_dir(ged, "gpu_debug_enable", "0");
        write_val("/sys/devices/platform/gpu/dvfs_enable", "1");
        write_val("/sys/kernel/debug/tracing/events/mtk_events/enable", "0");
    }

    // optimize_pvr_settings
    const char* pvr = "/sys/module/pvrsrvkm/parameters";
    if (access(pvr, F_OK) != -1) {
        write_val_dir(pvr, "HTBufferSizeInKB", "512");
        write_val_dir(pvr, "EnableFWContextSwitch", "1");
        write_val_dir(pvr, "gPVRDebugLevel", "0");
        write_val_dir(pvr, "gpu_dvfs_enable", "1");
        system("for p in $(find /sys/kernel/debug/tracing/events/pvr_fence -name 'enable' 2>/dev/null); do echo \"0\" > \"$p\"; done");
    }
    
    const char* pvr_app = "/sys/kernel/debug/pvr/apphint";
    if (access(pvr_app, F_OK) != -1) {
        write_val_dir(pvr_app, "CacheOpConfig", "1");
        write_val_dir(pvr_app, "CacheOpUMKMThresholdSize", "512");
        write_val_dir(pvr_app, "EnableFTraceGPU", "0");
        write_val_dir(pvr_app, "HTBOperationMode", "2");
        write_val_dir(pvr_app, "TimeCorrClock", "1");
        write_val_dir(pvr_app, "0/DisableFEDLogging", "1");
    }

    // optimize_adreno_driver
    const char* kgsl = "/sys/class/kgsl/kgsl-3d0";
    if (access(kgsl, F_OK) != -1) {
        write_val_dir(kgsl, "bus_split", "1");
        write_val_dir(kgsl, "force_bus_on", "0");
        write_val_dir(kgsl, "perfcounter", "0");
        write_val_dir(kgsl, "fsync_enable", "0");
        write_val_dir(kgsl, "vsync_enable", "0");
        write_val_dir(kgsl, "devfreq/adrenoboost", "0");
        write_val_dir(kgsl, "idle_timer", "120");
        write_val_dir(kgsl, "throttling", "0"); 
        write_val_dir(kgsl, "force_no_nap", "0");
        write_val_dir(kgsl, "force_clk_on", "0");
        write_val_dir(kgsl, "force_rail_on", "0");
        
        write_val("/sys/kernel/debug/kgsl/kgsl-3d0/profiling/enable", "0");
        write_val("/sys/module/adreno_idler/parameters/adreno_idler_active", "0");
    }

    // EAS (Energy Aware Scheduling) stune for UI/Games
    const char* stune_top = "/dev/stune/top-app";
    if (access(stune_top, F_OK) != -1) {
        write_val_dir(stune_top, "schedtune.boost", "10");
        write_val_dir(stune_top, "schedtune.prefer_idle", "1");
    }

    // optimize_fpsgo (MediaTek)
    const char* fpsgo = "/sys/kernel/fpsgo";
    if (access(fpsgo, F_OK) != -1) {
        write_val_dir(fpsgo, "common/fpsgo_enable", "1");
        write_val_dir(fpsgo, "fbt/switch_idleprefer", "1");
        write_val_dir(fpsgo, "fstb/margin_mode", "1");
        write_val_dir(fpsgo, "fstb/margin_mode_gpu", "1");
    }

    // optimize_unisoc_driver (Spreadtrum)
    const char* sprd_drm = "/sys/module/sprd_drm/parameters";
    if (access(sprd_drm, F_OK) != -1) {
        write_val_dir(sprd_drm, "sprd_vboost", "1");
    }

    // optimize_mali_driver
    if (access("/proc/mali", F_OK) != -1 || access("/sys/module/mali_kbase", F_OK) != -1 || access("/sys/class/misc/mali0", F_OK) != -1) {
        write_val("/proc/mali/dvfs_enable", "1");
        char mali_dir[256];
        get_cmd_output_str("if [ -e /sys/class/misc/mali0 ]; then dirname $(dirname $(readlink -f /sys/class/misc/mali0)); else find /sys/devices/platform -type d -name '*mali*' -maxdepth 2 2>/dev/null | head -n 1; fi", mali_dir, sizeof(mali_dir));
        if (mali_dir[0] != '\0' && strcmp(mali_dir, ".") != 0) {
            write_val_dir(mali_dir, "js_ctx_scheduling_mode", "1");
            write_val_dir(mali_dir, "scheduling/serialize_jobs", "full");
            write_val_dir(mali_dir, "power_policy", "always_on");
            write_val_dir(mali_dir, "dvfs_period", "16");
            write_val_dir(mali_dir, "js_scheduling_period", "16");
        }
    }

    // optimize_task_cgroup_nice
    change_task_cgroup("surfaceflinger", "", "cpuset");
    change_task_cgroup("system_server", "foreground", "cpuset");
    change_task_cgroup("netd|allocator", "foreground", "cpuset");
    change_task_cgroup("hardware.media.c2|vendor.mediatek.hardware", "background", "cpuset");
    change_task_cgroup("aal_sof|kfps|dsp_send_thread|vdec_ipi_recv|mtk_drm_disp_id|disp_feature|hif_thread|main_thread|rx_thread|ged_", "background", "cpuset");
    change_task_cgroup("pp_event|crtc_", "background", "cpuset");
}

void facur_main(long max_rate) {
    long max_fps = max_rate;
    if (max_fps <= 0) max_fps = 60;
    
    long vsync_ns = 1000000000 / max_fps;
    long val_e = (vsync_ns * 80) / 100;
    long val_f = (vsync_ns * 60) / 100;
    long val_g = -val_e;
    long val_h = -val_f;

    const char* props_e[] = {
        "debug.sf.early.app.duration", "debug.sf.earlyGl.app.duration",
        "debug.sf.high_fps.early.app.duration", "debug.sf.high_fps.earlyGl.app.duration",
        "debug.sf.high_fps.late.app.duration", "debug.sf.late.app.duration"
    };
    for (int i = 0; i < 6; i++) resetprop_int(props_e[i], val_e);

    const char* props_f[] = {
        "debug.sf.early.sf.duration", "debug.sf.earlyGl.sf.duration",
        "debug.sf.high_fps.early.sf.duration", "debug.sf.high_fps.earlyGl.sf.duration",
        "debug.sf.high_fps.late.sf.duration", "debug.sf.late.sf.duration"
    };
    for (int i = 0; i < 6; i++) resetprop_int(props_f[i], val_f);

    const char* props_g[] = {
        "debug.sf.earlyGl_app_phase_offset_ns", "debug.sf.early_app_phase_offset_ns",
        "debug.sf.high_fps_earlyGl_app_phase_offset_ns", "debug.sf.high_fps_early_app_phase_offset_ns",
        "debug.sf.high_fps_late_app_phase_offset_ns", "debug.sf.late_app_phase_offset_ns"
    };
    for (int i = 0; i < 6; i++) resetprop_int(props_g[i], val_g);

    const char* props_h[] = {
        "debug.sf.earlyGl_phase_offset_ns", "debug.sf.early_phase_offset_ns",
        "debug.sf.high_fps_earlyGl_phase_offset_ns", "debug.sf.high_fps_early_phase_offset_ns",
        "debug.sf.high_fps_late_phase_offset_ns", "debug.sf.late_phase_offset_ns"
    };
    for (int i = 0; i < 6; i++) resetprop_int(props_h[i], val_h);
}

void zetamin_optimize() {
    prop_f = fopen("/data/local/tmp/zeta.prop", "w");

    long max_rate = get_real_fps();
    if (max_rate > 60) {
        char cmd[256];
        snprintf(cmd, sizeof(cmd), "settings put system min_refresh_rate %ld", max_rate); system(cmd);
        snprintf(cmd, sizeof(cmd), "settings put system peak_refresh_rate %ld", max_rate); system(cmd);
        snprintf(cmd, sizeof(cmd), "settings put system user_refresh_rate %ld", max_rate); system(cmd);
        
        // Xiaomi/POCO/Redmi specific fix
        char is_xiaomi[64];
        get_cmd_output_str("getprop ro.product.brand | grep -i -E 'xiaomi|poco|redmi'", is_xiaomi, sizeof(is_xiaomi));
        if (is_xiaomi[0] == '\0') get_cmd_output_str("getprop ro.product.manufacturer | grep -i -E 'xiaomi|poco|redmi'", is_xiaomi, sizeof(is_xiaomi));
        if (is_xiaomi[0] != '\0') {
            snprintf(cmd, sizeof(cmd), "settings put secure miui_refresh_rate %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system miui_refresh_rate %ld", max_rate); system(cmd);
        }
        
        // OPlus/OnePlus/Realme specific fix to bypass Game Space
        char is_oplus[64];
        get_cmd_output_str("getprop ro.product.brand | grep -i -E 'oplus|oneplus|realme'", is_oplus, sizeof(is_oplus));
        if (is_oplus[0] == '\0') get_cmd_output_str("getprop ro.product.manufacturer | grep -i -E 'oplus|oneplus|realme'", is_oplus, sizeof(is_oplus));
        if (is_oplus[0] != '\0') {
            system("settings put system peak_refresh_rate 1");
            system("settings put system min_refresh_rate 1");
            system("settings put secure peak_refresh_rate 1");
            system("settings put secure min_refresh_rate 1");
            system("settings put system oplus_customize_screen_refresh_rate 1");
        }

        // Nubia/ZTE/Unisoc specific fix
        char is_nubia[64];
        get_cmd_output_str("getprop ro.product.brand | grep -i -E 'nubia|zte'", is_nubia, sizeof(is_nubia));
        if (is_nubia[0] != '\0') {
            if (max_rate >= 144) system("settings put system refresh_rate_mode 4");
            else if (max_rate >= 120) system("settings put system refresh_rate_mode 3");
            else if (max_rate >= 90) system("settings put system refresh_rate_mode 2");
            snprintf(cmd, sizeof(cmd), "settings put system unisoc.display_refreshrate %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put global unisoc.display_refreshrate %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system all_refresh_rate %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put global all_refresh_rate %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system ScreenRefreshRateController_resultFps %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put global ScreenRefreshRateController_resultFps %ld", max_rate); system(cmd);
        }

        // TECNO/Infinix/itel (Transsion) specific fix
        char is_transsion[64];
        get_cmd_output_str("getprop ro.product.brand | grep -i -E 'tecno|infinix|itel'", is_transsion, sizeof(is_transsion));
        if (is_transsion[0] == '\0') get_cmd_output_str("getprop ro.product.manufacturer | grep -i -E 'tecno|infinix|itel'", is_transsion, sizeof(is_transsion));
        if (is_transsion[0] != '\0') {
            // Write both Integer and Float formats just in case SettingsProvider rejects one
            snprintf(cmd, sizeof(cmd), "settings put system min_refresh_rate %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system min_refresh_rate %ld.0", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put global min_refresh_rate %ld.0", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put secure min_refresh_rate %ld.0", max_rate); system(cmd);
            
            snprintf(cmd, sizeof(cmd), "settings put system peak_refresh_rate %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system peak_refresh_rate %ld.0", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put global peak_refresh_rate %ld.0", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put secure peak_refresh_rate %ld.0", max_rate); system(cmd);
            
            snprintf(cmd, sizeof(cmd), "settings put system default_app_refresh_rate %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system other_apps_refresh_rate %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system tran_other_app_refresh_rate %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system tran_need_recovery_refresh_rate %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system tran_refresh_mode %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system tran_need_recovery_refresh_mode %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system last_tran_refresh_mode_in_refresh_setting %ld", max_rate); system(cmd);
            snprintf(cmd, sizeof(cmd), "settings put system user_refresh_rate %ld", max_rate); system(cmd);
        }

        resetprop_int("ro.surface_flinger.game_default_frame_rate_override", max_rate);
        resetprop("ro.surface_flinger.enable_frame_rate_override", "false");
    }

    resetprop("vestia.zeta.is", "Cat");

    main_flux();
    main_render(max_rate);
    facur_main(max_rate);

    if (prop_f) {
        fclose(prop_f);
        system("resetprop -f /data/local/tmp/zeta.prop");
        remove("/data/local/tmp/zeta.prop");
    }
}

#ifdef STANDALONE
int main(int argc, char *argv[]) {
    zetamin_optimize();
    return 0;
}
#endif
