#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <stdbool.h>

// Define constants for file paths and buffer size
#define GAME_LIST "/data/ProjectRaco/game.txt"
#define RACO_SCRIPT "/data/adb/modules/ProjectRaco/Scripts/Raco.sh"
#define BUFFER_SIZE 1024

// Enum to track the last executed state to avoid redundant script calls
typedef enum {
    EXEC_NONE,
    EXEC_GAME,
    EXEC_NORMAL
} ExecType;

// Helper function to check if the game list file exists
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

int main(void) {
    // Check for game.txt at startup and exit if it's missing.
    if (!file_exists(GAME_LIST)) {
        fprintf(stderr, "Error: %s not found\n", GAME_LIST);
        return 1;
    }

    bool prev_screen_on = true;
    ExecType last_executed = EXEC_NONE;
    int delay_seconds = 5;
    char buffer[BUFFER_SIZE]; // Reusable buffer for commands

    while (1) {
        // --- 1. Screen State Detection (Updated) ---
        bool current_screen_on = false;
        
        // Using the lighter 'cmd deviceidle' instead of 'dumpsys'
        execute_cmd("cmd deviceidle get screen", buffer, sizeof(buffer));

        // Check if output contains "true"
        if (strstr(buffer, "true") != NULL) {
            current_screen_on = true;
        }

        // Adjust delay based on screen state for power saving.
        if (current_screen_on != prev_screen_on) {
            if (current_screen_on) {
                printf("Screen turned on - check interval: 7 seconds\n");
                delay_seconds = 7;
            } else {
                printf("Screen turned off - check interval: 12 seconds\n");
                delay_seconds = 12;
            }
            prev_screen_on = current_screen_on;
        }

        // --- 2. Focused App and Game Detection ---
        bool is_game_running = false;
        
        // Only check for games if the screen is actually ON
        if (current_screen_on) {
            char package_name[BUFFER_SIZE] = "";
            
            // Command to get the top visible activity's package name
            const char *focused_app_cmd = "cmd activity stack list | sed -n '/visible=true/{s/.*://;s:/.*::;s/^[ \t]*//;p;q}'";

            execute_cmd(focused_app_cmd, package_name, sizeof(package_name));

            if (strlen(package_name) > 0) {
                char grep_command[BUFFER_SIZE];
                // We use `grep -qFx` for the most efficient search:
                // -q: quiet mode, exits immediately on first match.
                // -F: treats the package name as a fixed string.
                // -x: matches the whole line.
                snprintf(grep_command, sizeof(grep_command), "grep -qFx \"%s\" %s", package_name, GAME_LIST);

                // `system` returns the command's exit code. `grep` returns 0 on a successful match.
                if (system(grep_command) == 0) {
                    is_game_running = true;
                    printf("Game package detected: %s\n", package_name);
                }
            }
        }

        // --- 3. Execute Control Script ---
        if (is_game_running) {
            if (last_executed != EXEC_GAME) {
                printf("Applying game profile...\n");
                char command[BUFFER_SIZE];
                snprintf(command, sizeof(command), "sh %s 1", RACO_SCRIPT);
                system(command);
                last_executed = EXEC_GAME;
            }
        } else {
            // Note: If screen is off, is_game_running is false, so we fall here.
            // This ensures we go back to normal profile if screen turns off while gaming.
            if (last_executed != EXEC_NORMAL) {
                printf("Applying normal profile...\n");
                char command[BUFFER_SIZE];
                snprintf(command, sizeof(command), "sh %s 2", RACO_SCRIPT);
                system(command);
                last_executed = EXEC_NORMAL;
            }
        }

        sleep(delay_seconds);
    }

    return 0;
}