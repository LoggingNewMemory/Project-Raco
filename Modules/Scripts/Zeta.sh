#!/system/bin/sh
max_rate=$(cmd display dump 2>/dev/null | grep -Eo 'fps=[0-9.]+' | cut -f2 -d= | sort -nr | head -n1 | cut -d . -f 1)

if [ -n "$max_rate" ] && [ "$max_rate" -gt 60 ]; then
    settings put system min_refresh_rate "$max_rate"
    settings put system peak_refresh_rate "$max_rate"
    resetprop ro.surface_flinger.game_default_frame_rate_override "$max_rate"
else
    exit 1
fi

resetprop debug.graphics.game_default_frame_rate.disabled true
resetprop debug.sf.disable_backpressure 1
resetprop debug.sf.disable_hwc 1
resetprop debug.sf.latch_unsignaled 1
resetprop debug.sf.disable_client_composition_cache 1
resetprop ro.surface_flinger.use_color_management false
resetprop ro.surface_flinger.has_wide_color_display false
resetprop ro.surface_flinger.has_hdr_display false
resetprop persist.sys.sf.native_mode 1
resetprop vendor.debug.mali.disable_afbc 1
resetprop ro.vendor.ddk.set.afbc 0
resetprop debug.gralloc.map_fb_memory 1
resetprop debug.gralloc.enable_fb_ubwc 0

exit 0