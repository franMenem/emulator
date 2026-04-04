#!/usr/bin/env bash
#
# build.sh — Clone and compile SameBoy as a static library for macOS arm64.
#
# Produces:
#   SameBoyCore/lib/libsameboy.a
#   SameBoyCore/include/sameboy/*.h
#
# Usage:  cd <project-root>/SameBoyCore && bash build.sh
#         or: bash SameBoyCore/build.sh   (from project root)

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────
SAMEBOY_REPO="https://github.com/LIJI32/SameBoy.git"
SAMEBOY_TAG="v1.0.3"
ARCH="arm64"

# Resolve paths relative to this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SAMEBOY_SRC="${SCRIPT_DIR}/SameBoy"
OUTPUT_LIB="${SCRIPT_DIR}"
OUTPUT_INCLUDE="${SCRIPT_DIR}/include"
OUTPUT_BOOT="${SCRIPT_DIR}/boot"

# ── Helpers ──────────────────────────────────────────────────────────
info()  { printf "\033[1;34m[INFO]\033[0m  %s\n" "$1"; }
ok()    { printf "\033[1;32m[OK]\033[0m    %s\n" "$1"; }
warn()  { printf "\033[1;33m[WARN]\033[0m  %s\n" "$1"; }
fail()  { printf "\033[1;31m[FAIL]\033[0m  %s\n" "$1"; exit 1; }

# ── Step 1: Clone or update SameBoy ─────────────────────────────────
info "Cloning SameBoy ${SAMEBOY_TAG}..."

if [ -d "${SAMEBOY_SRC}/.git" ]; then
    info "SameBoy source already exists, checking out ${SAMEBOY_TAG}..."
    cd "${SAMEBOY_SRC}"
    git fetch --tags --quiet
    git checkout "${SAMEBOY_TAG}" --quiet
else
    git clone --depth 1 --branch "${SAMEBOY_TAG}" "${SAMEBOY_REPO}" "${SAMEBOY_SRC}"
fi

cd "${SAMEBOY_SRC}"
ok "SameBoy ${SAMEBOY_TAG} ready at ${SAMEBOY_SRC}"

# ── Step 2: Build static library ────────────────────────────────────
info "Building libsameboy.a (release, ${ARCH})..."

# Clean previous build artifacts
make clean 2>/dev/null || true

# Build the lib target.
# SameBoy's Makefile uses CONF for configuration and CC for the compiler.
# We pass -arch to ensure arm64 even on Rosetta.
make lib CONF=release CC="clang -arch ${ARCH}" -j"$(sysctl -n hw.logicalcpu)"

# ── Step 3: Locate build outputs ────────────────────────────────────
BUILT_LIB="${SAMEBOY_SRC}/build/lib/libsameboy.a"
BUILT_HEADERS="${SAMEBOY_SRC}/build/include/sameboy"

if [ ! -f "${BUILT_LIB}" ]; then
    # Some versions put it directly in build/
    BUILT_LIB="$(find "${SAMEBOY_SRC}/build" -name 'libsameboy.a' -print -quit 2>/dev/null || true)"
    [ -z "${BUILT_LIB}" ] && fail "libsameboy.a not found after build"
fi
ok "Found library: ${BUILT_LIB}"

# ── Step 4: Copy outputs to SameBoyCore/{lib,include} ───────────────
info "Copying build artifacts..."

mkdir -p "${OUTPUT_LIB}"
cp "${BUILT_LIB}" "${OUTPUT_LIB}/libsameboy.a"
ok "Copied libsameboy.a -> ${OUTPUT_LIB}/"

mkdir -p "${OUTPUT_INCLUDE}"

# Prefer processed headers from make lib if available AND non-empty.
# When cppp is not installed, the Makefile creates empty .h files, so we
# check that at least gb.h has actual content.
HEADERS_USABLE=false
if [ -d "${BUILT_HEADERS}" ] && [ -s "${BUILT_HEADERS}/gb.h" ]; then
    HEADERS_USABLE=true
fi

if ${HEADERS_USABLE}; then
    cp "${BUILT_HEADERS}"/*.h "${OUTPUT_INCLUDE}/"
    ok "Copied processed headers from build/include/sameboy/"
else
    # Fallback: copy raw Core headers. These work fine when GB_INTERNAL is not
    # defined (the preprocessor guards strip internal-only declarations).
    warn "Processed headers are missing or empty (cppp not installed); copying raw Core/*.h as fallback"
    cp "${SAMEBOY_SRC}"/Core/*.h "${OUTPUT_INCLUDE}/"
    ok "Copied raw headers from Core/"
fi

# ── Step 5: Boot ROMs (optional) ────────────────────────────────────
if command -v rgbasm &>/dev/null; then
    info "RGBDS found, building boot ROMs..."
    cd "${SAMEBOY_SRC}"
    make bootroms -j"$(sysctl -n hw.logicalcpu)" || warn "Boot ROM build failed (non-fatal)"
    mkdir -p "${OUTPUT_BOOT}"
    find "${SAMEBOY_SRC}/build/bin/BootROMs" -name '*.bin' -exec cp {} "${OUTPUT_BOOT}/" \; 2>/dev/null || true
    ok "Boot ROMs copied to ${OUTPUT_BOOT}/"
else
    warn "RGBDS not installed — skipping boot ROM build."
    warn "Boot ROMs are optional; SameBoy will use built-in quick boot."
fi

# ── Step 6: Validate ────────────────────────────────────────────────
info "Validating build artifacts..."

# Check library exists and has content
LIB_SIZE=$(stat -f%z "${OUTPUT_LIB}/libsameboy.a" 2>/dev/null || echo 0)
[ "${LIB_SIZE}" -gt 0 ] || fail "libsameboy.a is empty"
ok "libsameboy.a size: ${LIB_SIZE} bytes"

# Check for critical GB_ symbols
SYMBOLS=$(nm "${OUTPUT_LIB}/libsameboy.a" 2>/dev/null || true)
for sym in GB_init GB_run_frame GB_set_user_data GB_get_user_data GB_set_vblank_callback GB_set_pixels_output GB_load_rom; do
    if echo "${SYMBOLS}" | grep -q "${sym}"; then
        ok "Symbol found: ${sym}"
    else
        fail "Missing critical symbol: ${sym}"
    fi
done

# Check headers exist
HEADER_COUNT=$(ls -1 "${OUTPUT_INCLUDE}"/*.h 2>/dev/null | wc -l | tr -d ' ')
[ "${HEADER_COUNT}" -gt 0 ] || fail "No headers found in ${OUTPUT_INCLUDE}"
ok "Headers: ${HEADER_COUNT} files in ${OUTPUT_INCLUDE}/"

# Check architecture
ARCH_INFO=$(lipo -info "${OUTPUT_LIB}/libsameboy.a" 2>/dev/null || true)
if echo "${ARCH_INFO}" | grep -q "${ARCH}"; then
    ok "Architecture: ${ARCH} confirmed"
else
    warn "Could not confirm ${ARCH} architecture: ${ARCH_INFO}"
fi

# ── Done ─────────────────────────────────────────────────────────────
echo ""
ok "SameBoy ${SAMEBOY_TAG} built successfully!"
echo "  Library:  ${OUTPUT_LIB}/libsameboy.a"
echo "  Headers:  ${OUTPUT_INCLUDE}/"
[ -d "${OUTPUT_BOOT}" ] && echo "  BootROMs: ${OUTPUT_BOOT}/"
echo ""
