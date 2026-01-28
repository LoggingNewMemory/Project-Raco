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

# --- Project Raco Plugin Loader ---
PLUGIN_TXT="/data/ProjectRaco/Plugin.txt"
PLUGIN_DIR="/data/ProjectRaco/Plugins"

if [ -f "$PLUGIN_TXT" ]; then
    # Read Plugin.txt line by line (format: PluginID=1)
    while IFS='=' read -r plugin_id enabled || [ -n "$plugin_id" ]; do
        # Clean up whitespace/newlines
        plugin_id=$(echo "$plugin_id" | tr -d '[:space:]')
        enabled=$(echo "$enabled" | tr -d '[:space:]')

        # If plugin is enabled (1), execute its post-fs-data.sh
        if [ "$enabled" = "1" ]; then
            plugin_script="$PLUGIN_DIR/$plugin_id/post-fs-data.sh"
            if [ -f "$plugin_script" ]; then
                chmod +x "$plugin_script"
                # Run synchronously for post-fs-data to ensure props apply before boot continues
                sh "$plugin_script"
            fi
        fi
    done < "$PLUGIN_TXT"
fi
# ----------------------------------