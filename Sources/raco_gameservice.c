/*
Project Raco - Game Monitoring Service
Copyright (C) 2026 Kanagawa Yamada 
*/

#include "raco.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <stddef.h>
#include <sys/wait.h>
#include <signal.h>

// Full path to the raco mode-switcher binary, built from MODDIR (argv[1])
static char raco_bin_path[512] = {0};

// Execute the raco binary with a given mode argument.
// Uses execv() directly — no shell, no environment inheritance issues.
static void exec_raco_mode(const char *mode_arg) {
    if (raco_bin_path[0] == '\0') return;

    pid_t pid = fork();
    if (pid == 0) {
        // Double-fork to fully detach from daemon so we don't block accept()
        if (fork() == 0) {
            char *args[] = {
                "/system/bin/linker64",
                raco_bin_path,
                (char *)mode_arg,
                NULL
            };
            execv("/system/bin/linker64", args);
            _exit(1);
        }
        _exit(0);
    } else if (pid > 0) {
        // Only wait for the intermediate child (which exits immediately).
        // The grandchild (actual raco exec) is detached and runs independently.
        waitpid(pid, NULL, 0);
    }
}

long get_mem_available() {
    FILE *fp = fopen("/proc/meminfo", "r");
    if (!fp) return 0;
    char line[256];
    long mem_avail = 0;
    while (fgets(line, sizeof(line), fp)) {
        if (strncmp(line, "MemAvailable:", 13) == 0) {
            sscanf(line, "MemAvailable: %ld kB", &mem_avail);
            break;
        }
    }
    fclose(fp);
    return mem_avail / 1024; // MB
}

void handle_client(int client_sock) {
    char buffer[256];
    int bytes_read = read(client_sock, buffer, sizeof(buffer) - 1);
    if (bytes_read > 0) {
        buffer[bytes_read] = '\0';

        // Ensure string is cleanly terminated
        buffer[strcspn(buffer, "\r\n")] = '\0';

        char *colon = strchr(buffer, ':');
        char *pkg = NULL;
        if (colon) {
            *colon = '\0';
            pkg = colon + 1;
        }

        if (strncmp(buffer, "AWAKEN", 6) == 0) {
            close(client_sock); // Close BEFORE exec so accept() can resume immediately
            exec_raco_mode("4");
            return;
        } else if (strncmp(buffer, "BALANCED", 8) == 0) {
            close(client_sock);
            exec_raco_mode("3");
            return;
        } else if (strncmp(buffer, "POWERSAVE", 9) == 0) {
            close(client_sock);
            exec_raco_mode("2");
            return;
        } else if (strncmp(buffer, "NORMAL", 6) == 0) {
            close(client_sock);
            exec_raco_mode("1");
            return;
        } else if (strncmp(buffer, "GET_FPS", 7) == 0) {
            int fps = get_universal_fps(pkg ? pkg : "");

            char out_buf[16];
            snprintf(out_buf, sizeof(out_buf), "%d", fps);
            write(client_sock, out_buf, strlen(out_buf));
        } else if (strncmp(buffer, "GET_PID", 7) == 0) {
            char out_buf[512] = "-1";
            if (pkg && strlen(pkg) > 0) {
                char cmd[256];
                snprintf(cmd, sizeof(cmd), "pgrep -f %s | tr '\\n' ' '", pkg);
                FILE *fp = popen(cmd, "r");
                if (fp) {
                    if (fgets(out_buf, sizeof(out_buf), fp) != NULL) {
                        out_buf[strcspn(out_buf, "\r\n")] = '\0';
                        if (strlen(out_buf) == 0) strcpy(out_buf, "-1");
                    }
                    pclose(fp);
                }
            }
            write(client_sock, out_buf, strlen(out_buf));
        }
    }
    close(client_sock);
}

int main(int argc, char *argv[]) {
    int server_sock, client_sock;
    struct sockaddr_un server_addr, client_addr;
    socklen_t client_len = sizeof(client_addr);

    // Prevent zombie children from accumulating
    signal(SIGCHLD, SIG_IGN);

    // argv[1] is MODDIR passed from service.sh
    // Build the path to raco: $MODDIR/Compiled/raco
    if (argc >= 2) {
        snprintf(raco_bin_path, sizeof(raco_bin_path), "%s/Compiled/raco", argv[1]);
    }

    // Java FPS daemon has been removed in favor of direct C implementation.
    // fps_pid check is skipped.

    server_sock = socket(AF_UNIX, SOCK_STREAM, 0);
    if (server_sock < 0) {
        return 1;
    }

    memset(&server_addr, 0, sizeof(server_addr));
    server_addr.sun_family = AF_UNIX;
    strncpy(server_addr.sun_path, GAMESERVICE_SOCKET, sizeof(server_addr.sun_path) - 1);
    server_addr.sun_path[0] = '\0'; // Use Abstract namespace

    socklen_t addr_len = offsetof(struct sockaddr_un, sun_path) + strlen(GAMESERVICE_SOCKET);
    if (bind(server_sock, (struct sockaddr *)&server_addr, addr_len) < 0) {
        return 1;
    }

    if (listen(server_sock, 10) < 0) {
        return 1;
    }

    while (1) {
        client_sock = accept(server_sock, (struct sockaddr *)&client_addr, &client_len);
        if (client_sock >= 0) {
            handle_client(client_sock);
        }
    }

    close(server_sock);
    return 0;
}
