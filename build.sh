#!/bin/bash

# ==========================================
# 1. ENVIRONMENT & CONFIGURATION
# ==========================================
export NDK=/opt/android-ndk
export API=28
TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin

MODULES_DIR="Modules"
BUILD_DIR="Build"
SRC_DIR="Sources"

# Check if megumi.sh exists and load configuration
TELEGRAM_ENABLED=false
if [ -f "megumi.sh" ]; then
    source megumi.sh
    TELEGRAM_ENABLED=true
fi

mkdir -p "$BUILD_DIR"
# The Compiled Sources folder will be mapped to Modules/Compiled
mkdir -p "$MODULES_DIR/Compiled"

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

# Function to send file to Telegram
send_to_telegram() {
    local file_path="$1"
    local caption="$2"
    local chat_id="$3"

    if [ -z "$TELEGRAM_BOT_TOKEN" ]; then
        echo "Error: TELEGRAM_BOT_TOKEN is not set in megumi.sh!"
        return 1
    fi

    if [ -z "$chat_id" ]; then
        echo "Error: Chat ID is empty!"
        return 1
    fi

    echo "Uploading $(basename "$file_path") to chat ID: $chat_id..."

    # Send document to Telegram
    response=$(curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendDocument" \
        -F "chat_id=$chat_id" \
        -F "document=@$file_path" \
        -F "caption=$caption")

    # Check if upload was successful
    if echo "$response" | grep -q '"ok":true'; then
        echo "✓ Successfully uploaded $(basename "$file_path") to $chat_id"
        return 0
    else
        echo "✗ Failed to upload $(basename "$file_path") to $chat_id"
        echo "Response: $response"
        return 1
    fi
}

# Function to send message to Telegram
send_message_to_telegram() {
    local message="$1"
    local chat_id="$2"

    if [ -z "$TELEGRAM_BOT_TOKEN" ] || [ -z "$chat_id" ]; then
        return 1
    fi

    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
        -d "chat_id=$chat_id" \
        -d "text=$message" \
        -d "parse_mode=Markdown" > /dev/null
}

# Function to display available groups and get selection
select_telegram_groups() {
    local available_groups=()
    local group_names=()

    if [ ${#TELEGRAM_GROUPS[@]} -eq 0 ]; then
        echo "No Telegram groups configured in megumi.sh"
        return 1
    fi

    echo ""
    echo "Available Telegram groups:"
    echo "--------------------------"

    local index=1
    for group in "${TELEGRAM_GROUPS[@]}"; do
        local group_name=$(echo "$group" | cut -d':' -f1)
        local chat_id=$(echo "$group" | cut -d':' -f2)

        available_groups+=("$chat_id")
        group_names+=("$group_name")

        echo "$index. $group_name ($chat_id)"
        ((index++))
    done

    echo "a. All groups"
    echo "0. Cancel"
    echo ""

    while true; do
        read -p "Select groups (comma-separated numbers, 'a' for all, or '0' to cancel): " selection
        selection=${selection,,} 

        if [[ "$selection" == "0" ]]; then
            return 1
        elif [[ "$selection" == "a" || "$selection" == "all" ]]; then
            SELECTED_GROUPS=("${available_groups[@]}")
            SELECTED_GROUP_NAMES=("${group_names[@]}")
            return 0
        else
            SELECTED_GROUPS=()
            SELECTED_GROUP_NAMES=()
            IFS=',' read -ra SELECTIONS <<< "$selection"

            local valid=true
            for sel in "${SELECTIONS[@]}"; do
                sel=$(echo "$sel" | tr -d '[:space:]')
                if [[ "$sel" =~ ^[0-9]+$ ]] && [ "$sel" -ge 1 ] && [ "$sel" -le ${#available_groups[@]} ]; then
                    local idx=$((sel-1))
                    SELECTED_GROUPS+=("${available_groups[$idx]}")
                    SELECTED_GROUP_NAMES+=("${group_names[$idx]}")
                else
                    echo "Invalid selection: $sel"
                    valid=false
                    break
                fi
            done

            if [ "$valid" = true ] && [ ${#SELECTED_GROUPS[@]} -gt 0 ]; then
                return 0
            fi
        fi
        echo "Please enter valid selections."
    done
}

prompt_changelog() {
    echo ""
    read -p "Give changelog? (Y/N): " ADD_CHANGELOG
    ADD_CHANGELOG=${ADD_CHANGELOG,,}

    if [[ "$ADD_CHANGELOG" == "y" || "$ADD_CHANGELOG" == "yes" ]]; then
        echo ""
        echo "Enter changelog (press Ctrl+D or type 'END' on a new line when finished):"
        echo "---"

        CHANGELOG=""
        while IFS= read -r line; do
            if [[ "$line" == "END" ]]; then
                break
            fi
            if [ -n "$CHANGELOG" ]; then
                CHANGELOG+=$'\n'
            fi
            CHANGELOG+="$line"
        done

        if [ -n "$CHANGELOG" ]; then
            echo "---"
            echo "Changelog captured successfully!"
            return 0
        else
            echo "No changelog entered."
            return 1
        fi
    else
        return 1
    fi
}

prompt_telegram_post() {
    echo ""
    read -p "Post to Telegram groups? (y/N): " POST_TO_TELEGRAM
    POST_TO_TELEGRAM=${POST_TO_TELEGRAM,,}

    if [[ "$POST_TO_TELEGRAM" == "y" || "$POST_TO_TELEGRAM" == "yes" ]]; then
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

    read -p "Enter Version (e.g., V1.0): " VERSION

    while true; do
        read -p "Enter Build Type (LAB/RELEASE): " BUILD_TYPE
        BUILD_TYPE=${BUILD_TYPE^^}
        if [[ "$BUILD_TYPE" == "LAB" || "$BUILD_TYPE" == "RELEASE" ]]; then
            break
        fi
        echo "Invalid input. Please enter LAB or RELEASE."
    done

# ------------------------------------------
    # A. COMPILE NATIVE BINARIES
    # ------------------------------------------
    echo ""
    echo "---------------------------------"
    echo "      Compiling Source Code      "
    echo "---------------------------------"

    echo "[1/4] Building Project Raco Core..."
    if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
        -o "$MODULES_DIR/Compiled/raco" \
        "$SRC_DIR/raco_main.c" \
        "$SRC_DIR/raco_devices.c" \
        "$SRC_DIR/raco_modules.c" \
        "$SRC_DIR/raco_utils.c" \
        "$SRC_DIR/raco_write.s"; then
        echo "❌ ERROR: Compilation of Raco Core failed!"
        exit 1
    fi

    echo "[2/4] Building Anya Thermal..."
    if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
        -o "$MODULES_DIR/Compiled/anya_thermal" \
        "$SRC_DIR/anya_thermal.c" \
        "$SRC_DIR/raco_utils.c" \
        "$SRC_DIR/raco_write.s"; then
        echo "❌ ERROR: Compilation of Anya Thermal failed!"
        exit 1
    fi

    echo "[3/4] Building Zetamin..."
    if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
        -o "$MODULES_DIR/Compiled/zetamin" \
        "$SRC_DIR/zetamin.c" \
        "$SRC_DIR/raco_utils.c" \
        "$SRC_DIR/raco_write.s"; then
        echo "❌ ERROR: Compilation of Zetamin failed!"
        exit 1
    fi

    echo "[4/4] Building Ayunda Rusdi..."
    if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
        -o "$MODULES_DIR/Compiled/ayunda_rusdi" \
        "$SRC_DIR/ayunda_rusdi.c" \
        "$SRC_DIR/raco_utils.c" \
        "$SRC_DIR/raco_write.s"; then
        echo "❌ ERROR: Compilation of Ayunda Rusdi failed!"
        exit 1
    fi

    # Strip the binaries to reduce file size
    $TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/raco"
    $TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/anya_thermal"
    $TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/zetamin"
    $TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/ayunda_rusdi"

    # ------------------------------------------
    # B. PACKAGING MODULE
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

    # ------------------------------------------
    # C. TELEGRAM UPLOAD LOGIC
    # ------------------------------------------
    if [ "$TELEGRAM_ENABLED" = true ]; then
        if prompt_telegram_post; then
            HAS_CHANGELOG=false
            if prompt_changelog; then
                HAS_CHANGELOG=true
            fi

            if select_telegram_groups; then
                echo ""
                echo "Uploading to selected Telegram groups..."

                SUMMARY_MESSAGE="🚀 *Project Raco Build Complete*%0A%0A"
                SUMMARY_MESSAGE+="📦 *Module:* $MODULE_ID%0A"
                SUMMARY_MESSAGE+="🏷️ *Version:* $VERSION%0A"
                SUMMARY_MESSAGE+="🔧 *Build Type:* $BUILD_TYPE%0A"

                if [ "$HAS_CHANGELOG" = true ] && [ -n "$CHANGELOG" ]; then
                    ENCODED_CHANGELOG=$(echo "$CHANGELOG" | sed 's/%/%25/g; s/ /%20/g; s/!/%21/g; s/"/%22/g; s/#/%23/g; s/\$/%24/g; s/&/%26/g; s/'\''/%27/g; s/(/%28/g; s/)/%29/g; s/\*/%2A/g; s/+/%2B/g; s/,/%2C/g; s/-/%2D/g; s/\./%2E/g; s/\//%2F/g; s/:/%3A/g; s/;/%3B/g; s/</%3C/g; s/=/%3D/g; s/>/%3E/g; s/?/%3F/g; s/@/%40/g; s/\[/%5B/g; s/\\/%5C/g; s/\]/%5D/g; s/\^/%5E/g; s/_/%5F/g; s/`/%60/g; s/{/%7B/g; s/|/%7C/g; s/}/%7D/g; s/~/%7E/g')
                    ENCODED_CHANGELOG=$(echo "$ENCODED_CHANGELOG" | tr '\n' ' ' | sed 's/ /%0A/g')
                    SUMMARY_MESSAGE+=%0A%0A"📝 *Changelog:*%0A$ENCODED_CHANGELOG"
                fi

                SUMMARY_MESSAGE+=%0A%0A"File uploading below... ⬇️"

                local upload_success=0
                local upload_total=${#SELECTED_GROUPS[@]}

                for i in "${!SELECTED_GROUPS[@]}"; do
                    local chat_id="${SELECTED_GROUPS[$i]}"
                    local group_name="${SELECTED_GROUP_NAMES[$i]}"

                    echo ""
                    echo "📤 Posting to: $group_name"

                    send_message_to_telegram "$SUMMARY_MESSAGE" "$chat_id"

                    if [ -f "$BUILD_DIR/$ZIP_NAME" ]; then
                        caption="📱 $MODULE_ID - $VERSION ($BUILD_TYPE)"

                        if send_to_telegram "$BUILD_DIR/$ZIP_NAME" "$caption" "$chat_id"; then
                            ((upload_success++))
                            COMPLETION_MESSAGE="✅ *Upload Complete!*%0A%0AModule uploaded successfully to $group_name."
                            send_message_to_telegram "$COMPLETION_MESSAGE" "$chat_id"
                        else
                            FAILURE_MESSAGE="❌ *Upload Failed*%0A%0AThere was an issue uploading the module to $group_name."
                            send_message_to_telegram "$FAILURE_MESSAGE" "$chat_id"
                        fi
                    else
                        echo "Error: ZIP file not found at $BUILD_DIR/$ZIP_NAME"
                    fi
                done

                echo ""
                echo "📊 Upload Summary:"
                echo "✅ Successful: $upload_success/$upload_total groups"
                echo "❌ Failed: $((upload_total - upload_success))/$upload_total groups"
            else
                echo "Telegram upload cancelled."
            fi
        else
            echo "Skipping Telegram upload."
        fi
    else
        echo ""
        echo "Post to telegram disabled, please setup megumi.sh and configure TELEGRAM_GROUPS array"
    fi
}

welcome
SECONDS=0  # Start timing
build_modules
success