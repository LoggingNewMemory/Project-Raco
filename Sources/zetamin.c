/*
Project Raco - Zetamin Gen 2
Copyright (C) 2026 Kanagawa Yamada 
*/

#include "raco.h"

// Tools
void mask_val(const char *val, const char *path) {
    if (access(path, F_OK) == 0) {
    system("touch /data/local/tmp/mount_mask");
        char cmd[256];
        snprintf(cmd, sizeof(cmd), "umount %s 2>/dev/null", path);
        system(cmd);
        
        rawrite(val, path);
        
        snprintf(cmd, sizeof(cmd), "mount --bind /data/local/tmp/mount_mask %s 2>/dev/null", path);
        system(cmd); 
    }
}

void mask_bulk(const char *base, const char *files[], int count, const char *val) {
    char path[256];
    for (int i = 0; i < count; i++) {
        snprintf(path, sizeof(path), "%s/%s", base, files[i]);
        mask_val(val, path);
    }
}

void write_bulk(const char *base, const char *files[], int count, const char *val) {
    char path[256];
    for (int i = 0; i < count; i++) {
        snprintf(path, sizeof(path), "%s/%s", base, files[i]);
        rawrite(val, path);
    }
}

void change_task_cgroup_nice() {
    // Surfaceflinger & System Server
    system("for p in $(ps -Ao pid,args | grep -iE 'surfaceflinger' | grep -v 'PID' | awk '{print $1}'); do for t in $(ls /proc/$p/task/ 2>/dev/null); do echo $t > /dev/cpuset/cpuset/tasks 2>/dev/null; done; done");
    system("for p in $(ps -Ao pid,args | grep -iE 'system_server' | grep -v 'PID' | awk '{print $1}'); do for t in $(ls /proc/$p/task/ 2>/dev/null); do echo $t > /dev/cpuset/foreground/tasks 2>/dev/null; done; done");
    
    // Background Tasks
    system("for p in $(ps -Ao pid,args | grep -iE 'hardware.media.c2|vendor.mediatek.hardware|aal_sof|kfps|dsp_send_thread|vdec_ipi_recv|mtk_drm_disp_id|disp_feature|hif_thread|main_thread|rx_thread|ged_|pp_event|crtc_' | grep -v 'PID' | awk '{print $1}'); do for t in $(ls /proc/$p/task/ 2>/dev/null); do echo $t > /dev/cpuset/background/tasks 2>/dev/null; done; done");
}

// Calculation (Facur and Flux)
void zetamin_facur() {
    int max_fps = 60;
    FILE *fp = popen("cmd display dump 2>/dev/null | grep -Eo 'fps=[0-9]+' | cut -d= -f2 | sort -nr | head -n1", "r");
    if (fp) {
        fscanf(fp, "%d", &max_fps);
        pclose(fp);
    }
    if (max_fps <= 0) max_fps = 60;

    long long vsync_ns = 1000000000LL / max_fps;
    long long val_e = (vsync_ns * 80) / 100;
    long long val_f = (vsync_ns * 60) / 100;
    char cmd[256];
    const char *props_e[] = {"debug.sf.early.app.duration", "debug.sf.earlyGl.app.duration", "debug.sf.high_fps.early.app.duration", "debug.sf.high_fps.earlyGl.app.duration", "debug.sf.high_fps.late.app.duration", "debug.sf.late.app.duration"};
    for (int i=0; i<6; i++) { snprintf(cmd, sizeof(cmd), "setprop %s %lld", props_e[i], val_e); system(cmd); }

    const char *props_f[] = {"debug.sf.early.sf.duration", "debug.sf.earlyGl.sf.duration", "debug.sf.high_fps.early.sf.duration", "debug.sf.high_fps.earlyGl.sf.duration", "debug.sf.high_fps.late.sf.duration", "debug.sf.late.sf.duration"};
    for (int i=0; i<6; i++) { snprintf(cmd, sizeof(cmd), "setprop %s %lld", props_f[i], val_f); system(cmd); }
}

void zetamin_flux() {
    system("dumpsys SurfaceFlinger --latency-clear");
    system("setprop debug.sf.prime_shader_cache.solid_layers true");
    system("setprop debug.sf.prime_shader_cache.image_layers true");
    system("setprop debug.sf.prime_shader_cache.shadow_layers true");
}

