#!/bin/bash

MODULES_DIR="Modules"
BUILD_DIR="Build"

# Check if megumi.sh exists and load configuration
TELEGRAM_ENABLED=false
if [ -f "megumi.sh" ]; then
    source megumi.sh
    TELEGRAM_ENABLED=true
fi

mkdir -p "$BUILD_DIR"

welcome() {
    clear
    echo "---------------------------------"
    echo "     Project Raco Builder      "
    echo "---------------------------------"
    echo ""
}

success() {
    echo "---------------------------------"
    echo "    Build Process Completed      "
    printf "     Ambatukam : %s seconds\n" "$SECONDS"
    echo "---------------------------------"
}

# Function to build Flutter APK
build_flutter_apk() {
    echo "---------------------------------"
    echo "      Building Flutter APK       "
    echo "---------------------------------"

    # Save current directory to return later
    local current_dir=$(pwd)
    local flutter_project_dir="AppSource/project_raco"

    if [ ! -d "$flutter_project_dir" ]; then
        echo "Error: Flutter project directory '$flutter_project_dir' not found!"
        return 1
    fi

    echo "Navigating to $flutter_project_dir..."
    cd "$flutter_project_dir" || return 1

    echo "Running flutter clean..."
    if ! flutter clean; then
        echo "Error: flutter clean failed!"
        cd "$current_dir"
        return 1
    fi

    # ADDED: flutter pub get to restore dependencies for VSCode
    echo "Running flutter pub get..."
    if ! flutter pub get; then
        echo "Error: flutter pub get failed!"
        cd "$current_dir"
        return 1
    fi

    echo "Running flutter build apk..."
    if ! flutter build apk; then
        echo "Error: flutter build apk failed!"
        cd "$current_dir"
        return 1
    fi

    # Define paths
    local built_apk="build/app/outputs/flutter-apk/app-release.apk"
    local dest_apk="$current_dir/$MODULES_DIR/ProjectRaco.apk"

    if [ -f "$built_apk" ]; then
        echo "Moving APK to Modules directory..."
        cp "$built_apk" "$dest_apk"
        echo "✓ Updated ProjectRaco.apk in $MODULES_DIR/"
    else
        echo "Error: Built APK not found at $built_apk"
        cd "$current_dir"
        return 1
    fi

    # Return to original directory
    cd "$current_dir"
}

