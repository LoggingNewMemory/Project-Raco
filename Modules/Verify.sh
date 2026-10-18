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

# Verify.sh
# Called from customize.sh to check file integrity

SHALIST="$MODPATH/ShaList.txt"

if [ ! -f "$SHALIST" ]; then
    ui_print "! WARNING: ShaList.txt not found. Skipping integrity check."
else
    ui_print "- Verifying file integrity..."
    error_found=0

    while IFS='=' read -r file hash; do
        # Skip empty lines
        [ -z "$file" ] && continue
        
        target_file="$MODPATH/$file"
        
        # Only verify files that were actually extracted to MODPATH
        if [ -f "$target_file" ]; then
            actual_hash=$(sha256sum "$target_file" | awk '{print $1}')
            if [ "$actual_hash" != "$hash" ]; then
                ui_print "! ERROR: Hash mismatch for $file"
                ui_print "  Expected: $hash"
                ui_print "  Got:      $actual_hash"
                error_found=1
            fi
        fi
    done < "$SHALIST"

    if [ "$error_found" -eq 1 ]; then
        abort "! Integrity check failed! The module files are corrupted."
    else
        ui_print "- Integrity check passed successfully."
    fi
    
    # Clean up verification files
    rm -f "$SHALIST"
    rm -f "$MODPATH/Verify.sh"
fi
