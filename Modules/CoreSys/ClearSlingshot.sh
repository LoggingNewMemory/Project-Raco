#!/system/bin/sh
PKG="$1"

if [ -z "$PKG" ]; then
    echo "Usage: $0 <package_name>"
    exit 1
fi

SDK_INT=$(getprop ro.build.version.sdk)
if [ "$SDK_INT" -ge 33 ]; then
    cmd game reset "$PKG" >/dev/null 2>&1
else
    cmd game downscale 1.0 "$PKG" >/dev/null 2>&1
fi

echo "Cleared Slingshot compatibility flags for $PKG"
settings delete global angle_gl_driver_selection_pkgs >/dev/null 2>&1
settings delete global angle_gl_driver_selection_values >/dev/null 2>&1
