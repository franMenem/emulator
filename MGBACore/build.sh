#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MGBA_DIR="$SCRIPT_DIR/mgba"
BUILD_DIR="$SCRIPT_DIR/mgba-build"
OUTPUT_DIR="$SCRIPT_DIR"

# Clone mGBA if not present
if [ ! -d "$MGBA_DIR" ]; then
    git clone --depth 1 --branch 0.10.3 https://github.com/mgba-emu/mgba.git "$MGBA_DIR"
fi

# Build as static library (core only, no frontends, no deps)
cmake -S "$MGBA_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
    -DLIBMGBA_ONLY=ON \
    -DM_CORE_GB=OFF \
    -DM_CORE_GBA=ON

cmake --build "$BUILD_DIR" -j$(sysctl -n hw.ncpu)

# Copy artifacts
cp "$BUILD_DIR/libmgba.a" "$OUTPUT_DIR/libmgba.a"
mkdir -p "$OUTPUT_DIR/include"
# Copy public headers from source
cp -R "$MGBA_DIR/include/mgba" "$OUTPUT_DIR/include/"
cp -R "$MGBA_DIR/include/mgba-util" "$OUTPUT_DIR/include/"
# Copy generated headers (version.h, config.h)
cp -R "$BUILD_DIR/include/mgba" "$OUTPUT_DIR/include/" 2>/dev/null || true
cp -R "$BUILD_DIR/include/mgba-util" "$OUTPUT_DIR/include/" 2>/dev/null || true

echo "Done: libmgba.a and headers in $OUTPUT_DIR"
