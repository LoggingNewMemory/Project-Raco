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

# Execute the Raco Game Monitoring Service
$MODDIR/CoreSys/raco_gameservice &