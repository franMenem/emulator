#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NESTOPIA_DIR="$SCRIPT_DIR/nestopia"
OUTPUT_DIR="$SCRIPT_DIR"

# Clone if not present
if [ ! -d "$NESTOPIA_DIR" ]; then
    git clone --depth 1 https://github.com/libretro/nestopia.git "$NESTOPIA_DIR"
fi

cd "$NESTOPIA_DIR/libretro"

# Clean previous build
make clean 2>/dev/null || true

# Create a prefix header to rename all retro_* symbols to nes_retro_*
cat > "$SCRIPT_DIR/nes_prefix.h" << 'HEADER'
#ifndef NES_PREFIX_H
#define NES_PREFIX_H

#define retro_init nes_retro_init
#define retro_deinit nes_retro_deinit
#define retro_api_version nes_retro_api_version
#define retro_get_system_info nes_retro_get_system_info
#define retro_get_system_av_info nes_retro_get_system_av_info
#define retro_set_environment nes_retro_set_environment
#define retro_set_video_refresh nes_retro_set_video_refresh
#define retro_set_audio_sample nes_retro_set_audio_sample
#define retro_set_audio_sample_batch nes_retro_set_audio_sample_batch
#define retro_set_input_poll nes_retro_set_input_poll
#define retro_set_input_state nes_retro_set_input_state
#define retro_set_controller_port_device nes_retro_set_controller_port_device
#define retro_reset nes_retro_reset
#define retro_run nes_retro_run
#define retro_serialize_size nes_retro_serialize_size
#define retro_serialize nes_retro_serialize
#define retro_unserialize nes_retro_unserialize
#define retro_cheat_reset nes_retro_cheat_reset
#define retro_cheat_set nes_retro_cheat_set
#define retro_load_game nes_retro_load_game
#define retro_load_game_special nes_retro_load_game_special
#define retro_unload_game nes_retro_unload_game
#define retro_get_region nes_retro_get_region
#define retro_get_memory_data nes_retro_get_memory_data
#define retro_get_memory_size nes_retro_get_memory_size

#endif
HEADER

ARCH_FLAGS="-arch arm64 -mmacosx-version-min=14.0"
PREFIX_FLAGS="-include $SCRIPT_DIR/nes_prefix.h"

# Use CPPFLAGS to inject prefix header and arch flags without overriding
# the Makefile's own CFLAGS/CXXFLAGS (which set up include paths)
make -f Makefile \
    platform=osx \
    STATIC_LINKING=1 \
    CPPFLAGS="$ARCH_FLAGS $PREFIX_FLAGS" \
    -j$(sysctl -n hw.ncpu)

# Find and copy the output static library
# STATIC_LINKING=1 produces an ar archive, but the Makefile may name it .dylib or .a
LIB_FILE=$(find . -maxdepth 1 \( -name "*.a" -o -name "*.dylib" \) | head -1)
if [ -z "$LIB_FILE" ]; then
    echo "ERROR: No library file found after build"
    exit 1
fi

cp "$LIB_FILE" "$OUTPUT_DIR/libnestopia.a"

# Copy libretro header (the original, unmodified one)
mkdir -p "$OUTPUT_DIR/include"
cp "$NESTOPIA_DIR/libretro/libretro-common/include/libretro.h" "$OUTPUT_DIR/include/"

echo "Done: libnestopia.a and headers in $OUTPUT_DIR"
