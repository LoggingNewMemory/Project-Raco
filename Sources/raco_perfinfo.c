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
    int fps = 0;
    int sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (sock < 0) return 0;
    
    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(&addr.sun_path[1], "raco_fps_daemon", sizeof(addr.sun_path) - 2);
    
    if (connect(sock, (struct sockaddr*)&addr, sizeof(sa_family_t) + strlen("raco_fps_daemon") + 1) == 0) {
        write(sock, "GET_FPS", 7);
        char buf[16] = {0};
        int bytes = read(sock, buf, sizeof(buf) - 1);
        if (bytes > 0) {
            fps = atoi(buf);
        }
    }
    close(sock);
    return fps;
}
