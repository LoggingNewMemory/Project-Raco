/*
Project Raco - Anya Thermal Control
Copyright (C) 2026 Kanagawa Yamada 
 */

#include "raco.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

// Spoof thermal properties
static void spoof_thermal_props(const char *state) {
    char cmd[512];
    snprintf(cmd, sizeof(cmd),
        "getprop | grep 'thermal' | grep -v 'hal' | cut -d'[' -f2 | cut -d']' -f1 | "
        "while read -r prop; do [ -n \"$prop\" ] && resetprop -n \"$prop\" \"%s\"; done", state);
    system(cmd);
}

// ==========================================
// Anya Kawaii (Restore thermals)
// ==========================================
void exec_anya_kawaii() {
    printf("Anya Kawaii Start\n");

    // Unmount thermald
    system("umount /vendor/bin/thermald 2>/dev/null");

    // Restart thermal services
    system("getprop | grep -E 'init\\.svc(\\.vendor)?\\.thermal' | grep -v 'hal' | "
           "cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]' | "
           "while read -r svc; do resetprop -n \"init.svc.$svc\" \"stopped\"; start \"$svc\"; done");

    spoof_thermal_props("running");
}

// ==========================================
// Anya Melfissa (Kill thermals)
// ==========================================
void exec_anya_melfissa() {
    printf("Anya Melfissa Start...\n");

    // Kill & stop all thermal processes and services
    system("killall -9 thermald android.hardware.thermal@2.0-service 2>/dev/null; "
           "pgrep -f 'thermal' | grep -v 'hal' | xargs -r kill -9 2>/dev/null; "
           "getprop | grep -E 'init\\.svc.*thermal' | grep -v 'hal' | "
           "cut -d: -f1 | sed 's/init.svc.//g' | tr -d '[]' | "
           "while read -r svc; do stop \"$svc\"; done");

    // Block thermald & clean configs
    system("mount -o bind /dev/null /vendor/bin/thermald 2>/dev/null; "
           "rm -f /data/vendor/thermal/config /data/vendor/thermal/*.dump 2>/dev/null");

    // Spoof thermal props + OEM check
    system("for prop in $(getprop | grep -E 'sys\\..*thermal|thermal_config' | grep -v 'hal' | "
           "cut -d: -f1 | tr -d '[]'); do resetprop -n \"$prop\" \"0\"; done; "
           "resetprop debug.thermal.throttle.support 2>/dev/null | grep -q 'yes' && "
           "resetprop -n debug.thermal.throttle.support no");

    spoof_thermal_props("running");
}

#ifdef STANDALONE
int main(int argc, char *argv[]) {
    if (argc > 1) {
        if (strcmp(argv[1], "kawaii") == 0) {
            exec_anya_kawaii();
        } else if (strcmp(argv[1], "melfissa") == 0) {
            exec_anya_melfissa();
        } else {
            printf("Usage: anya [kawaii|melfissa]\n");
        }
    } else {
        printf("Usage: anya [kawaii|melfissa]\n");
    }
    return 0;
}
#endif