###################################
# Star Tweak (@Koneko_dev)
# Version amba 2.0 
# Note: 
# - No cmd package bg-dexopt-job
# - No Extreme Clean Mode & am kill-all (Conflicts With Raco Kill-all)
###################################

# Bersihkan cache process seperti zygote child yang idle
cmd activity idle-maintenance

sync
sleep 0.5

# Bersihkan log & trace yang bisa menahan wakelock
logcat -c
dumpsys batterystats --reset