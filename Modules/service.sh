#!/system/bin/sh

# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

MODDIR=${0%/*}

# Execute the Raco core service in the background
/system/bin/linker64 $MODDIR/CoreSys/raco_service $MODDIR &

# Start the FPS Daemon (Android 12+)
CLASSPATH=$MODDIR/CoreSys/raco_fps.dex app_process / com.raco.RacoFpsDaemon &

# Forcefully start the companion app's AutoGameMonitorService
# Bypasses Android 14+ background FGS restrictions and OEM Autostart blocks
su -lp 2000 -c "am start-foreground-service -n com.kanagawa.yamada.project.raco/.AutoGameMonitorService" &

# Wait briefly to ensure services are started
sleep 2

# Send Startup Notification
LEGACY_NOTIF=$(grep '^LEGACY_NOTIF ' /data/ProjectRaco/raco.txt | awk '{print $2}')
if [ "$LEGACY_NOTIF" = "1" ]; then
    su -lp 2000 -c "cmd notification post -S bigtext -t 'Project Raco' 'TagRaco' 'Project Raco - オンライン'" &
else
    su -lp 2000 -c "cmd notification post -S bigtext -t 'Project Raco' -i file:///data/local/tmp/logo.png -I file:///data/local/tmp/logo.png 'TagRaco' 'Project Raco - オンライン'" &
fi