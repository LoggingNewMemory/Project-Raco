#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void print_usage() {
    printf("Usage: Rshoot cap <output_path>\n");
}

int main(int argc, char *argv[]) {
    if (argc < 3) {
        print_usage();
        return 1;
    }

    if (strcmp(argv[1], "cap") == 0) {
        char *path = argv[2];
        char command[512];
        
        // Extract directory from path to ensure it exists
        char *last_slash = strrchr(path, '/');
        if (last_slash != NULL) {
            char dir[256];
            int dir_len = last_slash - path;
            if (dir_len >= sizeof(dir)) {
                dir_len = sizeof(dir) - 1;
            }
            strncpy(dir, path, dir_len);
            dir[dir_len] = '\0';
            
            snprintf(command, sizeof(command), "mkdir -p %s", dir);
            system(command);
        }

        // Execute screencap
        snprintf(command, sizeof(command), "screencap -p > %s", path);
        int ret = system(command);

        if (ret == 0) {
            // Broadcast intent to media scanner so the image shows up in gallery
            snprintf(command, sizeof(command), "am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file://%s > /dev/null 2>&1", path);
            system(command);
            printf("Screenshot saved to %s\n", path);
        } else {
            printf("Failed to capture screenshot\n");
        }
        return ret;
    } else {
        printf("Unknown command: %s\n", argv[1]);
        print_usage();
        return 1;
    }

    return 0;
}
