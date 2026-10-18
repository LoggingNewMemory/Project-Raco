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

void rswap_on() {
    printf("Turning on RSWAP...\n");
    // Attempt normal swapon first
    int ret = system("swapon -p 32767 /data/ProjectRaco/RSWAP 2>/dev/null");
    
    // Check if it's active
    if (system("grep -q 'RSWAP' /proc/swaps") != 0) {
        printf("Direct swapon failed or mapped to loop. Checking/mounting loop device...\n");
        // Try loop device fallback
        system("LOOP=$(losetup -f); if [ -n \"$LOOP\" ]; then losetup $LOOP /data/ProjectRaco/RSWAP; swapon -p 32767 $LOOP; fi");
    }

    if (system("grep -q -e 'RSWAP' -e '^/dev/block/loop' /proc/swaps") == 0) {
        printf("RSWAP is active.\n");
        system("echo 100 > /proc/sys/vm/swappiness 2>/dev/null");
    } else {
        printf("Failed to activate RSWAP.\n");
    }
}

void rswap_off() {
    printf("Turning off RSWAP...\n");
    system("swapoff /data/ProjectRaco/RSWAP 2>/dev/null");
    system("swapoff /ProjectRaco/RSWAP 2>/dev/null");
    system("for loop in $(losetup -a | grep 'RSWAP' | cut -d: -f1); do swapoff \"$loop\" 2>/dev/null; losetup -d \"$loop\" 2>/dev/null; done");
    printf("RSWAP is off.\n");
}

int main(int argc, char *argv[]) {
    if (argc < 2) {
        printf("Usage: %s [on|off]\n", argv[0]);
        return 1;
    }

    if (strcmp(argv[1], "on") == 0) {
        rswap_on();
    } else if (strcmp(argv[1], "off") == 0) {
        rswap_off();
    } else {
        printf("Unknown command: %s\n", argv[1]);
        printf("Usage: %s [on|off]\n", argv[0]);
        return 1;
    }

    return 0;
}
