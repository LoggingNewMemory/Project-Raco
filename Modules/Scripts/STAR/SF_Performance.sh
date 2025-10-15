###################################
# Star Tweak (@Koneko_dev)
# Version amba 2.0 
# Note: 
###################################

# --- SurfaceFlinger Dynamic Timing (Performance Mode) ---
fps="$(dumpsys display | grep -o -E 'fps=[0-9]+(\.[0-9]+)?' | cut -d'=' -f2 | sort -nr | head -n1 | awk '{printf("%d\n", ($1+0.5)/1)}')"
vsync_ns=$((1000000000 / fps))

# Performance offsets
timingapp=$(awk -v v=$vsync_ns 'BEGIN {print int(v*1.08)}')
timingsf=$(awk -v v=$vsync_ns 'BEGIN {print int(v*1.18)}')

setprop debug.sf.use_phase_offsets_as_durations 1

# Apply durations to app phase
for appduration in debug.sf.earlyGl.app.duration debug.sf.early.app.duration debug.sf.late.app.duration; do
    setprop $appduration $timingapp
done

# Apply durations to SurfaceFlinger phase
for sfduration in debug.sf.late.sf.duration debug.sf.early.sf.duration debug.sf.earlyGl.sf.duration; do
    setprop $sfduration $timingsf
done