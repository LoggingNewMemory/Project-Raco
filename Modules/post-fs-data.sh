#!/system/bin/sh

CONFIG_FILE="/data/ProjectRaco/raco.txt"

if grep -q "INCLUDE_ZETAMIN=1" "$CONFIG_FILE"; then

    # From EnCorinVest
    resetprop debug.graphics.game_default_frame_rate.disabled true
    resetprop sys.surfaceflinger.idle_reduce_framerate_enable no

    # Zeta Props
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

    # From BreezeOS
    resetprop ro.max.fling_velocity 10000
    resetprop ro.surface_flinger.max_frame_buffer_acquired_buffers 3
    resetprop ro.surface_flinger.max_virtual_display_dimension 1920
fi