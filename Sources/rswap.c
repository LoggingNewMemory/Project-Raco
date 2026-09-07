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
