max_rate=$(cmd display dump 2>/dev/null | grep -Eo 'fps=[0-9.]+' | cut -f2 -d= | sort -nr | head -n1 | cut -d . -f 1)

if [ -n "$max_rate" ] && [ "$max_rate" -gt 60 ]; then
    echo "✅ Maximum refresh rate found: ${max_rate}Hz"

    # Apply settings to lock the refresh rate
    settings put system min_refresh_rate "$max_rate"
    settings put system peak_refresh_rate "$max_rate"
    
    # Apply persistent properties for some vendor implementations
    setprop persist.sys.sf.refresh_rate "$max_rate"
    setprop persist.vendor.display.refresh_rate "$max_rate"
else
    exit 1
fi

exit 0