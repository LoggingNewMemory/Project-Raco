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
