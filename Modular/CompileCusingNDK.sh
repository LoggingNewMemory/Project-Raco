#!/bin/bash

# ==========================================
# Compile C files using Android NDK
# ==========================================

export NDK=/opt/android-ndk
export API=28
TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin

SRC_DIR="Sources"
MODULES_DIR="Modules"

echo "---------------------------------"
echo "   Compiling Source Code   "
echo "---------------------------------"

echo "1/6 Building Project Raco Core (Mode Switcher)..."

if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
  -o "$MODULES_DIR/Compiled/raco" \
  "$SRC_DIR/raco_main.c" \
  "$SRC_DIR/raco_devices.c" \
  "$SRC_DIR/anya.c" \
  "$SRC_DIR/raco_tools.c" \
  "$SRC_DIR/raco_tool.s"; then
  echo " ERROR: Compilation of Raco Core failed!"
  exit 1
fi

echo "2/6 Building Raco Core Service (Boot Daemon)..."
if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
  -o "$MODULES_DIR/CoreSys/raco_service" \
  "$SRC_DIR/raco_services.c" \
  "$SRC_DIR/kobo.c" \
  "$SRC_DIR/zetamin.c" \
  "$SRC_DIR/anya.c" \
  "$SRC_DIR/raco_tools.c" \
  "$SRC_DIR/raco_tool.s"; then
  echo " ERROR: Compilation of Raco Service failed!"
  exit 1
fi

echo "Building Raco Game Assistant Service (Daemon)..."
if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
  -o "$MODULES_DIR/CoreSys/RacoGameAssistantService" \
  "$SRC_DIR/RacoGameAssistant.c"; then
  echo " ERROR: Compilation of Raco Game Assistant Service failed!"
  exit 1
fi
$TOOLCHAIN/llvm-strip "$MODULES_DIR/CoreSys/RacoGameAssistantService"

echo "[4/6] Building Anya Standalone..."
if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" -DSTANDALONE \
  -o "$MODULES_DIR/Compiled/anya" \
  "$SRC_DIR/anya.c" \
  "$SRC_DIR/raco_tools.c" \
  "$SRC_DIR/raco_tool.s"; then
  echo " ERROR: Compilation of Anya failed!"
  exit 1
fi

echo "[5/6] Building Zetamin Standalone..."
if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" -DSTANDALONE \
  -o "$MODULES_DIR/Compiled/zetamin" \
  "$SRC_DIR/zetamin.c" \
  "$SRC_DIR/raco_tools.c" \
  "$SRC_DIR/raco_tool.s"; then
  echo " ERROR: Compilation of Zetamin failed!"
  exit 1
fi

echo "[6/6] Building Kobo Standalone..."
if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" -DSTANDALONE \
  -o "$MODULES_DIR/Compiled/kobo" \
  "$SRC_DIR/kobo.c" \
  "$SRC_DIR/raco_tools.c" \
  "$SRC_DIR/raco_tool.s"; then
  echo " ERROR: Compilation of Kobo failed!"
  exit 1
fi

echo "[7/8] Building RSWAP Manager..."
if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
  -o "$MODULES_DIR/Compiled/rswap" \
  "$SRC_DIR/rswap.c"; then
  echo " ERROR: Compilation of RSWAP Manager failed!"
  exit 1
fi

echo "[8/8] Building Rshoot..."
if ! $TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -I"$SRC_DIR" \
  -o "$MODULES_DIR/Compiled/Rshoot" \
  "$SRC_DIR/Rshoot.c"; then
  echo " ERROR: Compilation of Rshoot failed!"
  exit 1
fi

# Strip the binaries to reduce file size and optimize
echo " Stripping Binaries..."
$TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/raco"
$TOOLCHAIN/llvm-strip "$MODULES_DIR/CoreSys/raco_service"

$TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/anya"
$TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/zetamin"
$TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/kobo"
$TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/rswap"
$TOOLCHAIN/llvm-strip "$MODULES_DIR/Compiled/Rshoot"
