#!/system/bin/sh
PKG="$1"

if [ -z "$PKG" ]; then
    echo "Usage: $0 <package_name>"
    exit 1
fi

cmd game reset "$PKG" >/dev/null 2>&1

am compat disable DOWNSCALED "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_30 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_35 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_40 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_45 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_50 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_55 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_60 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_65 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_70 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_75 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_80 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_85 "$PKG" >/dev/null 2>&1
am compat disable DOWNSCALE_90 "$PKG" >/dev/null 2>&1
am compat disable FORCE_RESIZE_APP "$PKG" >/dev/null 2>&1
am compat disable ALWAYS_SANDBOX_DISPLAY_APIS "$PKG" >/dev/null 2>&1

echo "Cleared Slingshot compatibility flags for $PKG"
settings delete global angle_gl_driver_selection_pkgs >/dev/null 2>&1
settings delete global angle_gl_driver_selection_values >/dev/null 2>&1
