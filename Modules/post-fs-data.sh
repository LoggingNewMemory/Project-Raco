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

CONFIG_FILE="/data/ProjectRaco/raco.txt"

INCLUDE_ZETAMIN=$(grep '^INCLUDE_ZETAMIN ' "$CONFIG_FILE" | awk '{print $2}')

if [ "$INCLUDE_ZETAMIN" = "1" ]; then

    # From EnCorinVest
    resetprop debug.graphics.game_default_frame_rate.disabled true
    resetprop sys.surfaceflinger.idle_reduce_framerate_enable no
fi
