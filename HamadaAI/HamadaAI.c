#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>
#include <ctype.h>

#define GAME_LIST "/data/ProjectRaco/game.txt"
#define CONFIG_FILE "/data/ProjectRaco/raco.txt"
#define RACO_SCRIPT "/data/adb/modules/ProjectRaco/Scripts/Raco.sh"
#define BUFFER_SIZE 1024

#define MODE_POWERSAVE "3" 
#define MODE_GAME "1"      
#define MODE_NORMAL "2"    

typedef enum {
    EXEC_NONE,
    EXEC_POWERSAVE,
    EXEC_GAME,
    EXEC_NORMAL
} ExecType;

bool file_exists(const char *filename) {
    return access(filename, F_OK) == 0;
}

void get_config_int(const char *key, int *target) {
    FILE *fp = fopen(CONFIG_FILE, "r");
    if (!fp) return;

    char line[256];
    size_t key_len = strlen(key);

    while (fgets(line, sizeof(line), fp)) {
        char *ptr = line;
        
        while (*ptr && isspace((unsigned char)*ptr)) ptr++;

        if (strncmp(ptr, key, key_len) == 0 && ptr[key_len] == '=') {
            *target = atoi(ptr + key_len + 1);
            break; 
        }
    }

    fclose(fp);
}

bool is_screen_on() {
    char buffer[128];
    FILE *fp = popen("dumpsys window policy | grep mScreenOn=true", "r");
    bool screen_on = false;

    if (fp) {
        if (fgets(buffer, sizeof(buffer), fp) != NULL) {
            if (strstr(buffer, "mScreenOn=true") != NULL) {
                screen_on = true;
            }
        }
        pclose(fp);
    }
    return screen_on;
}

bool check_game_running() {
    bool is_game = false;
    char line[BUFFER_SIZE];
    char grep_command[BUFFER_SIZE];
    
    const char *visible_apps_cmd = "cmd activity stack list | sed -n '/visible=true/{s/.*://;s:/.*::;s/^[ \t]*//;p}'";

    FILE *fp = popen(visible_apps_cmd, "r");
    if (!fp) return false;

    while (fgets(line, sizeof(line), fp)) {
        line[strcspn(line, "\n")] = '\0';
        
        if (strlen(line) > 0) {
            snprintf(grep_command, sizeof(grep_command), "grep -qFx \"%s\" %s", line, GAME_LIST);
            
            if (system(grep_command) == 0) {
                printf("Game detected (Visible): %s\n", line);
                is_game = true;
                break;
            }
        }
    }
    pclose(fp);
    return is_game;
}

int main(void) {
    if (!file_exists(GAME_LIST)) {
        fprintf(stderr, "Error: %s not found\n", GAME_LIST);
        return 1;
    }

    bool prev_screen_on = true;
    ExecType last_executed = EXEC_NONE;
    int delay_seconds = 5;

    int conf_enable_powersave = 1;
    int conf_loop_normal = 5;
    int conf_loop_off = 7;

    while (1) {
        get_config_int("HAMADA_ENABLE_POWERSAVE", &conf_enable_powersave);
        get_config_int("HAMADA_LOOP", &conf_loop_normal);
        get_config_int("HAMADA_LOOP_OFF", &conf_loop_off);

        bool current_screen_on = is_screen_on();

        if (current_screen_on) {
            delay_seconds = conf_loop_normal;
        } else {
            delay_seconds = conf_loop_off;
        }

        if (current_screen_on != prev_screen_on) {
            printf("Screen state changed: %s. New interval: %d seconds\n", 
                   current_screen_on ? "ON" : "OFF", delay_seconds);
            prev_screen_on = current_screen_on;
        }

        ExecType target_state = EXEC_NONE;
        const char* target_mode_arg = "";
        const char* target_mode_name = "";

        if (!current_screen_on) {
            if (conf_enable_powersave == 1) {
                target_state = EXEC_POWERSAVE;
                target_mode_arg = MODE_POWERSAVE;
                target_mode_name = "Powersave";
            } else {
                target_state = EXEC_NORMAL;
                target_mode_arg = MODE_NORMAL;
                target_mode_name = "Normal (Powersave Disabled)";
            }
        } else {
            if (check_game_running()) {
                target_state = EXEC_GAME;
                target_mode_arg = MODE_GAME;
                target_mode_name = "Game";
            } else {
                target_state = EXEC_NORMAL;
                target_mode_arg = MODE_NORMAL;
                target_mode_name = "Normal";
            }
        }

        if (last_executed != target_state) {
            printf("Applying %s profile (Mode %s)...\n", target_mode_name, target_mode_arg);
            char command[BUFFER_SIZE];
            
            snprintf(command, sizeof(command), "sh %s %s", RACO_SCRIPT, target_mode_arg);
            system(command);
            
            last_executed = target_state;
        }

        sleep(delay_seconds);
    }

    return 0;
}