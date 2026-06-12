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

        if (strncmp(buffer, "NORMAL", 6) != 0 && strlen(buffer) > 0) {
            long mem_before = get_mem_available();
            char *colon = strchr(buffer, ':');
            if (colon) {
                *colon = '\0'; // split the buffer so strncmp for AWAKEN etc below works properly
            }
            kill_all();
            usleep(800000); // Wait a bit for memory to settle
            long mem_after = get_mem_available();
            long cleared = mem_after - mem_before;
            if (cleared < 0) cleared = 0;

            char toast_cmd[512];
            snprintf(toast_cmd, sizeof(toast_cmd), "su -lp 2000 -c \"am broadcast -a com.kanagawa.yamada.project.raco.SHOW_TOAST -p com.kanagawa.yamada.project.raco -e msg \\\"Ready for Game\\\"\" >/dev/null 2>&1 &");
            system(toast_cmd);
            usleep(200000); // Ensure toast intent is sent before raco mode blocks
        }

        if (strncmp(buffer, "AWAKEN", 6) == 0) {
            if (fork() == 0) {
                system("su -lp 2000 -c \"am broadcast -a com.kanagawa.yamada.project.raco.SHOW_TOAST -p com.kanagawa.yamada.project.raco -e msg \\\"Switching to Awaken Mode...\\\"\" >/dev/null 2>&1");
                system("/data/adb/modules/ProjectRaco/Compiled/raco 4 >/dev/null 2>&1");
                system("su -lp 2000 -c \"am broadcast -a com.kanagawa.yamada.project.raco.SHOW_TOAST -p com.kanagawa.yamada.project.raco -e msg \\\"Switched to Awaken Mode\\\"\" >/dev/null 2>&1");
                exit(0);
            }
        } else if (strncmp(buffer, "MID", 3) == 0) {
            if (fork() == 0) {
                system("su -lp 2000 -c \"am broadcast -a com.kanagawa.yamada.project.raco.SHOW_TOAST -p com.kanagawa.yamada.project.raco -e msg \\\"Switching to Mid Mode...\\\"\" >/dev/null 2>&1");
                system("/data/adb/modules/ProjectRaco/Compiled/raco 3 >/dev/null 2>&1");
                system("su -lp 2000 -c \"am broadcast -a com.kanagawa.yamada.project.raco.SHOW_TOAST -p com.kanagawa.yamada.project.raco -e msg \\\"Switched to Mid Mode\\\"\" >/dev/null 2>&1");
                exit(0);
            }
        } else if (strncmp(buffer, "ECO", 3) == 0) {
            if (fork() == 0) {
                system("su -lp 2000 -c \"am broadcast -a com.kanagawa.yamada.project.raco.SHOW_TOAST -p com.kanagawa.yamada.project.raco -e msg \\\"Switching to Eco Mode...\\\"\" >/dev/null 2>&1");
                system("/data/adb/modules/ProjectRaco/Compiled/raco 2 >/dev/null 2>&1");
                system("su -lp 2000 -c \"am broadcast -a com.kanagawa.yamada.project.raco.SHOW_TOAST -p com.kanagawa.yamada.project.raco -e msg \\\"Switched to Eco Mode\\\"\" >/dev/null 2>&1");
                exit(0);
            }
        } else if (strncmp(buffer, "NORMAL", 6) == 0) {
            if (fork() == 0) {
                system("su -lp 2000 -c \"am broadcast -a com.kanagawa.yamada.project.raco.SHOW_TOAST -p com.kanagawa.yamada.project.raco -e msg \\\"Restoring Normal State...\\\"\" >/dev/null 2>&1");
                system("/data/adb/modules/ProjectRaco/Compiled/raco 1 >/dev/null 2>&1");
                system("su -lp 2000 -c \"am broadcast -a com.kanagawa.yamada.project.raco.SHOW_TOAST -p com.kanagawa.yamada.project.raco -e msg \\\"Restored Normal State\\\"\" >/dev/null 2>&1");
                exit(0);
            }
        }
    }
    close(client_sock);
}

int main(int argc, char *argv[]) {
    int server_sock, client_sock;
    struct sockaddr_un server_addr, client_addr;
    socklen_t client_len = sizeof(client_addr);

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

    if (listen(server_sock, 5) < 0) {
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
