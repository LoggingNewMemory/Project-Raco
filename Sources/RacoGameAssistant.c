#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/inotify.h>
#include <limits.h>
#include <errno.h>
#include <poll.h>
#include <signal.h>

#define TASKS_FILE "/dev/cpuset/top-app/tasks"
#define GAME_TXT "/data/ProjectRaco/gamelist.txt"
#define EVENT_SIZE (sizeof(struct inotify_event))
#define EVENT_BUF_LEN (1024 * (EVENT_SIZE + 16))

int active_game_pid = 0;
char active_game_pkg[256] = {0};
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

int is_companion_mode() {
    FILE *f = fopen("/data/ProjectRaco/raco.txt", "r");
    if (!f) return 0;
    char line[128];
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "COMPANION_MODE 1", 16) == 0) {
            fclose(f);
            return 1;
        }
    }
    fclose(f);
    return 0;
}

void exec_performance(char *pkg) {
    pid_t pid = fork();
    if (pid == 0) {
        char cmd[1024];
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
        // Load performance mode
        snprintf(cmd, sizeof(cmd), "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco load %s %d", pkg, mode);
        system(cmd);
        
        // Tell Kotlin app to show overlay (if not Companion Mode)
        if (!is_companion_mode()) {
            snprintf(cmd, sizeof(cmd), "am startservice -a com.kanagawa.yamada.project.raco.SHOW_OVERLAY -e package \"%s\" com.kanagawa.yamada.project.raco/.GameAssistantService >/dev/null 2>&1", pkg);
            system(cmd);
        }
        exit(0);
    }
}

void exec_balance(const char *pkg) {
    pid_t pid = fork();
    if (pid == 0) {
        // Tell Kotlin app to hide overlay (if not Companion Mode)
        if (!is_companion_mode()) {
            system("am startservice -a com.kanagawa.yamada.project.raco.HIDE_OVERLAY com.kanagawa.yamada.project.raco/.GameAssistantService >/dev/null 2>&1");
        }
        
        // Unload performance mode and suspend game via RSWAP
        char cmd[512];
        snprintf(cmd, sizeof(cmd), "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco unload %s 0", pkg);
        system(cmd);
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

int get_oom_score_adj(int pid) {
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/oom_score_adj", pid);
    FILE *f = fopen(path, "r");
    if (f) {
        int score = 0;
        if (fscanf(f, "%d", &score) == 1) {
            fclose(f);
            return score;
        }
        fclose(f);
    }
    return -1;
}

int main() {
    if (daemon(0, 0) == -1) return 1;
    
    // Automatically reap child processes to prevent zombie leaks
    signal(SIGCHLD, SIG_IGN);
    
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
        // Use poll with a 500ms timeout only when a game is active
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
            int score = get_oom_score_adj(active_game_pid);
            
            // If oom_score_adj is between 0 and 300, it's foreground, visible, perceptible, or backup.
            if (score >= 0 && score <= 300) {
                continue;
            } else {
                active_game_pid = 0;
                exec_balance(active_game_pkg);
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
                                strncpy(active_game_pkg, cmdline, sizeof(active_game_pkg) - 1);
                                active_game_pkg[sizeof(active_game_pkg) - 1] = '\0';
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
