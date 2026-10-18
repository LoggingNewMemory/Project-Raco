#!/bin/bash
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

# GenSha.sh
# Objective: Generate SHA-256 hashes for all files in the Modules directory

# Change to the script's directory (project root)
cd "$(dirname "$0")" || exit 1

MODULES_DIR="Modules"
OUTPUT_FILE="$MODULES_DIR/ShaList.txt"

# Clear the output file
> "$OUTPUT_FILE"

# Find all files in Modules and generate SHA-256
find "$MODULES_DIR" -type f | while read -r file; do
    # Skip the ShaList.txt itself to prevent hashing the file we're writing to
    if [[ "$file" == "$OUTPUT_FILE" ]]; then
        continue
    fi
    
    hash=$(sha256sum "$file" | awk '{print $1}')
    # Extract relative path (e.g. Compiled/raco)
    rel_path=${file#"$MODULES_DIR/"}
    
    # Format: [File]=[SHA-256]
    echo "$rel_path=$hash" >> "$OUTPUT_FILE"
done

echo "ShaList.txt has been generated successfully."
