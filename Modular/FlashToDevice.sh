#!/bin/bash

ZIP_PATH="$1"
BUILD_DIR="$2"

if [ -z "$ZIP_PATH" ] || [ -z "$BUILD_DIR" ]; then
    echo "Usage: $0 <zip_path> <build_dir>"
    exit 1
fi

# Function to flash module directly via ADB
flash_via_adb() {
    local zip_path="$1"
    local zip_name=$(basename "$zip_path")
    local remote_path="/data/local/tmp/$zip_name"
    local local_script="$BUILD_DIR/tmp_install.sh"
    local remote_script="/data/local/tmp/tmp_install.sh"

    echo ""
    echo "---------------------------------"
    echo "      Direct ADB Flashing        "
    echo "---------------------------------"

    # Check if adb is available
    if ! command -v adb >/dev/null 2>&1; then
        echo "Error: 'adb' is not installed or not in PATH."
        return 1
    fi

    # Check if a device is connected
    local device_state=$(adb get-state 2>/dev/null)
    if [ "$device_state" != "device" ]; then
        echo "Error: No device connected or device unauthorized."
        return 1
    fi

    # Check for Shell Root Access explicitly
    echo "Checking root access..."
    local root_check=$(adb shell su -c 'id -u' 2>/dev/null | tr -d '\r' | tr -d ' ')
    if [ "$root_check" != "0" ]; then
        echo "Error: Please Grant \"Shell\" Root Access in Your Root Manager."
        return 1
    fi

    echo "Pushing $zip_name to /data/local/tmp/..."
    if ! adb push "$zip_path" "$remote_path"; then
        echo "Error: Failed to push file to device."
        return 1
    fi

    # 1. Create the installation script locally to avoid ADB multiline escaping issues
    cat << 'EOF' > "$local_script"
TARGET_ZIP="$1"

if command -v ksud >/dev/null 2>&1; then
    echo "Detected: KernelSU Based"
    echo "Installing module..."
    ksud module install "$TARGET_ZIP"
elif command -v magisk >/dev/null 2>&1; then
    echo "Detected: Magisk Based"
    echo "Installing module..."
    magisk module install "$TARGET_ZIP"
elif command -v apd >/dev/null 2>&1; then
    echo "Detected: APatch"
    echo "Installing module..."
    apd module install "$TARGET_ZIP"
else
    echo "Error: No supported root manager found."
    rm -f "$TARGET_ZIP"
    exit 1
fi

echo "Cleaning up temporary files..."
rm -f "$TARGET_ZIP"
echo "Flashing process completed on device!"
EOF

    # 2. Push the script to the device
    adb push "$local_script" "$remote_script" >/dev/null 2>&1

    echo "Flashing module via root manager..."
    # 3. Execute the script cleanly (no newlines to confuse su)
    adb shell su -c "sh '$remote_script' '$remote_path'"

    # 4. Clean up the script file on both ends
    adb shell rm -f "$remote_script"
    rm -f "$local_script"

    # Optional prompt to reboot the device
    if [ "$FLASHTODEVICE" == "1" ]; then
        echo "Non-interactive mode: Automatically rebooting device..."
        adb reboot
    elif [ -n "$FLASHTODEVICE" ]; then
        echo "Non-interactive mode: Skipping device reboot."
    else
        echo ""
        read -p "Do you want to reboot the device now? (y/N): " REBOOT_DEV
        if [[ "${REBOOT_DEV,,}" == "y" || "${REBOOT_DEV,,}" == "yes" ]]; then
            echo "Rebooting device..."
            adb reboot
        fi
    fi
    echo "---------------------------------"
}

# Function to prompt for ADB push and flash
prompt_adb_flash() {
    if [ -n "$FLASHTODEVICE" ]; then
        if [ "$FLASHTODEVICE" == "1" ]; then
            return 0
        else
            return 1
        fi
    fi

    echo ""
    read -p "Flash directly to connected device via ADB? (y/N): " DO_ADB_FLASH
    DO_ADB_FLASH=${DO_ADB_FLASH,,}

    if [[ "$DO_ADB_FLASH" == "y" || "$DO_ADB_FLASH" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

if prompt_adb_flash; then
    flash_via_adb "$ZIP_PATH"
fi
