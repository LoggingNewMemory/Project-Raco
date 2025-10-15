# Get highest rate By: Koneko_Dev
max_rate=$(cmd display dump 2>/dev/null | grep -Eo 'fps=[0-9.]+' | cut -f2 -d= | awk '{printf "%.0f\n", $1}' | sort -nr | head -n1)

# Apply settings
settings put system min_refresh_rate $max_rate
settings put system peak_refresh_rate $max_rate
setprop persist.sys.sf.refresh_rate $max_rate
setprop persist.vendor.display.refresh_rate $max_rate
