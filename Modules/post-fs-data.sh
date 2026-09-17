#!/system/bin/sh

CONFIG_FILE="/data/ProjectRaco/raco.txt"

INCLUDE_ZETAMIN=$(grep '^INCLUDE_ZETAMIN ' "$CONFIG_FILE" | awk '{print $2}')

if [ "$INCLUDE_ZETAMIN" = "1" ]; then

    # From EnCorinVest
    resetprop debug.graphics.game_default_frame_rate.disabled true
    resetprop sys.surfaceflinger.idle_reduce_framerate_enable no
fi
