#!/system/bin/sh
# Project Raco - Performance and Gaming Optimization Suite
# Copyright (C) 2026 Kanagawa Yamada <albert.wesley.dion@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

MODDIR=${0%/*}

# Erase STATE so the app resets each state after reboot
sed -i 's/^STATE.*/STATE/' /data/ProjectRaco/raco.txt

/system/bin/linker64 $MODDIR/CoreSys/raco_service $MODDIR &

# Execute Ayunda Rusdi (Screen Modifiers) if configured
AYUNDA_RUSDI=$(grep '^AYUNDA_RUSDI ' /data/ProjectRaco/raco.txt | awk '{print $2}')
if [ "$AYUNDA_RUSDI" = "1" ]; then
    sh "/data/ProjectRaco/AyundaRusdi.sh" &
fi

# RSWAP Boot Initialization
RSWAP_ENABLED=$(grep '^RSWAP ' /data/ProjectRaco/raco.txt | awk '{print $2}' | tr -d '\r')
if [ "$RSWAP_ENABLED" = "1" ]; then
    if [ ! -f /data/ProjectRaco/RSWAP ]; then
        RSWAP_SIZE=$(grep '^RSWAP_SIZE ' /data/ProjectRaco/raco.txt | awk '{print $2}' | tr -d '\r')
        if [ -z "$RSWAP_SIZE" ]; then RSWAP_SIZE="4"; fi
        fallocate -l ${RSWAP_SIZE}G /data/ProjectRaco/RSWAP
    fi
    if [ -f /data/ProjectRaco/RSWAP ]; then
        chmod 0600 /data/ProjectRaco/RSWAP
        mkswap /data/ProjectRaco/RSWAP
        /system/bin/linker64 $MODDIR/Compiled/rswap on
        echo 100 > /proc/sys/vm/swappiness
        echo $(( $(cat /proc/sys/vm/min_free_kbytes) * 12 / 10 )) > /proc/sys/vm/min_free_kbytes
    fi
    # Clean up ghost RSWAP track files from before reboot
    rm -f /data/ProjectRaco/RSWAPTrack/rswap_stop_*
fi

# Wait briefly to ensure services are started
sleep 2

# Prime the Kotlin service so it isn't in a stopped state
# We also whitelist it in deviceidle so it can start background services silently without persistent notifications!
su -c "dumpsys deviceidle whitelist +com.kanagawa.yamada.project.raco >/dev/null 2>&1"
su -c "am startservice com.kanagawa.yamada.project.raco/.GameAssistantService >/dev/null 2>&1"

# Send Startup Notification
SILENT_NOTIF=$(grep '^SILENT_NOTIF ' /data/ProjectRaco/raco.txt | awk '{print $2}')
if [ "$SILENT_NOTIF" = "0" ]; then
    LEGACY_NOTIF=$(grep '^LEGACY_NOTIF ' /data/ProjectRaco/raco.txt | awk '{print $2}')
    if [ "$LEGACY_NOTIF" = "1" ]; then
        su -lp 2000 -c "cmd notification post -S bigtext -t 'Project Raco' 'TagRaco' 'Project Raco - オンライン'" &
    else
        su -lp 2000 -c "cmd notification post -S bigtext -t 'Project Raco' -i file:///data/local/tmp/logo.png -I file:///data/local/tmp/logo.png 'TagRaco' 'Project Raco - オンライン'" &
    fi
fi
# Start the Game Watcher Daemon
GAME_ASSISTANT=$(grep '^GAME_ASSISTANT ' /data/ProjectRaco/raco.txt | awk '{print $2}')
if [ "$GAME_ASSISTANT" = "1" ]; then
    su -c "$MODDIR/CoreSys/RacoGameAssistantService" &
fi
