/*
Project Raco - Real-Time FPS Counter
Copyright (C) 2026 Kanagawa Yamada 
*/

#include "raco.h"
#include <stdio.h>
#include <stdlib.h>
#include <sys/un.h>
#include <sys/socket.h>
#include <unistd.h>
#include <sys/wait.h>
#include <fcntl.h>
#include <signal.h>
#include <time.h>
#include <sys/time.h>

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
    static long long prev_frame = -1;
    static double prev_time = 0.0;
    
    FastPipe p = popen_dumpsys("SurfaceFlinger", NULL, NULL);
    if (!p.fp) return 0;

    char line[1024];
    int found_layer = 0;
    long long current_frame = -1;

    while (fgets(line, sizeof(line), p.fp)) {
        if (!found_layer) {
            if (strstr(line, "SurfaceView[") && strstr(line, "(BLAST)")) {
                if (!pkg || strlen(pkg) == 0 || strstr(line, pkg)) {
                    found_layer = 1;
                }
            }
        } else {
            char *frame_ptr = strstr(line, "frame=");
            if (frame_ptr) {
                if (sscanf(frame_ptr, "frame=%lld", &current_frame) == 1) {
                    break;
                }
            }
            if (strstr(line, "Layer [")) {
                found_layer = 0; // Missed frame=, new layer started
            }
        }
    }
    pclose_dumpsys(p);

    int fps = 0;
    if (current_frame >= 0) {
        struct timespec ts;
        clock_gettime(CLOCK_MONOTONIC, &ts);
        double now = ts.tv_sec + ts.tv_nsec / 1e9;
        
        if (prev_frame >= 0) {
            double delta_t = now - prev_time;
            if (delta_t > 0.0 && current_frame >= prev_frame) {
                fps = (int)((current_frame - prev_frame) / delta_t);
            }
        }
        prev_frame = current_frame;
        prev_time = now;
    }
    
    return fps;
}
