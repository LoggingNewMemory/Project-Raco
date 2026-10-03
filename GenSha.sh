#!/bin/bash
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
