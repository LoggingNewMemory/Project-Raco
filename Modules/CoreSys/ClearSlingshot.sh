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
