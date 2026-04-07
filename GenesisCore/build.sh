#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
GENESIS_DIR="$SCRIPT_DIR/Genesis-Plus-GX"
OUTPUT_DIR="$SCRIPT_DIR"

# Clone if not present
if [ ! -d "$GENESIS_DIR" ]; then
    git clone --depth 1 https://github.com/libretro/Genesis-Plus-GX.git "$GENESIS_DIR"
fi

cd "$GENESIS_DIR"

# Clean previous build
make -f Makefile.libretro clean 2>/dev/null || true

ARCH_FLAGS="-arch arm64 -mmacosx-version-min=14.0"
PREFIX_FLAGS="-include $SCRIPT_DIR/genesis_prefix.h"

# Genesis Makefile.libretro uses CFLAGS += throughout, so we cannot
# override CFLAGS on the command line (Make would ignore the +=).
# Instead we inject our flags via ARCHFLAGS (used by the osx platform
# section: CFLAGS += $(ARCHFLAGS)) and CC (prefix header).
make -f Makefile.libretro \
    platform=osx \
    STATIC_LINKING=1 \
    ARCHFLAGS="$ARCH_FLAGS $PREFIX_FLAGS" \
    -j$(sysctl -n hw.ncpu)

# Find and copy the output static library
LIB_FILE=$(find . -maxdepth 1 \( -name "*.a" -o -name "*.dylib" \) | head -1)
if [ -z "$LIB_FILE" ]; then
    echo "ERROR: No library file found after build"
    exit 1
fi

cp "$LIB_FILE" "$OUTPUT_DIR/libgenesis.a"

# Copy libretro header (the original, unmodified one)
mkdir -p "$OUTPUT_DIR/include"
cp "$GENESIS_DIR/libretro/libretro-common/include/libretro.h" "$OUTPUT_DIR/include/"

echo "Done: libgenesis.a and headers in $OUTPUT_DIR"