# Function to build HamadaAI
build_hamada_ai() {
    echo "---------------------------------"
    echo "       HamadaAI Build            "
    echo "---------------------------------"
    echo "1. Build HamadaAI"
    echo "0. Skip"
    local hamada_choice
    while true; do
        read -p "Enter your choice (1/0): " hamada_choice
        case "$hamada_choice" in
            1)
                echo "Building HamadaAI..."

                # Verify directory exists
                if [ -d "HamadaAI" ]; then
                    local root_dir=$(pwd)

                    # Enter directory to run build script so it finds sources
                    echo "Entering HamadaAI directory..."
                    cd "HamadaAI" || { echo "Failed to enter HamadaAI directory"; break; }

                    if [ -f "build.sh" ]; then
                        bash build.sh
                    else
                        echo "Error: build.sh not found inside HamadaAI directory!"
                    fi

                    # Return to root for file moving operations
                    cd "$root_dir"

                    # Define paths (relative to root)
                    local dest_dir="$MODULES_DIR/HamadaAI"
                    local src_dir="HamadaAI/bin"

                    # Ensure destination directory exists and is clean
                    if [ ! -d "$dest_dir" ]; then
                        mkdir -p "$dest_dir"
                    else
                        echo "Cleaning $dest_dir..."
                        rm -rf "$dest_dir"/*
                    fi

                    # Move files from bin to Modules
                    if [ -d "$src_dir" ]; then
                        echo "Moving files from $src_dir to $dest_dir..."
                        if [ "$(ls -A $src_dir)" ]; then
                            mv "$src_dir"/* "$dest_dir"/
                            echo "✓ HamadaAI files updated."
                        else
                            echo "Warning: $src_dir is empty (Build might have failed)."
                        fi
                    else
                        echo "Error: Source directory '$src_dir' not found!"
                    fi
                else
                    echo "Error: HamadaAI directory not found!"
                fi
                break
                ;;
            0)
                echo "Skipping HamadaAI build..."
                echo ""
                break
                ;;
            *)
                echo "Invalid choice. Please enter 1 or 0."
                ;;
        esac
    done
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

    # Parse TELEGRAM_GROUPS array
    if [ ${#TELEGRAM_GROUPS[@]} -eq 0 ]; then
        echo "No Telegram groups configured in megumi.sh"
        return 1
    fi

    echo ""
    echo "Available Telegram groups:"
    echo "--------------------------"

    local index=1
    for group in "${TELEGRAM_GROUPS[@]}"; do
        # Parse group entry: "GROUP_NAME:CHAT_ID"
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
        selection=${selection,,}  # Convert to lowercase

        if [[ "$selection" == "0" ]]; then
            return 1
        elif [[ "$selection" == "a" || "$selection" == "all" ]]; then
            SELECTED_GROUPS=("${available_groups[@]}")
            SELECTED_GROUP_NAMES=("${group_names[@]}")
            return 0
        else
            # Parse comma-separated selections
            SELECTED_GROUPS=()
            SELECTED_GROUP_NAMES=()
            IFS=',' read -ra SELECTIONS <<< "$selection"

            local valid=true
            for sel in "${SELECTIONS[@]}"; do
                sel=$(echo "$sel" | tr -d '[:space:]')  # Remove whitespace
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

# Function to prompt for changelog
prompt_changelog() {
    echo ""
    read -p "Give changelog? (Y/N): " ADD_CHANGELOG
    ADD_CHANGELOG=${ADD_CHANGELOG,,}  # Convert to lowercase

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

# Function to prompt for Telegram posting
prompt_telegram_post() {
    echo ""
    read -p "Post to Telegram groups? (y/N): " POST_TO_TELEGRAM
    POST_TO_TELEGRAM=${POST_TO_TELEGRAM,,}  # Convert to lowercase

    if [[ "$POST_TO_TELEGRAM" == "y" || "$POST_TO_TELEGRAM" == "yes" ]]; then
        return 0
    else
        return 1
    fi
}

build_modules() {
    rm -rf "$BUILD_DIR"/*

    # --- HAMADAAI BUILD START ---
    build_hamada_ai
    # --- HAMADAAI BUILD END ---

    # --- APK Build Selection ---
    echo "APK Build Options:"
    echo "1. Build the apk"
    echo "2. Skip apk build"
    local apk_choice
    while true; do
        read -p "Enter your choice (1/2): " apk_choice
        case "$apk_choice" in
            1) build_flutter_apk; break ;;
            2) echo "Skipping APK build..."; echo ""; break ;;
            *) echo "Invalid choice. Please enter 1 or 2." ;;
        esac
    done
    # ---------------------------

    read -p "Enter Version (e.g., V1.0): " VERSION

    echo ""
    echo "Manage build identifier files (CBT/Canary/Official) in '$MODULES_DIR'?"
    echo "1. Remove existing files and create a new one"
    echo "2. Keep existing files"
    local choice
    while true; do
        read -p "Enter your choice (1/2): " choice
        if [[ "$choice" == "1" || "$choice" == "2" ]]; then
            break
        fi
        echo "Invalid choice. Please enter 1 or 2."
    done
    echo ""

    # --- MODIFICATION START ---
    # Display a menu for build type selection
    echo "Select Build Type:"
    echo "1. CBT"
    echo "2. Canary"
    echo "3. Official"
    local build_choice
    while true; do
        read -p "Enter your choice (1-3): " build_choice
        case "$build_choice" in
            1) BUILD_TYPE="CBT"; break ;;
            2) BUILD_TYPE="CANARY"; break ;;
            3) BUILD_TYPE="OFFICIAL"; break ;;
            *) echo "Invalid choice. Please enter a number from 1 to 3." ;;
        esac
    done
    # --- MODIFICATION END ---

    if [[ "$choice" == "1" ]]; then
        echo "Removing existing build identifier files..."
        rm -f "$MODULES_DIR/CBT" "$MODULES_DIR/Canary" "$MODULES_DIR/Official"

        # Determine proper case for the new filename
        local PROPER_CASE_BUILD_TYPE
        if [[ "$BUILD_TYPE" == "CANARY" ]]; then
            PROPER_CASE_BUILD_TYPE="Canary"
        elif [[ "$BUILD_TYPE" == "OFFICIAL" ]]; then
            PROPER_CASE_BUILD_TYPE="Official"
        else # CBT
            PROPER_CASE_BUILD_TYPE="CBT"
        fi

        echo "Creating new build identifier file: $PROPER_CASE_BUILD_TYPE"

        # Prompt for Developer Name and write it to the identifier file
        read -p "Enter Developer Name: " DEV_NAME
        echo "$DEV_NAME" > "$MODULES_DIR/$PROPER_CASE_BUILD_TYPE"

    else
        echo "Keeping existing build identifier files."
    fi
    echo ""


    cd "$MODULES_DIR" || exit 1
    MODULE_ID=$(grep "^id=" "module.prop" | cut -d'=' -f2 | tr -d '[:space:]')

    # Fix: Use sed without attempting to preserve permissions
    # Create a temporary file for the sed operation
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
    zip -9 -q -r "$ZIP_PATH" ./*
    echo "Created: $ZIP_NAME"

    cd ..

    # Check if Telegram is enabled
    if [ "$TELEGRAM_ENABLED" = true ]; then
        # Prompt for Telegram posting
        if prompt_telegram_post; then
            # Prompt for changelog
            HAS_CHANGELOG=false
            if prompt_changelog; then
                HAS_CHANGELOG=true
            fi

            # Select groups to post to
            if select_telegram_groups; then
                echo ""
                echo "Uploading to selected Telegram groups..."

                # Create a summary message
                SUMMARY_MESSAGE="🚀 *Project Raco Build Complete*%0A%0A"
                SUMMARY_MESSAGE+="📦 *Module:* $MODULE_ID%0A"
                SUMMARY_MESSAGE+="🏷️ *Version:* $VERSION%0A"
                SUMMARY_MESSAGE+="🔧 *Build Type:* $BUILD_TYPE%0A"

                # Add changelog if provided
                if [ "$HAS_CHANGELOG" = true ] && [ -n "$CHANGELOG" ]; then
                    # URL encode the changelog for Telegram
                    ENCODED_CHANGELOG=$(echo "$CHANGELOG" | sed 's/%/%25/g; s/ /%20/g; s/!/%21/g; s/"/%22/g; s/#/%23/g; s/\$/%24/g; s/&/%26/g; s/'\''/%27/g; s/(/%28/g; s/)/%29/g; s/\*/%2A/g; s/+/%2B/g; s/,/%2C/g; s/-/%2D/g; s/\./%2E/g; s/\//%2F/g; s/:/%3A/g; s/;/%3B/g; s/</%3C/g; s/=/%3D/g; s/>/%3E/g; s/?/%3F/g; s/@/%40/g; s/\[/%5B/g; s/\\/%5C/g; s/\]/%5D/g; s/\^/%5E/g; s/_/%5F/g; s/`/%60/g; s/{/%7B/g; s/|/%7C/g; s/}/%7D/g; s/~/%7E/g')
                    # Replace newlines with %0A for Telegram
                    ENCODED_CHANGELOG=$(echo "$ENCODED_CHANGELOG" | tr '\n' ' ' | sed 's/ /%0A/g')
                    SUMMARY_MESSAGE+=%0A%0A"📝 *Changelog:*%0A$ENCODED_CHANGELOG"
                fi

                SUMMARY_MESSAGE+=%0A%0A"File uploading below... ⬇️"

                local upload_success=0
                local upload_total=${#SELECTED_GROUPS[@]}

                # Loop through selected groups
                for i in "${!SELECTED_GROUPS[@]}"; do
                    local chat_id="${SELECTED_GROUPS[$i]}"
                    local group_name="${SELECTED_GROUP_NAMES[$i]}"

                    echo ""
                    echo "📤 Posting to: $group_name"

                    # Send summary message first
                    send_message_to_telegram "$SUMMARY_MESSAGE" "$chat_id"

                    # Upload the zip file
                    if [ -f "$BUILD_DIR/$ZIP_NAME" ]; then
                        caption="📱 $MODULE_ID - $VERSION ($BUILD_TYPE)"

                        if send_to_telegram "$BUILD_DIR/$ZIP_NAME" "$caption" "$chat_id"; then
                            ((upload_success++))

                            # Send completion message
                            COMPLETION_MESSAGE="✅ *Upload Complete!*%0A%0AModule uploaded successfully to $group_name."
                            send_message_to_telegram "$COMPLETION_MESSAGE" "$chat_id"
                        else
                            # Send failure message
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