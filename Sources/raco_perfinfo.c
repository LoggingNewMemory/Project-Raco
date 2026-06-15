/*
Project Raco - Real-Time FPS Counter
Copyright (C) 2026 Kanagawa Yamada 
*/

#include "raco.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>

int str_contains_nocase(const char *haystack, const char *needle) {
    if (!haystack || !needle) return 0;
    size_t h_len = strlen(haystack);
    size_t n_len = strlen(needle);
    if (n_len == 0) return 1;
    if (h_len < n_len) return 0;
    for (size_t i = 0; i <= h_len - n_len; i++) {
        if (strncasecmp(haystack + i, needle, n_len) == 0) return 1;
    }
    return 0;
}

typedef struct {
    FILE *fp;
    pid_t pid;
} FastPipe;

FastPipe popen_dumpsys(const char *arg1, const char *arg2, const char *arg3) {
    FastPipe p = {NULL, -1};
    int fd[2];
    if (pipe(fd) < 0) return p;
    pid_t pid = fork();
    if (pid == 0) {
        close(fd[0]);
        dup2(fd[1], STDOUT_FILENO);
        close(fd[1]);
        
        int null_fd = open("/dev/null", O_WRONLY);
        if (null_fd >= 0) {
            dup2(null_fd, STDERR_FILENO);
            close(null_fd);
        }

        if (arg3) {
            execl("/system/bin/dumpsys", "dumpsys", arg1, arg2, arg3, NULL);
        } else if (arg2) {
            execl("/system/bin/dumpsys", "dumpsys", arg1, arg2, NULL);
        } else {
            execl("/system/bin/dumpsys", "dumpsys", arg1, NULL);
        }
        exit(1);
    }
    close(fd[1]);
    p.fp = fdopen(fd[0], "r");
    p.pid = pid;
    return p;
}

#include <signal.h>
#include <time.h>

void pclose_dumpsys(FastPipe p) {
    if (p.fp) fclose(p.fp);
    if (p.pid > 0) {
        kill(p.pid, SIGKILL);
        waitpid(p.pid, NULL, 0);
    }
}

static char cached_layer_name[256] = {0};
static time_t last_full_check = 0;

int get_universal_fps(const char *pkg) {
    time_t now = time(NULL);

    if (cached_layer_name[0] != '\0') {
        FastPipe fp = popen_dumpsys("SurfaceFlinger", "--latency", cached_layer_name);
        if (fp.fp) {
            char line[256];
            long long timestamps[128];
            int ts_count = 0;
            long long latest = 0;
            if (fgets(line, sizeof(line), fp.fp)) {
                long long t1, t2, t3;
                while (fgets(line, sizeof(line), fp.fp) && ts_count < 128) {
                    if (sscanf(line, "%lld\t%lld\t%lld", &t1, &t2, &t3) == 3) {
                        if (t2 != 0 && t2 != 9223372036854775807LL) {
                            timestamps[ts_count++] = t2;
                            if (t2 > latest) latest = t2;
                        }
                    }
                }
            }
            pclose_dumpsys(fp);
            if (ts_count > 0 && latest > 0) {
                long long cutoff = latest - 1000000000LL;
                int layer_fps = 0;
                for (int i = 0; i < ts_count; i++) {
                    if (timestamps[i] > cutoff) {
                        layer_fps++;
                    }
                }
                if (layer_fps > 0) {
                    return layer_fps > 144 ? 144 : layer_fps;
                }
            }
        }
        cached_layer_name[0] = '\0';
    }

    if (now - last_full_check < 2) {
        return 0;
    }
    last_full_check = now;

    char current_pkg[256] = {0};

    if (pkg == NULL || pkg[0] == '\0' || strcmp(pkg, "SurfaceView") == 0) {
        FastPipe fp_focus = popen_dumpsys("window", "displays", NULL);
        if (fp_focus.fp) {
            char focus_line[512];
            while (fgets(focus_line, sizeof(focus_line), fp_focus.fp)) {
                if (strstr(focus_line, "mCurrentFocus")) {
                    char *slash = strchr(focus_line, '/');
                    if (slash) {
                        *slash = '\0';
                        char *space = strrchr(focus_line, ' ');
                        if (space) {
                            strncpy(current_pkg, space + 1, sizeof(current_pkg) - 1);
                        }
                    }
                    break;
                }
            }
            pclose_dumpsys(fp_focus);
        }
        
        if (current_pkg[0] != '\0') {
            pkg = current_pkg;
        } else {
            pkg = "SurfaceView";
        }
    }

    FastPipe fp_list = popen_dumpsys("SurfaceFlinger", "--list", NULL);
    if (!fp_list.fp) return 0;

    int max_fps = 0;
    char layer_name[256];

    while (fgets(layer_name, sizeof(layer_name), fp_list.fp)) {
        layer_name[strcspn(layer_name, "\r\n")] = '\0';
        if (layer_name[0] == '\0') continue;
        if (!str_contains_nocase(layer_name, pkg)) continue;

        if (strncmp(layer_name, "RequestedLayerState{", 20) == 0) {
            char *start = layer_name + 20;
            char *end = strrchr(start, '}');
            if (end) *end = '\0';
            
            char *suffix = strstr(start, " parentId=");
            if (suffix) *suffix = '\0';
            suffix = strstr(start, " relativeParentId=");
            if (suffix) *suffix = '\0';
            suffix = strstr(start, " z=");
            if (suffix) *suffix = '\0';
            suffix = strstr(start, " !handle");
            if (suffix) *suffix = '\0';
            
            memmove(layer_name, start, strlen(start) + 1);
        }

        FastPipe fp = popen_dumpsys("SurfaceFlinger", "--latency", layer_name);
        if (!fp.fp) continue;

        char line[256];
        long long timestamps[128];
        int ts_count = 0;
        long long latest = 0;

        if (fgets(line, sizeof(line), fp.fp)) { // skip refresh period
            long long t1, t2, t3;
            while (fgets(line, sizeof(line), fp.fp) && ts_count < 128) {
                if (sscanf(line, "%lld\t%lld\t%lld", &t1, &t2, &t3) == 3) {
                    if (t2 != 0 && t2 != 9223372036854775807LL) {
                        timestamps[ts_count++] = t2;
                        if (t2 > latest) latest = t2;
                    }
                }
            }
        }
        pclose_dumpsys(fp);

        if (ts_count > 0 && latest > 0) {
            long long cutoff = latest - 1000000000LL;
            int layer_fps = 0;
            for (int i = 0; i < ts_count; i++) {
                if (timestamps[i] > cutoff) {
                    layer_fps++;
                }
            }
            if (layer_fps > max_fps) {
                max_fps = layer_fps;
                strncpy(cached_layer_name, layer_name, sizeof(cached_layer_name) - 1);
            }
        }
    }
    pclose_dumpsys(fp_list);

    if (max_fps > 144) max_fps = 144;
    return max_fps;
}
