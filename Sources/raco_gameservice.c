/*
Project Raco - Game Monitoring Service (CLI Mode)
Copyright (C) 2026 Kanagawa Yamada 
*/

#include "raco.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>

int main(int argc, char *argv[]) {
    // Prevent zombie children from accumulating if we ever fork
    signal(SIGCHLD, SIG_IGN);

    if (argc >= 3 && strcmp(argv[1], "--monitor-fps") == 0) {
        const char *pkg = argv[2];
        
        while (1) {
            int fps = get_universal_fps(pkg);
            printf("%d\n", fps);
            fflush(stdout); // Crucial: fflush to ensure Java receives the output immediately
            sleep(1);
        }
        return 0;
    } else if (argc >= 3 && strcmp(argv[1], "--get-pid") == 0) {
        const char *pkg = argv[2];
        if (pkg && strlen(pkg) > 0) {
            char cmd[256];
            snprintf(cmd, sizeof(cmd), "pgrep -f %s | tr '\\n' ' '", pkg);
            FILE *fp = popen(cmd, "r");
            if (fp) {
                char out_buf[512] = "-1";
                if (fgets(out_buf, sizeof(out_buf), fp) != NULL) {
                    out_buf[strcspn(out_buf, "\r\n")] = '\0';
                    if (strlen(out_buf) == 0) strcpy(out_buf, "-1");
                    printf("%s\n", out_buf);
                }
                pclose(fp);
            }
        }
        return 0;
    } else if (argc >= 2 && strcmp(argv[1], "--get-top-app") == 0) {
        char out_buf[4096] = "";
        size_t out_len = 0;
        FILE *fp = fopen("/dev/cpuset/top-app/cgroup.procs", "r");
        if (fp) {
            int pid;
            while (fscanf(fp, "%d", &pid) == 1) {
                char cmdline_path[256];
                snprintf(cmdline_path, sizeof(cmdline_path), "/proc/%d/cmdline", pid);
                FILE *cmd_fp = fopen(cmdline_path, "r");
                if (cmd_fp) {
                    char cmd[256] = {0};
                    if (fread(cmd, 1, sizeof(cmd) - 1, cmd_fp) > 0) {
                        size_t cmd_len = strlen(cmd);
                        if (cmd_len > 0 && !strstr(out_buf, cmd)) {
                            // +1 for comma, +1 for null terminator
                            if (out_len + cmd_len + 2 < sizeof(out_buf)) {
                                if (out_len > 0) {
                                    out_buf[out_len++] = ',';
                                }
                                memcpy(out_buf + out_len, cmd, cmd_len);
                                out_len += cmd_len;
                                out_buf[out_len] = '\0';
                            }
                        }
                    }
                    fclose(cmd_fp);
                }
            }
            fclose(fp);
        }
        printf("%s\n", out_buf);
        return 0;
    }

    // Default exit if no valid arguments
    return 0;
}
