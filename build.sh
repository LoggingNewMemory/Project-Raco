#!/bin/bash

# ==========================================
# 0. QUICK CONFIGURATION
# ==========================================
# Uncomment and modify these to skip interactive prompts.
# Comment them out to return to normal interactive mode.
RACOVER="6.1.15"
BUILD="LAB"

# ==========================================
# 1. ENVIRONMENT & CONFIGURATION
# ==========================================
export NDK=/opt/android-ndk
export API=28
TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin

MODULES_DIR="Modules"
BUILD_DIR="Build"
SRC_DIR="Sources"

mkdir -p "$BUILD_DIR"
mkdir -p "$MODULES_DIR/Compiled"
mkdir -p "$MODULES_DIR/CoreSys"

# ==========================================
# 2. UI & HELPER FUNCTIONS
# ==========================================
welcome() {
    clear
    echo "---------------------------------"
    echo "      Project Raco Builder       "
    echo "---------------------------------"
    echo ""
}

success() {
    echo "---------------------------------"
    echo "    Build Process Completed      "
    printf "     Finished in : %s seconds\n" "$SECONDS"
    echo "---------------------------------"
}

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
        echo "❌ Error: 'adb' is not installed or not in PATH."
        return 1
    fi

    # Check if a device is connected
    local device_state=$(adb get-state 2>/dev/null)
    if [ "$device_state" != "device" ]; then
        echo "❌ Error: No device connected or device unauthorized."
        return 1
    fi

    # Check for Shell Root Access explicitly
    echo "🔎 Checking root access..."
    local root_check=$(adb shell su -c 'id -u' 2>/dev/null | tr -d '\r' | tr -d ' ')
    if [ "$root_check" != "0" ]; then
        echo "❌ Error: Please Grant \"Shell\" Root Access in Your Root Manager."
        return 1
    fi

    echo "📲 Pushing $zip_name to /data/local/tmp/..."
    if ! adb push "$zip_path" "$remote_path"; then
        echo "❌ Error: Failed to push file to device."
        return 1
    fi

    # Create the installation script locally
    cat << 'EOF' > "$local_script"
TARGET_ZIP="$1"

if command -v ksud >/dev/null 2>&1; then
    echo "✅ Detected: KernelSU Based"
    echo "📦 Installing module..."
    ksud module install "$TARGET_ZIP"
elif command -v magisk >/dev/null 2>&1; then
    echo "✅ Detected: Magisk Based"
    echo "📦 Installing module..."
    magisk module install "$TARGET_ZIP"
elif command -v apd >/dev/null 2>&1; then
    echo "✅ Detected: APatch"
    echo "📦 Installing module..."
    apd module install "$TARGET_ZIP"
else
    echo "❌ Error: No supported root manager found."
    rm -f "$TARGET_ZIP"
    exit 1
fi

echo "🧹 Cleaning up temporary files..."
rm -f "$TARGET_ZIP"
echo "✅ Flashing process completed on device!"
EOF

    adb push "$local_script" "$remote_script" >/dev/null 2>&1

    echo "🔄 Flashing module via root manager..."
    adb shell su -c "sh '$remote_script' '$remote_path'"

    adb shell rm -f "$remote_script"
    rm -f "$local_script"

    echo ""
    read -p "Do you want to reboot the device now? (y/N): " REBOOT_DEV
    if [[ "${REBOOT_DEV,,}" == "y" || "${REBOOT_DEV,,}" == "yes" ]]; then
        echo "Rebooting device... 👋"
        adb reboot
    fi
    echo "---------------------------------"
}

