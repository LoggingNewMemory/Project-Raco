###################################
# Star Tweak (@Koneko_dev)
# Version amba 2.0 
# Note: 
# - No cmd package bg-dexopt-job
# - No Extreme Clean Mode (Conflicts With Raco Kill-all)
###################################

# Bersihkan cache process seperti zygote child yang idle
cmd activity idle-maintenance

am kill-all >/dev/null 2>&1

sync
sleep 0.5

# Bersihkan log & trace yang bisa menahan wakelock
logcat -c
dumpsys batterystats --reset