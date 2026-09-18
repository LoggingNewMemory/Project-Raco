#!/system/bin/sh
PKG="$1"

if [ -z "$PKG" ]; then
    echo "Usage: $0 <package_name>"
    exit 1
fi

cmd game reset "$PKG" >/dev/null 2>&1
am compat reset-all "$PKG" >/dev/null 2>&1

echo "Cleared Slingshot compatibility flags for $PKG"
settings delete global angle_gl_driver_selection_pkgs >/dev/null 2>&1
settings delete global angle_gl_driver_selection_values >/dev/null 2>&1