prompt_adb_flash() {
    echo ""
    read -p "Flash directly to connected device via ADB? (y/N): " DO_ADB_FLASH
    DO_ADB_FLASH=${DO_ADB_FLASH,,}

    if [[ "$DO_ADB_FLASH" == "y" || "$DO_ADB_FLASH" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

# ==========================================
# 3. CORE BUILD PROCESS
# ==========================================
build_modules() {
    rm -rf "$BUILD_DIR"/*

    if [ -n "$RACOVER" ]; then
        VERSION="$RACOVER"
        echo "Auto-set Version: $VERSION"
    else
        read -p "Enter Version (e.g., V1.0): " VERSION
    fi

    if [ -n "$BUILD" ]; then
        BUILD_TYPE="${BUILD^^}"
        echo "Auto-set Build Type: $BUILD_TYPE"
    else
        while true; do
            read -p "Enter Build Type (LAB/RELEASE): " BUILD_TYPE
            BUILD_TYPE=${BUILD_TYPE^^}
            if [[ "$BUILD_TYPE" == "LAB" || "$BUILD_TYPE" == "RELEASE" ]]; then
                break
            fi
            echo "Invalid input. Please enter LAB or RELEASE."
        done
    fi

    # ------------------------------------------
    # A. COMPILE NATIVE BINARIES
    # ------------------------------------------
    echo ""
    echo "---------------------------------"
    echo "      Compiling Source Code      "
    echo "---------------------------------"

    echo "[1/6] Building Project Raco Core (Mode Switcher)..."
    if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
        -o "$MODULES_DIR/Compiled/raco" \
        "$SRC_DIR/raco_main.c" \
        "$SRC_DIR/raco_devices.c" \
        "$SRC_DIR/anya.c" \
        "$SRC_DIR/raco_tools.c" \
        "$SRC_DIR/raco_tool.s"; then
        echo "❌ ERROR: Compilation of Raco Core failed!"
        exit 1
    fi

    echo "[2/6] Building Raco Core Service (Boot Daemon)..."
    if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
        -o "$MODULES_DIR/CoreSys/raco_service" \
        "$SRC_DIR/raco_services.c" \
        "$SRC_DIR/kobo.c" \
        "$SRC_DIR/zetamin.c" \
        "$SRC_DIR/anya.c" \
        "$SRC_DIR/raco_tools.c" \
        "$SRC_DIR/raco_tool.s"; then
        echo "❌ ERROR: Compilation of Raco Service failed!"
        exit 1
    fi

    echo "[3/6] Building Raco Game Service (Monitor Daemon)..."
    if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
        -o "$MODULES_DIR/CoreSys/raco_gameservice" \
        "$SRC_DIR/raco_gameservice.c" \
        "$SRC_DIR/raco_perfinfo.c" \
        "$SRC_DIR/anya.c" \
        "$SRC_DIR/raco_tools.c" \
        "$SRC_DIR/raco_tool.s"; then
        echo "❌ ERROR: Compilation of Raco Game Service failed!"
        exit 1
    fi

    echo "[4/6] Building Anya Standalone..."
    if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" -DSTANDALONE \
        -o "$MODULES_DIR/Compiled/anya" \
        "$SRC_DIR/anya.c" \
        "$SRC_DIR/raco_tools.c" \
        "$SRC_DIR/raco_tool.s"; then
        echo "❌ ERROR: Compilation of Anya failed!"
        exit 1
    fi

    echo "[5/6] Building Zetamin Standalone..."
    if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" -DSTANDALONE \
        -o "$MODULES_DIR/Compiled/zetamin" \
        "$SRC_DIR/zetamin.c" \
        "$SRC_DIR/raco_tools.c" \
        "$SRC_DIR/raco_tool.s"; then
        echo "❌ ERROR: Compilation of Zetamin failed!"
        exit 1
    fi

    echo "[6/6] Building Kobo Standalone..."
    if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" -DSTANDALONE \
        -o "$MODULES_DIR/Compiled/kobo" \
        "$SRC_DIR/kobo.c" \
        "$SRC_DIR/raco_tools.c" \
        "$SRC_DIR/raco_tool.s"; then
        echo "❌ ERROR: Compilation of Kobo failed!"
        exit 1
    fi

    # Strip the binaries to reduce file size and optimize
    echo "🗜️ Stripping Binaries..."
    $TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/raco"
    $TOOLCHAIN/llvm-strip "$MODULES_DIR/CoreSys/raco_service"
    $TOOLCHAIN/llvm-strip "$MODULES_DIR/CoreSys/raco_gameservice"
    $TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/anya"
    $TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/zetamin"
    $TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/kobo"

    # ------------------------------------------
    # C. BUILD ANDROID APP
    # ------------------------------------------
    echo ""
    echo "---------------------------------"
    echo "       Building Android App      "
    echo "---------------------------------"
    echo "Syncing App version to $VERSION..."
    VCODE=$(echo "$VERSION" | tr -d '.' | tr -d 'vV')
    if ! [[ "$VCODE" =~ ^[0-9]+$ ]]; then
        VCODE=1
    fi
    sed -i "s/versionName = \".*\"/versionName = \"$VERSION\"/" "AppSource2/app/build.gradle.kts"
    sed -i "s/versionCode = [0-9]*/versionCode = $VCODE/" "AppSource2/app/build.gradle.kts"

    echo "Building release APK..."
    cd "AppSource2" || exit 1
    ./gradlew assembleRelease
    cd ..
    
    APK_UNSIGNED="AppSource2/app/build/outputs/apk/release/app-release-unsigned.apk"
    APK_SIGNED="AppSource2/app/build/outputs/apk/release/app-release.apk"
    APK_ALIGNED="AppSource2/app/build/outputs/apk/release/app-release-aligned.apk"
    
    # If gradle didn't produce a signed APK but did produce an unsigned one, sign it
    if [ ! -f "$APK_SIGNED" ] && [ -f "$APK_UNSIGNED" ]; then
        echo "📦 Unsigned APK detected. Signing with RacoKey.jks..."
        
        # Find latest build-tools
        BUILD_TOOLS_DIR=$(ls -1d /home/yamada/Android/Sdk/build-tools/* 2>/dev/null | sort -V | tail -n 1)
        APKSIGNER="$BUILD_TOOLS_DIR/apksigner"
        ZIPALIGN="$BUILD_TOOLS_DIR/zipalign"
        
        if [ -f "$APKSIGNER" ] && [ -f "$ZIPALIGN" ]; then
            KEY_ALIAS="key0"
            KS_PASS="aw240706"
            
            echo "🔧 Aligning APK..."
            "$ZIPALIGN" -v -p 4 "$APK_UNSIGNED" "$APK_ALIGNED" > /dev/null
            
            echo "🔐 Signing APK..."
            "$APKSIGNER" sign --ks "RacoKey.jks" --ks-key-alias "$KEY_ALIAS" --ks-pass "pass:$KS_PASS" --key-pass "pass:$KS_PASS" --out "$APK_SIGNED" "$APK_ALIGNED"
            
            if [ $? -eq 0 ]; then
                echo "✅ Signing successful!"
                rm -f "$APK_ALIGNED"
            else
                echo "❌ ERROR: Signing failed!"
            fi
        else
            echo "⚠️  WARNING: apksigner or zipalign not found in /home/yamada/Android/Sdk/build-tools/. Skipping signing."
        fi
    fi

    if [ -f "$APK_SIGNED" ]; then
        cp "$APK_SIGNED" "$MODULES_DIR/ProjectRaco.apk"
        echo "✅ Copied app-release.apk to Modules/ProjectRaco.apk"
    elif [ -f "$APK_UNSIGNED" ]; then
        cp "$APK_UNSIGNED" "$MODULES_DIR/ProjectRaco.apk"
        echo "⚠️  Copied app-release-unsigned.apk to Modules/ProjectRaco.apk (Unsigned)"
    else
        echo "❌ ERROR: No release APK found!"
    fi

    # ------------------------------------------
    # C. PACKAGING MODULE
    # ------------------------------------------
    echo ""
    echo "---------------------------------"
    echo "       Packaging Module          "
    echo "---------------------------------"

    cd "$MODULES_DIR" || exit 1
    MODULE_ID=$(grep "^id=" "module.prop" | cut -d'=' -f2 | tr -d '[:space:]')

    if [ -f "module.prop" ]; then
        cp "module.prop" "module.prop.tmp"
        sed "s/^version=.*$/version=$VERSION/" "module.prop.tmp" > "module.prop"
        rm "module.prop.tmp"
    fi

    if [ -f "customize.sh" ]; then
        cp "customize.sh" "customize.sh.tmp"
        sed "s/^ui_print \"Version : .*$/ui_print \"Version : $VERSION\"/" "customize.sh.tmp" > "customize.sh"
        rm "customize.sh.tmp"
    fi

    ZIP_NAME="${MODULE_ID}-${VERSION}-${BUILD_TYPE}.zip"
    ZIP_PATH="../$BUILD_DIR/$ZIP_NAME"
    zip -q -r "$ZIP_PATH" ./*
    echo "Created: $ZIP_NAME"

    cd ..

    # --- ADB Flash Prompt ---
    if prompt_adb_flash; then
        flash_via_adb "$BUILD_DIR/$ZIP_NAME"
    fi
}

welcome
SECONDS=0  # Start timing
build_modules
success