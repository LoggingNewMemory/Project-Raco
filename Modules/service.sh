#!/system/bin/sh

# Wait for boot completion
while [ -z "$(getprop sys.boot_completed)" ]; do
    sleep 10
done

#!/system/bin/sh
MODDIR=${0%/*}

# Execute the Raco core service in the background
$MODDIR/CoreSys/raco_service &