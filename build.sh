#!/bin/bash

#========================
# NON INTERACTIVE MODE
# Remove this for interactive mode
# 1 = Enable | 0 = Disable
#========================
export MODULEVERSION="8.0"
export FLASHTODEVICE="1"
export SENDTOTELEGRAM="0"

MODULES_DIR="Modules"
BUILD_DIR="Build"

mkdir -p "$BUILD_DIR"
mkdir -p "$MODULES_DIR/Compiled"
mkdir -p "$MODULES_DIR/CoreSys"

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

build_modules() {
    rm -rf "$BUILD_DIR"/*

    if [ -n "$MODULEVERSION" ]; then
        export VERSION="$MODULEVERSION"
        echo "Version: $VERSION"
    else
        read -p "Enter Version (e.g., V1.0): " VERSION
        export VERSION="$VERSION"
    fi

    # --- C Compilation ---
    if [ -f "Modular/CompileCusingNDK.sh" ]; then
        bash Modular/CompileCusingNDK.sh
        if [ $? -ne 0 ]; then
            echo "Error during C compilation. Aborting."
            exit 1
        fi
    fi

    # --- Build App ---
    if [ -f "Modular/CompileApp.sh" ]; then
        bash Modular/CompileApp.sh
    fi

    cd "$MODULES_DIR" || exit 1
    MODULE_ID=$(grep "^id=" "module.prop" | cut -d'=' -f2 | tr -d '[:space:]')

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

    ZIP_NAME="${MODULE_ID}-${VERSION}.zip"
    ZIP_PATH="../$BUILD_DIR/$ZIP_NAME"
    zip -q -r "$ZIP_PATH" ./* -x "*.gitkeep"
    echo "Created: $ZIP_NAME"

    cd ..

    # --- ADB Flash Prompt ---
    if [ -f "Modular/FlashToDevice.sh" ]; then
        bash Modular/FlashToDevice.sh "$BUILD_DIR/$ZIP_NAME" "$BUILD_DIR"
    fi

    # --- Telegram Post ---
    if [ -f "Modular/SendToTelegram.sh" ]; then
        bash Modular/SendToTelegram.sh "$MODULE_ID" "$VERSION" "$BUILD_DIR/$ZIP_NAME"
    fi
}

welcome
SECONDS=0  # Start timing
build_modules
success