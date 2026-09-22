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

int get_tgid(int tid) {
    char path[256];
    snprintf(path, sizeof(path), "/proc/%d/status", tid);
    FILE *f = fopen(path, "r");
    if (f) {
        char line[256];
        while (fgets(line, sizeof(line), f)) {
            if (strncmp(line, "Tgid:", 5) == 0) {
                int tgid = tid;
                sscanf(line + 5, "%d", &tgid);
                fclose(f);
                return tgid;
            }
        }
        fclose(f);
    }
    return tid;
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

int is_rswap_enabled() {
    FILE *f = fopen("/data/ProjectRaco/raco.txt", "r");
    if (!f) return 0;
    char line[128];
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "RSWAP 1", 7) == 0) {
            fclose(f);
            return 1;
        }
    }
    fclose(f);
    return 0;
}

int is_playboost_enabled() {
    FILE *f = fopen("/data/ProjectRaco/raco.txt", "r");
    if (!f) return 0;
    char line[128];
    while (fgets(line, sizeof(line), f)) {
        if (strncmp(line, "RIPROG_PLAYBOOST 1", 18) == 0) {
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
            char line[256];
            // Line 1: CPU Mode
            if (fgets(line, sizeof(line), f)) {
                mode = atoi(line);
            }
            // Line 2: Ayunda RGB Values (R G B S)
            if (fgets(line, sizeof(line), f)) {
                float r, g, b, s;
                if (sscanf(line, "%f %f %f %f", &r, &g, &b, &s) == 4) {
                    char sf_cmd[512];
                    snprintf(sf_cmd, sizeof(sf_cmd), "touch /data/ProjectRaco/ayunda_active ; service call SurfaceFlinger 1015 i32 1 f %f f 0 f 0 f 0 f 0 f %f f 0 f 0 f 0 f 0 f %f f 0 f 0 f 0 f 0 f 1 ; service call SurfaceFlinger 1022 f %f", r, g, b, s);
                    system(sf_cmd);
                }
            }
            fclose(f);
        }
        // Load performance mode
        snprintf(cmd, sizeof(cmd), "/system/bin/linker64 /data/adb/modules/ProjectRaco/Compiled/raco load %s %d", pkg, mode);
        system(cmd);

        if (is_playboost_enabled()) {
            snprintf(cmd, sizeof(cmd), "pid=$(pgrep -f %s | head -n 1); if [ -n \"$pid\" ]; then for task in /proc/$pid/task/*; do tid=$(basename $task); taskset -p ffffffff $tid; done; fi", pkg);
            system(cmd);
        }
        
        // Tell Kotlin app to show overlay (if not Companion Mode)
        if (!is_companion_mode()) {
            snprintf(cmd, sizeof(cmd), "cmd activity start-service --user current -e package \"%s\" com.kanagawa.yamada.project.raco/.GameAssistantService >/dev/null 2>&1", pkg);
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
            char cmd[512];
            snprintf(cmd, sizeof(cmd), "am force-stop com.kanagawa.yamada.project.raco >/dev/null 2>&1");
            system(cmd);
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
    return -9999;
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

    int pending_check = 0;

    while (1) {
        // Use poll with a 500ms timeout when active, 100ms when waiting for init, 2000ms fallback
        struct pollfd pfd = {fd, POLLIN, 0};
        int timeout = (active_game_pid != 0) ? 500 : (pending_check ? 100 : 2000);
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
            
            // If oom_score_adj is <= 300, it's foreground, visible, or we boosted it to -1000.
            if (score != -9999 && score <= 300) {
                continue;
            } else {
                // Check if another process of the same game took over foreground
                int handed_over = 0;
                FILE *tasks_file = fopen(TASKS_FILE, "r");
                if (tasks_file) {
                    int pid;
                    while (fscanf(tasks_file, "%d", &pid) > 0) {
                        char cmdline[256];
                        get_cmdline(pid, cmdline, sizeof(cmdline));
                        if (strlen(cmdline) > 0) {
                            char base_pkg[256];
                            strncpy(base_pkg, cmdline, sizeof(base_pkg));
                            base_pkg[sizeof(base_pkg) - 1] = '\0';
                            char *colon = strchr(base_pkg, ':');
                            if (colon) *colon = '\0';

                            if (strcmp(base_pkg, active_game_pkg) == 0) {
                                int tgid = get_tgid(pid);
                                int new_score = get_oom_score_adj(tgid);
                                if (new_score != -9999 && new_score <= 300) {
                                    active_game_pid = tgid;
                                    handed_over = 1;
                                    break;
                                }
                            }
                        }
                    }
                    fclose(tasks_file);
                }
                
                if (handed_over) {
                    continue;
                }
                
                active_game_pid = 0;
                exec_balance(active_game_pkg);
            }
        }

        if (active_game_pid == 0) {
            load_gamelist();
            int found = 0;
            pending_check = 0;
            
            FILE *tasks_file = fopen(TASKS_FILE, "r");
            if (tasks_file) {
                int pid;
                while (fscanf(tasks_file, "%d", &pid) > 0) {
                    char cmdline[256];
                    get_cmdline(pid, cmdline, sizeof(cmdline));
                    if (strlen(cmdline) > 0) {
                        if (strstr(cmdline, "zygote") != NULL || strstr(cmdline, "<pre-initialized>") != NULL) {
                            pending_check = 1;
                        } else {
                            char base_pkg[256];
                            strncpy(base_pkg, cmdline, sizeof(base_pkg));
                            base_pkg[sizeof(base_pkg) - 1] = '\0';
                            char *colon = strchr(base_pkg, ':');
                            if (colon) *colon = '\0';

                            if (check_game_in_memory(base_pkg)) {
                                int tgid = get_tgid(pid);
                                int score = get_oom_score_adj(tgid);
                                
                                // Prevent infinite loops: only activate if the game is genuinely in the foreground (score <= 300).
                                if (score != -9999 && score <= 300) {
                                    active_game_pid = tgid;
                                    strncpy(active_game_pkg, base_pkg, sizeof(active_game_pkg) - 1);
                                    active_game_pkg[sizeof(active_game_pkg) - 1] = '\0';
                                    exec_performance(base_pkg);
                                    found = 1;
                                    break;
                                }
                            }
                        }
                    }
                }
                fclose(tasks_file);
            }
        }
    }

    inotify_rm_watch(fd, wd);
    close(fd);
    return 0;
}
