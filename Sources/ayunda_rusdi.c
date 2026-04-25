/*
Project Raco - Performance Module
Copyright (C) 2026 Kanagawa Yamada 
This program is free software: you can redistribute it and/or modify it under the terms of 
the GNU General Public License as published by the Free Software Foundation, either version 3 of the License, or (at your option) any later version. 

This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; 
without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. 
See the GNU General Public License for more details. 
You should have received a copy of the GNU General Public License along with this program. 

If not, see https://www.gnu.org/licenses/.
 */

#include <stdio.h>
#include <stdlib.h>

void apply_screen_modifiers(float r, float g, float b, float saturation) {
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
             "service call SurfaceFlinger 1015 i32 1 "
             "f %f f 0 f 0 f 0 "
             "f 0 f %f f 0 f 0 "
             "f 0 f 0 f %f f 0 "
             "f 0 f 0 f 0 f 1 > /dev/null 2>&1", 
             r, g, b);
    system(cmd);

    snprintf(cmd, sizeof(cmd), 
             "service call SurfaceFlinger 1022 f %f > /dev/null 2>&1", 
             saturation);
    system(cmd);
}

int main(int argc, char *argv[]) {
    float r = 1.0;
    float g = 1.0;
    float b = 1.0;
    float saturation = 1.0;

    if (argc == 5) {
        r = atof(argv[1]);
        g = atof(argv[2]);
        b = atof(argv[3]);
        saturation = atof(argv[4]);
    }

    printf("[*] Applying AyundaRusdi Screen Modifiers...\n");
    printf("    -> RGB Matrix: [%.2f, %.2f, %.2f]\n", r, g, b);
    printf("    -> Saturation: %.2f\n", saturation);
    
    apply_screen_modifiers(r, g, b, saturation);
    printf("[+] Screen modifiers applied.\n");

    return 0;
}