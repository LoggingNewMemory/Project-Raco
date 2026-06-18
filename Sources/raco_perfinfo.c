/*
Project Raco - Real-Time FPS Counter
Copyright (C) 2026 Kanagawa Yamada 
*/

#include "raco.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <signal.h>
#include <time.h>
#include <sys/time.h>




#define MAX_LAYERS 32

typedef struct {
    char name[128];
    long long prev_frame;
    double prev_time;
} LayerFPS;

static LayerFPS tracked_layers[MAX_LAYERS];
static int layer_count = 0;

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

void pclose_dumpsys(FastPipe p) {
    if (p.fp) fclose(p.fp);
    if (p.pid > 0) {
        kill(p.pid, SIGKILL);
        waitpid(p.pid, NULL, 0);
    }
}

int get_universal_fps(const char *pkg) {
    FastPipe p = popen_dumpsys("SurfaceFlinger", NULL, NULL);
    if (!p.fp) return 0;

    char line[1024];
    char current_layer_name[128] = {0};
    int in_layer = 0;
    long long current_frame = -1;
    int active_fps = 0;

    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    double now = ts.tv_sec + ts.tv_nsec / 1e9;

    while (fgets(line, sizeof(line), p.fp)) {
        // Always check for layer boundary first before evaluating anything else
        if (strstr(line, "Layer [") || strstr(line, "+ name:") || strstr(line, "RequestedLayerState")) {
            in_layer = 0;
        }

        if (!in_layer) {
            int match_pkg = (!pkg || strlen(pkg) == 0) ? 1 : str_contains_nocase(line, pkg);
            if (match_pkg && (strstr(line, "SurfaceView") || strstr(line, "Vulkan"))) {
                
                // Ignore known non-drawing container layers
                if (strstr(line, "Background for") || strstr(line, "Bounds for")) {
                    continue;
                }

                // If no specific package is requested, ignore our own overlay and system UI
                if ((!pkg || strlen(pkg) == 0) && (str_contains_nocase(line, "com.kanagawa.yamada.project.raco") || str_contains_nocase(line, "com.android.systemui"))) {
                    continue;
                }

                in_layer = 1;
                char *start = strchr(line, '[');
                if (!start) start = strstr(line, " - ");
                if (!start) start = line;

                int len = strlen(start);
                if (len >= sizeof(current_layer_name)) len = sizeof(current_layer_name) - 1;
                strncpy(current_layer_name, start, len);
                current_layer_name[len] = '\0';
            }
        } else {
            char *frame_ptr = strstr(line, "frame=");
            if (frame_ptr) {
                if (sscanf(frame_ptr, "frame=%lld", &current_frame) == 1) {
                    int found = 0;
                    for (int i = 0; i < layer_count; i++) {
                        if (strcmp(tracked_layers[i].name, current_layer_name) == 0) {
                            found = 1;
                            double delta_t = now - tracked_layers[i].prev_time;
                            if (delta_t > 0.0 && current_frame >= tracked_layers[i].prev_frame) {
                                int fps = (int)((current_frame - tracked_layers[i].prev_frame) / delta_t);
                                if (fps > active_fps && fps <= 240) {
                                    active_fps = fps;
                                }
                            }
                            tracked_layers[i].prev_frame = current_frame;
                            tracked_layers[i].prev_time = now;
                            break;
                        }
                    }
                    if (!found) {
                        int insert_idx = layer_count;
                        if (layer_count >= MAX_LAYERS) {
                            // Find oldest layer
                            double oldest_time = now + 1000.0;
                            int oldest_idx = 0;
                            for (int i = 0; i < MAX_LAYERS; i++) {
                                if (tracked_layers[i].prev_time < oldest_time) {
                                    oldest_time = tracked_layers[i].prev_time;
                                    oldest_idx = i;
                                }
                            }
                            insert_idx = oldest_idx;
                        } else {
                            layer_count++;
                        }
                        strncpy(tracked_layers[insert_idx].name, current_layer_name, sizeof(tracked_layers[insert_idx].name) - 1);
                        tracked_layers[insert_idx].prev_frame = current_frame;
                        tracked_layers[insert_idx].prev_time = now;
                    }
                }
                in_layer = 0;
            }
        }
    }
    pclose_dumpsys(p);
    return active_fps;
}
