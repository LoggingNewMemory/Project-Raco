#!/system/bin/sh
PKG="$1"
USE_SKIA="$2"
USE_ANGLE="$3"
DOWNSCALE_RATIO="$4"

if [ -z "$PKG" ]; then
    echo "Usage: $0 <package_name> <use_skia> <use_angle> <downscale_ratio>"
    exit 1
fi

# Clean previous slingshot configuration

# Force stop the app so downscaling applies correctly on cold boot
am force-stop "$PKG"
su -c "sh /data/adb/modules/ProjectRaco/CoreSys/ClearSlingshot.sh \"$PKG\""

# Apply SkiaVK
if [ "$USE_SKIA" = "true" ]; then
    setprop debug.hwui.renderer skiavk
fi

# Apply ANGLE
if [ "$USE_ANGLE" = "true" ]; then
    settings put global angle_gl_driver_selection_pkgs "$PKG"
    settings put global angle_gl_driver_selection_values angle
fi

# Apply Downscale via Game Manager (API aware)
if [ "$DOWNSCALE_RATIO" != "1.0" ] && [ "$DOWNSCALE_RATIO" != "1.0f" ]; then
    SDK_INT=$(getprop ro.build.version.sdk)
    if [ "$SDK_INT" -ge 33 ]; then
        cmd game set --downscale "$DOWNSCALE_RATIO" "$PKG" >/dev/null 2>&1
    else
        cmd game downscale "$DOWNSCALE_RATIO" "$PKG" >/dev/null 2>&1
    fi
fi

