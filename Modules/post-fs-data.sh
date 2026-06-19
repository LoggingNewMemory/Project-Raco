#!/system/bin/sh

CONFIG_FILE="/data/ProjectRaco/raco.txt"

INCLUDE_ZETAMIN=$(grep '^INCLUDE_ZETAMIN ' "$CONFIG_FILE" | awk '{print $2}')

if [ "$INCLUDE_ZETAMIN" = "1" ]; then

    # From EnCorinVest
    resetprop debug.graphics.game_default_frame_rate.disabled true
    resetprop sys.surfaceflinger.idle_reduce_framerate_enable no

    # From BreezeOS
    resetprop ro.max.fling_velocity 10000
    resetprop ro.surface_flinger.max_frame_buffer_acquired_buffers 3
    resetprop ro.surface_flinger.max_virtual_display_dimension 1920
fi
