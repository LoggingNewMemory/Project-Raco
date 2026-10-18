#!/system/bin/sh
# Project Raco - Performance and Gaming Optimization Suite
# Copyright (C) 2026 Kanagawa Yamada <albert.wesley.dion@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

PKG="$1"
USE_SKIA="$2"
USE_ANGLE="$3"
DOWNSCALE_RATIO="$4"

if [ -z "$PKG" ]; then
    echo "Usage: $0 <package_name> <use_skia> <use_angle> <downscale_ratio>"
    exit 1
fi

# Clean previous slingshot configuration
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