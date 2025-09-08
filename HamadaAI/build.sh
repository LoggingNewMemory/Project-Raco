#!/bin/bash

export NDK=/opt/android-ndk
export API=21
TOOLCHAIN=$NDK/toolchains/llvm/prebuilt/linux-x86_64/bin

# Create output directory
mkdir -p bin

# Build for ARM64
echo "Building for ARM64..."
$TOOLCHAIN/aarch64-linux-android$API-clang -Wall -O2 -o bin/hamadaAI_arm64 HamadaAI.c

# Build for ARM32
echo "Building for ARM32..."
$TOOLCHAIN/armv7a-linux-androideabi$API-clang -Wall -O2 -o bin/hamadaAI_arm32 HamadaAI.c

echo "Build complete! Binaries are in the bin directory."