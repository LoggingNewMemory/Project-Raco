#!/system/bin/sh

# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

MODDIR=${0%/*}

# Execute the Raco core service in the background
/system/bin/linker64 $MODDIR/CoreSys/raco_service $MODDIR &

# Execute Ayunda Rusdi (Screen Modifiers) if configured
AYUNDA_RUSDI=$(grep '^AYUNDA_RUSDI ' /data/ProjectRaco/raco.txt | awk '{print $2}')
if [ "$AYUNDA_RUSDI" = "1" ]; then
    sh "$MODDIR/CoreSys/AyundaRusdi.sh" &
fi

# Forcefully auto-grant and enable the Game Assistant Accessibility Service
su -c "settings put secure enabled_accessibility_services com.kanagawa.yamada.project.raco/.GameAssistantService"
su -c "settings put secure accessibility_enabled 1" &

# RSWAP Boot Initialization
RSWAP_ENABLED=$(grep '^RSWAP ' /data/ProjectRaco/raco.txt | awk '{print $2}')
if [ "$RSWAP_ENABLED" = "1" ]; then
    if [ ! -f /data/ProjectRaco/RSWAP ]; then
        RSWAP_SIZE=$(grep '^RSWAP_SIZE ' /data/ProjectRaco/raco.txt | awk '{print $2}')
        if [ -z "$RSWAP_SIZE" ]; then RSWAP_SIZE="4"; fi
        fallocate -l ${RSWAP_SIZE}G /data/ProjectRaco/RSWAP
    fi
    if [ -f /data/ProjectRaco/RSWAP ]; then
        chmod 0600 /data/ProjectRaco/RSWAP
        mkswap /data/ProjectRaco/RSWAP
        swapon -p 32767 /data/ProjectRaco/RSWAP
        echo 100 > /proc/sys/vm/swappiness
        echo $(( $(cat /proc/sys/vm/min_free_kbytes) * 12 / 10 )) > /proc/sys/vm/min_free_kbytes
    fi
fi

# Wait briefly to ensure services are started
sleep 2

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