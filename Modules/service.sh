#!/system/bin/sh

# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

MODDIR=${0%/*}

# Execute the Raco core service in the background
$MODDIR/CoreSys/raco_service &

# Execute the Raco Game Monitoring Service
$MODDIR/CoreSys/raco_gameservice &

# Wait briefly to ensure services are started
sleep 2

# Send Startup Notification
LEGACY_NOTIF=$(grep '^LEGACY_NOTIF ' /data/ProjectRaco/raco.txt | awk '{print $2}')
if [ "$LEGACY_NOTIF" = "1" ]; then
    su -lp 2000 -c "cmd notification post -S bigtext -t 'Project Raco' 'TagRaco' 'Project Raco - オンライン'" &
else
    su -lp 2000 -c "cmd notification post -S bigtext -t 'Project Raco' -i file:///data/local/tmp/logo.png -I file:///data/local/tmp/logo.png 'TagRaco' 'Project Raco - オンライン'" &
fi