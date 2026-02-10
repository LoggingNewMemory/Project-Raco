#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

// Define constants for file paths and buffer size
#define GAME_LIST "/data/ProjectRaco/game.txt"
#define CONFIG_FILE "/data/ProjectRaco/raco.txt"
#define RACO_SCRIPT "/data/adb/modules/ProjectRaco/Scripts/Raco.sh"
#define BUFFER_SIZE 1024

#define MODE_POWERSAVE "3" 
#define MODE_GAME "1"      
#define MODE_NORMAL "2"    

// Enum to track the last executed state
typedef enum {
    EXEC_NONE,
    EXEC_POWERSAVE,
    EXEC_GAME,
    EXEC_NORMAL
} ExecType;

// Helper function to check if a file exists
bool file_exists(const char *filename) {
    return access(filename, F_OK) == 0;
}

// Helper function to execute a shell command and retrieve output
void execute_cmd(const char *cmd, char *buffer, size_t size) {
    FILE *fp = popen(cmd, "r");
    if (fp) {
        if (fgets(buffer, size, fp) != NULL) {
            // Remove trailing newline
            buffer[strcspn(buffer, "\n")] = '\0';
        } else {
            buffer[0] = '\0'; 
        }
        pclose(fp);
    } else {
        buffer[0] = '\0';
    }
}

// Helper function to read integer config values from raco.txt
void get_config_int(const char *key, int *target) {
    FILE *fp = fopen(CONFIG_FILE, "r");
    if (!fp) return;

    char line[256];
    size_t key_len = strlen(key);

    while (fgets(line, sizeof(line), fp)) {
        // Simple parser: key=value
        if (strncmp(line, key, key_len) == 0 && line[key_len] == '=') {
            *target = atoi(line + key_len + 1);
            break; 
        }
    }

    fclose(fp);
}

int main(void) {
    // Fail silently if game list not found
    if (!file_exists(GAME_LIST)) {
        return 1;
    }

    ExecType last_executed = EXEC_NONE;
    char buffer[BUFFER_SIZE]; 
    int delay_seconds = 2;

    // --- DEFAULTS ---
    int conf_enable_powersave = 1;

    while (1) {
        // --- 0. Read Config Dynamically ---
        // Reads 'ENDFIELD_ENABLE_POWERSAVE' every loop iteration.
        // If you change the file, it updates immediately without restart.
        get_config_int("ENDFIELD_ENABLE_POWERSAVE", &conf_enable_powersave);

        // --- 1. Screen State Detection ---
        bool current_screen_on = false;
        
        execute_cmd("cmd deviceidle get screen", buffer, sizeof(buffer));
        if (strstr(buffer, "true") != NULL) {
            current_screen_on = true;
        }

        // Adjust delay based on screen state
        if (current_screen_on) {
            delay_seconds = 2;
        } else {
            delay_seconds = 3;
        }

        // --- 2. Determine Target State ---
        ExecType target_state = EXEC_NONE;
        const char* target_mode_arg = "";

        if (!current_screen_on) {
            // --- SCREEN OFF LOGIC ---
            if (conf_enable_powersave == 1) {
                // Config enabled: Enter Powersave
                target_state = EXEC_POWERSAVE;
                target_mode_arg = MODE_POWERSAVE;
            } else {
                // Config disabled: Stay Normal
                // Since we were presumably already Normal before screen off,
                // last_executed checks will prevent re-execution.
                target_state = EXEC_NORMAL;
                target_mode_arg = MODE_NORMAL;
            }
        } else {
            // --- SCREEN ON LOGIC ---
            bool is_game_running = false;
            char package_name[BUFFER_SIZE] = "";
            
            // Scan visible apps
            const char *visible_apps_cmd = "cmd activity stack list | sed -n '/visible=true/{s/.*://;s:/.*::;s/^[ \t]*//;p}'";

            FILE *fp_apps = popen(visible_apps_cmd, "r");
            if (fp_apps) {
                while (fgets(package_name, sizeof(package_name), fp_apps) != NULL) {
                    package_name[strcspn(package_name, "\n")] = '\0';
                    if (strlen(package_name) > 0) {
                        char grep_command[BUFFER_SIZE];
                        snprintf(grep_command, sizeof(grep_command), "grep -qFx \"%s\" %s", package_name, GAME_LIST);

                        if (system(grep_command) == 0) {
                            is_game_running = true;
                            break; 
                        }
                    }
                }
                pclose(fp_apps);
            }

            if (is_game_running) {
                target_state = EXEC_GAME;
                target_mode_arg = MODE_GAME;
            } else {
                target_state = EXEC_NORMAL;
                target_mode_arg = MODE_NORMAL;
            }
        }
        
        if (last_executed != target_state) {
            char command[BUFFER_SIZE];
            snprintf(command, sizeof(command), "sh %s %s", RACO_SCRIPT, target_mode_arg);
            system(command);
            
            last_executed = target_state;
        }

        sleep(delay_seconds);
    }

    return 0;
}