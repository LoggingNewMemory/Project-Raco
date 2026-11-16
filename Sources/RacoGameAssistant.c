/*
 * Project Raco - Performance and Gaming Optimization Suite
 * Copyright (C) 2026 Kanagawa Yamada <albert.wesley.dion@gmail.com>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

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
#include <sys/stat.h>
#include <time.h>

#define TASKS_FILE "/dev/cpuset/top-app/tasks"
#define PROCS_FILE "/dev/cpuset/top-app/cgroup.procs"
#define GAME_TXT "/data/ProjectRaco/gamelist.txt"
#define EVENT_SIZE (sizeof(struct inotify_event))
#define EVENT_BUF_LEN (1024 * (EVENT_SIZE + 16))

int active_game_pid = 0;
char active_game_pkg[256] = {0};

// The gamelist used to be opened and re-read once per process per scan. Cache it
// and only reload when the file changes on disk.
static char gamelist_cache[65536];
static size_t gamelist_len = 0;
static struct timespec gamelist_mtim = {0, 0};
static off_t gamelist_size = -1;

static long long now_ms(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (long long)ts.tv_sec * 1000LL + ts.tv_nsec / 1000000LL;
}

static void refresh_gamelist(void) {
    struct stat st;
    if (stat(GAME_TXT, &st) != 0) {
        gamelist_len = 0;
        return;
    }
    // Compare nanosecond mtime + size: two edits inside the same second must not be missed.
    if (st.st_mtim.tv_sec == gamelist_mtim.tv_sec && st.st_mtim.tv_nsec == gamelist_mtim.tv_nsec &&
        st.st_size == gamelist_size) return;
    FILE *f = fopen(GAME_TXT, "r");
    if (!f) return;
    gamelist_len = fread(gamelist_cache, 1, sizeof(gamelist_cache) - 1, f);
    gamelist_cache[gamelist_len] = '\0';
    fclose(f);
    gamelist_mtim = st.st_mtim;
    gamelist_size = st.st_size;
}

// Same semantics as check_game_in_memory (RacoGameAssistantLibrary.s): a package matches
// only when it equals a whole line ('\n' or '\r' terminated). A plain strstr() would also
// match prefixes/substrings, e.g. "com.dts.freefire" against the line "com.dts.freefiremax".
static int game_in_list(const char *pkg) {
    if (!pkg || !*pkg || gamelist_len == 0) return 0;
    size_t plen = strlen(pkg);
    const char *p = gamelist_cache;
    const char *end = gamelist_cache + gamelist_len;
    while (p < end) {
        const char *eol = p;
        while (eol < end && *eol != '\n' && *eol != '\r') eol++;
        if ((size_t)(eol - p) == plen && memcmp(p, pkg, plen) == 0) return 1;
        p = eol + 1;
    }
    return 0;
}

// cgroup v1 cgroup.procs lists every TGID with at least one thread in the cgroup, so it
// yields the same processes as walking "tasks" (one line per thread) at ~1/10 the work.
static FILE *open_top_app_list(void) {
    FILE *f = fopen(PROCS_FILE, "r");
    return f ? f : fopen(TASKS_FILE, "r");
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
        
        if (!is_companion_mode()) {
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
        
        system("if [ -f /data/ProjectRaco/ayunda_active ]; then sh /data/ProjectRaco/AyundaRusdi.sh >/dev/null 2>&1; rm -f /data/ProjectRaco/ayunda_active; fi &");
        
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
    long long last_scan_ms = 0;

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

        // The cpuset file is modified continuously, so every event used to trigger a
        // full rescan of ~500 entries. Coalesce events instead of scanning per event;
        // scan at most every 1.5s while idle, 400ms while a game is being watched.
        long long now = now_ms();
        long long scan_interval = (active_game_pid != 0) ? 400 : 1500;
        if (now - last_scan_ms < scan_interval) continue;
        last_scan_ms = now;
        refresh_gamelist();

        if (active_game_pid != 0) {
            int score = get_oom_score_adj(active_game_pid);
            
            // If oom_score_adj is <= 300, it's foreground, visible, or we boosted it to -1000.
            if (score != -9999 && score <= 300) {
                continue;
            } else {
                // Check if another process of the same game took over foreground
                int handed_over = 0;
                FILE *tasks_file = open_top_app_list();
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
            int found = 0;
            pending_check = 0;
            
            FILE *tasks_file = open_top_app_list();
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

                            if (game_in_list(base_pkg)) {
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