// Adreno Optimization
void optimize_adreno() {
    const char *adreno = "/sys/class/kgsl/kgsl-3d0";
    if (access(adreno, F_OK) == 0) {
        char pwr[32];
        if (raread("/sys/class/kgsl/kgsl-3d0/num_pwrlevels", pwr, sizeof(pwr)) > 0) {
            int pwr_lvl = atoi(pwr) - 1;
            char pwr_val[16];
            snprintf(pwr_val, sizeof(pwr_val), "%d", pwr_lvl);

            char path[256];
            snprintf(path, sizeof(path), "%s/default_pwrlevel", adreno); mask_val(pwr_val, path);
            snprintf(path, sizeof(path), "%s/min_pwrlevel", adreno); mask_val(pwr_val, path);
        }
        
        const char *adr_ones[] = {"bus_split", "force_clk_on", "force_no_nap", "force_rail_on"};
        mask_bulk(adreno, adr_ones, 4, "1");

        const char *adr_zeros[] = {"max_pwrlevel", "force_bus_on", "thermal_pwrlevel", "throttling", "devfreq/adrenoboost"};
        mask_bulk(adreno, adr_zeros, 5, "0");
    }
    rawrite("0", "/sys/kernel/debug/kgsl/kgsl-3d0/profiling/enable");
    rawrite("0", "/sys/module/adreno_idler/parameters/adreno_idler_active");
    rawrite("1", "/sys/module/msm_performance/parameters/touchboost");
}

// GPU Optimization
void optimize_gpu_misc() {
    // GED Parameters (MediaTek)
    const char *ged = "/sys/module/ged/parameters";
    if (access(ged, F_OK) == 0) {
        char p[256];
        snprintf(p, sizeof(p), "%s/ged_smart_boost", ged); rawrite("1000", p);
        snprintf(p, sizeof(p), "%s/boost_upper_bound", ged); rawrite("100", p);
        
        const char *ged_ones[] = {"g_gpu_timer_based_emu", "boost_gpu_enable", "ged_boost_enable", "enable_gpu_boost", "gx_game_mode", "gx_boost_on", "gx_3D_benchmark_on", "is_GED_KPI_enabled", "gpu_dvfs_enable"};
        write_bulk(ged, ged_ones, 9, "1");

        const char *ged_zeros[] = {"gpu_idle", "gx_frc_mode"};
        write_bulk(ged, ged_zeros, 2, "0");
    }

    rawrite("1", "/sys/devices/platform/gpu/dvfs_enable");
    rawrite("1", "/sys/devices/platform/gpu/gpu_busy");

    // Mali Driver
    rawrite("1", "/proc/mali/dvfs_enable");

    // PVR Settings (Tegra/Unisoc)
    const char *pvr = "/sys/module/pvrsrvkm/parameters";
    if (access(pvr, F_OK) == 0) {
        char p[256];
        snprintf(p, sizeof(p), "%s/HTBufferSizeInKB", pvr); rawrite("512", p);
        snprintf(p, sizeof(p), "%s/gpu_power", pvr); rawrite("2", p);
        snprintf(p, sizeof(p), "%s/EmuMaxFreq", pvr); rawrite("2", p);

        const char *pvr_ones[] = {"DisableClockGating", "EnableFWContextSwitch", "gpu_dvfs_enable"};
        write_bulk(pvr, pvr_ones, 3, "1");

        snprintf(p, sizeof(p), "%s/gPVRDebugLevel", pvr); rawrite("0", p);
    }

    // CPUSET Tweaks
    rawrite("0-3,4-7", "/dev/cpuset/foreground/cpus");
    rawrite("4-7", "/dev/cpuset/foreground/boost/cpus");
    rawrite("0-7", "/dev/cpuset/top-app/cpus");
}

// Executions
void zetamin_optimize() {
    system("sync");
    
    optimize_gpu_misc();
    optimize_adreno();
    change_task_cgroup_nice();
    
    zetamin_facur();
    zetamin_flux();
}

#ifdef STANDALONE
int main(int argc, char *argv[]) {
    zetamin_optimize();
    return 0;
}
#endif