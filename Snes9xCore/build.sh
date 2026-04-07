#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SNES9X_DIR="$SCRIPT_DIR/snes9x"
OUTPUT_DIR="$SCRIPT_DIR"

# Clone if not present
if [ ! -d "$SNES9X_DIR" ]; then
    git clone --depth 1 https://github.com/libretro/snes9x.git "$SNES9X_DIR"
fi

cd "$SNES9X_DIR/libretro"

# Clean previous build
make clean 2>/dev/null || true

ARCH_FLAGS="-arch arm64 -mmacosx-version-min=14.0"
PREFIX_FLAGS="-include $SCRIPT_DIR/snes_prefix.h"

# Build as static library for arm64-macos with symbol prefixing
# snes9x osx platform doesn't auto-set STATIC_LINKING_LINK, so we set it
# and override TARGET to produce a .a file
make -f Makefile \
    platform=osx \
    STATIC_LINKING=1 \
    STATIC_LINKING_LINK=1 \
    TARGET=snes9x_libretro.a \
    CPPFLAGS="$ARCH_FLAGS $PREFIX_FLAGS" \
    -j$(sysctl -n hw.ncpu)

# Find and copy the output static library
LIB_FILE=$(find . -maxdepth 1 \( -name "*.a" -o -name "*.dylib" \) | head -1)
if [ -z "$LIB_FILE" ]; then
    echo "ERROR: No library file found after build"
    exit 1
fi

cp "$LIB_FILE" "$OUTPUT_DIR/libsnes9x.a"

# Copy libretro header (the original, unmodified one)
mkdir -p "$OUTPUT_DIR/include"
HEADER_FILE=$(find "$SNES9X_DIR" -name "libretro.h" -path "*/libretro-common/*" | head -1)
if [ -z "$HEADER_FILE" ]; then
    # Fallback: look anywhere in the repo
    HEADER_FILE=$(find "$SNES9X_DIR" -name "libretro.h" | head -1)
fi
cp "$HEADER_FILE" "$OUTPUT_DIR/include/"

echo "Done: libsnes9x.a and headers in $OUTPUT_DIR"
echo "Note: snes9x is C++ heavy — link with -lc++"
echo "SNES resolution: 256x224 (varies), audio: 32040 Hz"
