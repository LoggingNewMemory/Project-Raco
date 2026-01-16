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
            buffer[0] = '\0'; // Empty string if no output
        }
        pclose(fp);
    } else {
        buffer[0] = '\0';
    }
}

// Helper function to read integer config values from raco.txt
// Returns default_val if key not found or file error
int get_config_int(const char *key, int default_val) {
    FILE *fp = fopen(CONFIG_FILE, "r");
    if (!fp) return default_val;

    char line[256];
    int value = default_val;
    size_t key_len = strlen(key);

    while (fgets(line, sizeof(line), fp)) {
        // Look for lines starting with key
        if (strncmp(line, key, key_len) == 0 && line[key_len] == '=') {
            // Parse the integer after the '='
            value = atoi(line + key_len + 1);
            break; 
        }
    }

    fclose(fp);
    return value;
}

int main(void) {
    // Check for game.txt at startup
    if (!file_exists(GAME_LIST)) {
        fprintf(stderr, "Error: %s not found\n", GAME_LIST);
        return 1;
    }

    bool prev_screen_on = true;
    ExecType last_executed = EXEC_NONE;
    int delay_seconds = 5;
    char buffer[BUFFER_SIZE]; 

    while (1) {
        // --- 0. Read Config ---
        // Read configuration dynamically to allow live updates
        int conf_enable_powersave = get_config_int("HAMADA_ENABLE_POWERSAVE", 1);
        int conf_loop_normal = get_config_int("HAMADA_LOOP", 5);
        int conf_loop_off = get_config_int("HAMADA_LOOP_OFF", 7);

        // --- 1. Screen State Detection ---
        bool current_screen_on = false;
        
        // Check screen state
        execute_cmd("cmd deviceidle get screen", buffer, sizeof(buffer));

        if (strstr(buffer, "true") != NULL) {
            current_screen_on = true;
        }

        // Adjust delay based on screen state and config
        if (current_screen_on) {
            delay_seconds = conf_loop_normal;
        } else {
            delay_seconds = conf_loop_off;
        }

        // Log only on state transition to avoid spamming logcat
        if (current_screen_on != prev_screen_on) {
            printf("Screen state changed. New interval: %d seconds\n", delay_seconds);
            prev_screen_on = current_screen_on;
        }

        // --- 2. Determine Target State ---
        ExecType target_state = EXEC_NONE;
        const char* target_mode_arg = "";
        const char* target_mode_name = "";

        if (!current_screen_on) {
            // Priority 1: Screen OFF
            if (conf_enable_powersave == 1) {
                target_state = EXEC_POWERSAVE;
                target_mode_arg = MODE_POWERSAVE;
                target_mode_name = "Powersave";
            } else {
                // If powersave is disabled on screen off, treat as Normal (or maintain current if game was running? 
                // usually 'Normal' is safer to ensure we don't get stuck in high perf mode if screen goes off)
                target_state = EXEC_NORMAL;
                target_mode_arg = MODE_NORMAL;
                target_mode_name = "Normal (Powersave Disabled)";
            }
        } else {
            // Priority 2: Screen ON, check for Games
            bool is_game_running = false;
            char package_name[BUFFER_SIZE] = "";
            
            // Optimized command to get the top visible activity's package
            const char *focused_app_cmd = "cmd activity stack list | sed -n '/visible=true/{s/.*://;s:/.*::;s/^[ \t]*//;p;q}'";

            execute_cmd(focused_app_cmd, package_name, sizeof(package_name));

            if (strlen(package_name) > 0) {
                char grep_command[BUFFER_SIZE];
                // Efficient grep to check if package is in game.txt
                snprintf(grep_command, sizeof(grep_command), "grep -qFx \"%s\" %s", package_name, GAME_LIST);

                if (system(grep_command) == 0) {
                    is_game_running = true;
                    printf("Game package detected: %s\n", package_name);
                }
            }

            if (is_game_running) {
                target_state = EXEC_GAME;
                target_mode_arg = MODE_GAME;
                target_mode_name = "Game";
            } else {
                target_state = EXEC_NORMAL;
                target_mode_arg = MODE_NORMAL;
                target_mode_name = "Normal";
            }
        }

        // --- 3. Apply Control Script (Only if state changed) ---
        if (last_executed != target_state) {
            printf("Applying %s profile (Mode %s)...\n", target_mode_name, target_mode_arg);
            char command[BUFFER_SIZE];
            
            // Execute Raco.sh with the determined argument
            snprintf(command, sizeof(command), "sh %s %s", RACO_SCRIPT, target_mode_arg);
            system(command);
            
            last_executed = target_state;
        }

        sleep(delay_seconds);
    }

    return 0;
}