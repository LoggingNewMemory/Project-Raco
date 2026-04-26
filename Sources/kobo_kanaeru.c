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
#include <unistd.h>
#include "raco_utils.h"

void kobo_fast_charge() {
    const char* MAX_CURR = "9000000";
    const char* MAX_VOLT = "12000000";

    const char* cp_paths[] = {"cp_enable", "cp_switcher_en", "cp_charging_enabled", "slave_chg_enable"};
    for (int i = 0; i < 4; i++) find_and_tweak("/sys/class/power_supply/", cp_paths[i], "1", 1);
    
    find_and_tweak("/sys/class/power_supply/", "cp_current_limit", MAX_CURR, 1);
    find_and_tweak("/sys/class/power_supply/", "cp_ilim", MAX_CURR, 1);

    if (access("/sys/class/typec/port0", F_OK) == 0) {
        tweak("sink", "/sys/class/typec/port0/power_role");
        tweak("1", "/sys/class/typec/port0/vbus_vsafe0v");
    }

    find_and_tweak("/sys/class/power_supply/", "fast_charge", "1", 1);
    find_and_tweak("/sys/class/power_supply/", "pd_allowed", "1", 1);
    find_and_tweak("/sys/class/power_supply/", "input_current_limit", MAX_CURR, 1);
    find_and_tweak("/sys/class/power_supply/", "constant_charge_current", MAX_CURR, 1);
    find_and_tweak("/sys/class/power_supply/", "voltage_max", MAX_VOLT, 1);
    
    find_and_tweak("/sys/class/power_supply/", "step_charging_enabled", "0", 1);
    find_and_tweak("/sys/class/power_supply/", "sw_jeita_enabled", "0", 1);
}

int main(int argc, char *argv[]) {
    printf("[*] Executing Kobo Kanaeru Fast Charge Optimizations...\n");
    kobo_fast_charge();
    printf("[+] Kobo Kanaeru applied successfully.\n");
    return 0;
}