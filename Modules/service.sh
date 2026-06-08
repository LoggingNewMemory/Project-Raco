#!/system/bin/sh

# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

# Let system fully stabilize before applying tweaks
sleep 30

MODDIR=${0%/*}

# Execute the Raco core service in the background
$MODDIR/CoreSys/raco_service &

# GHenna Universal Deep Sleep & GMS Doze
rm -f /storage/emulated/0/*.log /data/log/*.log /cache/*.log 2>/dev/null
dumpsys deviceidle reset 2>/dev/null
dumpsys deviceidle enable light 2>/dev/null
dumpsys deviceidle enable deep 2>/dev/null
settings put global device_idle_constants light_after_inactive_to=15000,light_pre_idle_to=30000,light_idle_to=300000,light_max_idle_to=900000,inactive_to=1800000,idle_after_inactive_to=0,idle_pending_to=300000,max_idle_pending_to=600000,idle_to=3600000,max_idle_to=21600000 2>/dev/null
pm trim-caches 999999999 2>/dev/null

pm set-inactive com.google.android.gms true 2>/dev/null
dumpsys deviceidle whitelist -com.google.android.gms 2>/dev/null
dumpsys deviceidle tempwhitelist -c com.google.android.gms 2>/dev/null