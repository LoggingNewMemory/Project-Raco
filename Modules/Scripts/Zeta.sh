#!/system/bin/sh
max_rate=$(cmd display dump 2>/dev/null | grep -Eo 'fps=[0-9.]+' | cut -f2 -d= | sort -nr | head -n1 | cut -d . -f 1)

if [ -n "$max_rate" ] && [ "$max_rate" -gt 60 ]; then
    settings put system min_refresh_rate "$max_rate"
    settings put system peak_refresh_rate "$max_rate"
    resetprop ro.surface_flinger.game_default_frame_rate_override "$max_rate"
else
    exit 1
fi

exit 0