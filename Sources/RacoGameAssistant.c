#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/inotify.h>
#include <limits.h>
#include <errno.h>
#include <poll.h>

#define TASKS_FILE "/dev/cpuset/top-app/tasks"
#define GAME_TXT "/data/ProjectRaco/gamelist.txt"
#define EVENT_SIZE (sizeof(struct inotify_event))
#define EVENT_BUF_LEN (1024 * (EVENT_SIZE + 16))

int active_game_pid = 0;
char gamelist[1024][128];
int game_count = 0;

void load_gamelist() {
    game_count = 0;
    FILE *f = fopen(GAME_TXT, "r");
    if (f) {
        char line[128];
        while (fgets(line, sizeof(line), f) && game_count < 1024) {
            line[strcspn(line, "\r\n")] = 0;
            if (strlen(line) > 0) {
                strcpy(gamelist[game_count++], line);
            }
        }
        fclose(f);
    }
}

int check_game_in_memory(const char *cmdline) {
    for (int i = 0; i < game_count; i++) {
        if (strcmp(cmdline, gamelist[i]) == 0) {
            return 1;
        }
    }
    return 0;
}

void exec_performance(char *pkg) {
    pid_t pid = fork();
    if (pid == 0) {
        char cmd[512];
        int mode = 4;
        char path[256];
        snprintf(path, sizeof(path), "/data/ProjectRaco/modes/%s", pkg);
        FILE *f = fopen(path, "r");
        if (f) {
            char val[16];
            if (fgets(val, sizeof(val), f)) {
                mode = atoi(val);
            }
            fclose(f);
        }
        snprintf(cmd, sizeof(cmd), "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco load %s %d", pkg, mode);
        system(cmd);
        exit(0);
    }
}

void exec_balance(void) {
    pid_t pid = fork();
    if (pid == 0) {
        system("/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco unload auto 0");
        exit(0);
    }
}

void get_cmdline(int pid, char *cmdline, size_t size) {
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/cmdline", pid);
    FILE *f = fopen(path, "r");
    if (f) {
        if (fgets(cmdline, size, f) != NULL) {
            cmdline[strcspn(cmdline, "\n")] = 0;
        } else {
            cmdline[0] = '\0';
        }
        fclose(f);
    } else {
        cmdline[0] = '\0';
    }
}

int get_cpuset(int pid, char *cpuset, size_t size) {
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/cgroup", pid);
    FILE *f = fopen(path, "r");
    if (f) {
        char line[256];
        while (fgets(line, sizeof(line), f)) {
            if (strstr(line, "cpuset")) {
                strncpy(cpuset, line, size);
                fclose(f);
                return 1;
            }
        }
        fclose(f);
    }
    return 0;
}

int main() {
    if (daemon(0, 0) == -1) return 1;
    
    int fd = inotify_init();
    if (fd < 0) {
        perror("inotify_init");
        return 1;
    }

    int wd = inotify_add_watch(fd, TASKS_FILE, IN_MODIFY);
    if (wd < 0) {
        perror("inotify_add_watch");
        return 1;
    }

    char buffer[EVENT_BUF_LEN];

    while (1) {
        struct pollfd pfd = {fd, POLLIN, 0};
        int timeout = (active_game_pid != 0) ? 500 : -1;
        int ready = poll(&pfd, 1, timeout);

        if (ready < 0) {
            if (errno == EINTR) continue;
            perror("poll");
            break;
        }

        if (ready > 0) {
            int length = read(fd, buffer, EVENT_BUF_LEN);
            if (length < 0) {
                if (errno == EINTR) continue;
                perror("read");
                break;
            }
        }

        if (active_game_pid != 0) {
            char cpuset[256] = {0};
            int ret = get_cpuset(active_game_pid, cpuset, sizeof(cpuset));
            
            if (ret && strstr(cpuset, "top-app")) {
                continue;
            } else {
                active_game_pid = 0;
                exec_balance();
            }
        }

        if (active_game_pid == 0) {
            // Load the gamelist into memory ONCE per trigger event instead of per PID
            load_gamelist();
            
            int retry = 0;
            int found = 0;
            
            // 40 retries * 50ms = 2.0 seconds total wait time, but 4x faster polling
            while (retry < 40 && !found) {
                FILE *tasks_file = fopen(TASKS_FILE, "r");
                if (tasks_file) {
                    int pid;
                    while (fscanf(tasks_file, "%d", &pid) > 0) {
                        char cmdline[256];
                        get_cmdline(pid, cmdline, sizeof(cmdline));
                        if (strlen(cmdline) > 0 && strstr(cmdline, "zygote") == NULL && strstr(cmdline, "<pre-initialized>") == NULL) {
                            if (check_game_in_memory(cmdline)) {
                                active_game_pid = pid;
                                exec_performance(cmdline);
                                found = 1;
                                break;
                            }
                        }
                    }
                    fclose(tasks_file);
                }
                if (!found) {
                    usleep(50000); 
                    retry++;
                }
            }
        }
    }

    inotify_rm_watch(fd, wd);
    close(fd);
    return 0;
}
