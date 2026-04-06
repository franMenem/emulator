# Phase 1: GBA Emulation (mGBA) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Game Boy Advance emulation to CrystalBoy using mGBA as the emulation core.

**Architecture:** Clone and compile mGBA as `libmgba.a` (arm64-macos, core only). Write a thin C bridge (`MGBABridge.c/h`) wrapping the `mCore` vtable API. Write `MGBAEmulator.swift` conforming to the existing `EmulatorCore` protocol. Update `project.yml` to link the new library. Update `ConsoleType.availableCores` and `GameSession.makeEmulator` to activate GBA.

**Tech Stack:** C (mGBA core via mCore API), Swift 6.2, CMake, XcodeGen.

**Spec:** `docs/superpowers/specs/2026-04-06-multi-console-design.md` — Phase 1 section.

**Reference:** SameBoy integration pattern: `SameBoyCore/` + `Bridge/SameBoyBridge.c/h` + `CrystalBoy/Core/SameBoyEmulator.swift`

---

## File Map

### New Files to Create

| File | Responsibility |
|---|---|
| `MGBACore/build.sh` | Script to clone and compile mGBA as libmgba.a |
| `Bridge/MGBABridge.h` | C bridge header: wrapper functions with opaque context |
| `Bridge/MGBABridge.c` | C bridge implementation: manages mCore, routes callbacks |
| `CrystalBoy/Core/MGBAEmulator.swift` | EmulatorCore implementation wrapping the C bridge |

### Files to Modify

| File | Changes |
|---|---|
| `CrystalBoy/CrystalBoy-Bridging-Header.h` | Add `#import "../Bridge/MGBABridge.h"` |
| `CrystalBoy/Core/ConsoleType.swift` | Add `.gba` to `availableCores` |
| `CrystalBoy/App/GameSession.swift` | Add `.gba` case to `makeEmulator` |
| `project.yml` | Add mGBA include/library paths, linker flags, Bridge compiler flags |

---

## Task 1: Compile mGBA as Static Library

**Why first:** Everything depends on this. If it fails, we need a different core or approach.

**Files:**
- Create: `MGBACore/build.sh`

- [ ] **Step 1: Create build script**

```bash
mkdir -p /Users/efmenem/Projects/CrystalBoy/MGBACore
```

Write to `MGBACore/build.sh`:

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
MGBA_DIR="$SCRIPT_DIR/mgba"
BUILD_DIR="$SCRIPT_DIR/mgba-build"
OUTPUT_DIR="$SCRIPT_DIR"

# Clone mGBA if not present
if [ ! -d "$MGBA_DIR" ]; then
    git clone --depth 1 --branch 0.10.4 https://github.com/mgba-emu/mgba.git "$MGBA_DIR"
fi

# Build as static library (core only, no frontends, no deps)
cmake -S "$MGBA_DIR" -B "$BUILD_DIR" \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
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
```

- [ ] **Step 2: Run the build script**

```bash
cd /Users/efmenem/Projects/CrystalBoy
chmod +x MGBACore/build.sh
./MGBACore/build.sh
```

Expected: Script clones mGBA, runs cmake, compiles, and copies `libmgba.a` + headers.

- [ ] **Step 3: Validate the build**

```bash
file MGBACore/libmgba.a
nm MGBACore/libmgba.a | grep "mCoreCreate" | head -3
nm MGBACore/libmgba.a | grep "GBACoreCreate" | head -3
ls MGBACore/include/mgba/core/core.h
ls MGBACore/include/mgba/gba/core.h
```

Expected: `libmgba.a` is an arm64 archive, symbols found, header files exist.

- [ ] **Step 4: Add to .gitignore**

Add to `.gitignore`:
```
MGBACore/mgba/
MGBACore/mgba-build/
```

The `libmgba.a` and `include/` should be committed (same pattern as SameBoyCore).

- [ ] **Step 5: Commit**

```bash
git add MGBACore/build.sh MGBACore/libmgba.a MGBACore/include/ .gitignore
git commit -m "feat: compile mGBA 0.10.4 as static library for arm64-macos"
```

Note: `libmgba.a` is a binary — this will be a large commit. That's expected and matches the SameBoy pattern.

---

## Task 2: Write the mGBA C Bridge

**Why:** Swift can't call mGBA's C API directly (it's a vtable struct). We need a thin C wrapper like SameBoyBridge.

**Files:**
- Create: `Bridge/MGBABridge.h`
- Create: `Bridge/MGBABridge.c`

- [ ] **Step 1: Create MGBABridge.h**

```c
#ifndef MGBABridge_h
#define MGBABridge_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// Opaque handle
typedef struct MGBAContext MGBAContext;

// Callbacks from C to Swift
typedef void (*MGBAVideoCallback)(void *userData, const uint32_t *pixels);
typedef void (*MGBAAudioCallback)(void *userData, int16_t left, int16_t right);

// Lifecycle
MGBAContext *mgba_create(void);
void mgba_destroy(MGBAContext *ctx);

// User data (Swift object pointer)
void mgba_set_user_data(MGBAContext *ctx, void *userData);
void mgba_set_video_callback(MGBAContext *ctx, MGBAVideoCallback callback);
void mgba_set_audio_callback(MGBAContext *ctx, MGBAAudioCallback callback);

// ROM
bool mgba_load_rom(MGBAContext *ctx, const char *path);

// Emulation
void mgba_run_frame(MGBAContext *ctx);

// Input — bitmask: A=0, B=1, SELECT=2, START=3, RIGHT=4, LEFT=5, UP=6, DOWN=7, R=8, L=9
void mgba_set_keys(MGBAContext *ctx, uint32_t keys);

// Save / Load battery (SRAM)
bool mgba_save_battery(MGBAContext *ctx, const char *path);
bool mgba_load_battery(MGBAContext *ctx, const char *path);

// Save states
bool mgba_save_state(MGBAContext *ctx, const char *path);
bool mgba_load_state(MGBAContext *ctx, const char *path);

// Cheats
void mgba_add_cheat(MGBAContext *ctx, const char *code, const char *description);
void mgba_remove_all_cheats(MGBAContext *ctx);

// Audio
void mgba_set_sample_rate(MGBAContext *ctx, uint32_t sampleRate);

// Screen dimensions
unsigned int mgba_get_screen_width(MGBAContext *ctx);
unsigned int mgba_get_screen_height(MGBAContext *ctx);

#endif
```

- [ ] **Step 2: Create MGBABridge.c**

```c
#include "MGBABridge.h"
#include <mgba/core/core.h>
#include <mgba/core/cheats.h>
#include <mgba/gba/core.h>
#include <mgba-util/vfs.h>
#include <mgba-util/audio-buffer.h>
#include <stdlib.h>
#include <string.h>

#define GBA_WIDTH 240
#define GBA_HEIGHT 160
#define GBA_AUDIO_SAMPLES 2048

struct MGBAContext {
    struct mCore *core;
    uint32_t pixelBuffer[GBA_WIDTH * GBA_HEIGHT];
    int16_t audioBuffer[GBA_AUDIO_SAMPLES * 2]; // stereo
    MGBAVideoCallback videoCallback;
    MGBAAudioCallback audioCallback;
    void *userData;
    uint32_t currentKeys;
    uint32_t targetSampleRate;
};

// --- Pixel format conversion ---
// mGBA outputs XBGR8 (0x00BBGGRR), CGImage expects XRGB (0x00RRGGBB)
static inline uint32_t xbgr_to_xrgb(uint32_t pixel) {
    uint32_t r = (pixel >>  0) & 0xFF;
    uint32_t g = (pixel >>  8) & 0xFF;
    uint32_t b = (pixel >> 16) & 0xFF;
    return (0xFF << 24) | (r << 16) | (g << 8) | b;
}

// --- Public API ---

MGBAContext *mgba_create(void) {
    MGBAContext *ctx = calloc(1, sizeof(MGBAContext));
    ctx->core = GBACoreCreate();
    if (!ctx->core) {
        free(ctx);
        return NULL;
    }
    ctx->core->init(ctx->core);
    ctx->core->setVideoBuffer(ctx->core, (color_t *)ctx->pixelBuffer, GBA_WIDTH);
    ctx->core->setAudioBufferSize(ctx->core, GBA_AUDIO_SAMPLES);
    ctx->targetSampleRate = 32768;
    return ctx;
}

void mgba_destroy(MGBAContext *ctx) {
    if (!ctx) return;
    ctx->core->deinit(ctx->core);
    free(ctx);
}

void mgba_set_user_data(MGBAContext *ctx, void *userData) {
    ctx->userData = userData;
}

void mgba_set_video_callback(MGBAContext *ctx, MGBAVideoCallback callback) {
    ctx->videoCallback = callback;
}

void mgba_set_audio_callback(MGBAContext *ctx, MGBAAudioCallback callback) {
    ctx->audioCallback = callback;
}

bool mgba_load_rom(MGBAContext *ctx, const char *path) {
    if (!mCoreLoadFile(ctx->core, path)) return false;
    mCoreAutoloadSave(ctx->core);
    ctx->core->reset(ctx->core);
    return true;
}

void mgba_run_frame(MGBAContext *ctx) {
    // Set input
    ctx->core->setKeys(ctx->core, ctx->currentKeys);

    // Run one frame
    ctx->core->runFrame(ctx->core);

    // Convert pixel buffer from XBGR to XRGB and deliver
    if (ctx->videoCallback) {
        // In-place conversion
        for (int i = 0; i < GBA_WIDTH * GBA_HEIGHT; i++) {
            ctx->pixelBuffer[i] = xbgr_to_xrgb(ctx->pixelBuffer[i]);
        }
        ctx->videoCallback(ctx->userData, ctx->pixelBuffer);
    }

    // Drain audio buffer and deliver samples
    if (ctx->audioCallback) {
        struct mAudioBuffer *audioBuffer = ctx->core->getAudioBuffer(ctx->core);
        int16_t samples[GBA_AUDIO_SAMPLES * 2];
        size_t available = mAudioBufferAvailable(audioBuffer);
        while (available > 0) {
            size_t count = available > GBA_AUDIO_SAMPLES ? GBA_AUDIO_SAMPLES : available;
            size_t read = mAudioBufferRead(audioBuffer, samples, count);
            for (size_t i = 0; i < read; i++) {
                ctx->audioCallback(ctx->userData, samples[i * 2], samples[i * 2 + 1]);
            }
            available = mAudioBufferAvailable(audioBuffer);
        }
    }
}

void mgba_set_keys(MGBAContext *ctx, uint32_t keys) {
    ctx->currentKeys = keys;
}

bool mgba_save_battery(MGBAContext *ctx, const char *path) {
    struct VFile *vf = VFileOpen(path, O_WRONLY | O_CREAT | O_TRUNC);
    if (!vf) return false;
    ctx->core->savedataClone(ctx->core, NULL); // flush
    void *sram = NULL;
    size_t size = ctx->core->savedataClone(ctx->core, &sram);
    if (sram && size > 0) {
        vf->write(vf, sram, size);
        free(sram);
    }
    vf->close(vf);
    return true;
}

bool mgba_load_battery(MGBAContext *ctx, const char *path) {
    struct VFile *vf = VFileOpen(path, O_RDONLY);
    if (!vf) return false;
    bool ok = ctx->core->loadSave(ctx->core, vf);
    // Note: VFile is now owned by the core, don't close it
    return ok;
}

bool mgba_save_state(MGBAContext *ctx, const char *path) {
    struct VFile *vf = VFileOpen(path, O_WRONLY | O_CREAT | O_TRUNC);
    if (!vf) return false;
    bool ok = mCoreSaveStateNamed(ctx->core, vf, SAVESTATE_ALL);
    vf->close(vf);
    return ok;
}

bool mgba_load_state(MGBAContext *ctx, const char *path) {
    struct VFile *vf = VFileOpen(path, O_RDONLY);
    if (!vf) return false;
    bool ok = mCoreLoadStateNamed(ctx->core, vf, SAVESTATE_ALL);
    vf->close(vf);
    return ok;
}

void mgba_add_cheat(MGBAContext *ctx, const char *code, const char *description) {
    struct mCheatDevice *device = ctx->core->cheatDevice(ctx->core);
    if (!device) return;
    struct mCheatSet *set = device->createSet(device, description ? description : "");
    if (!set) return;
    mCheatAddLine(set, code, 0); // 0 = auto-detect format
    set->enabled = true;
    mCheatAddSet(device, set);
}

void mgba_remove_all_cheats(MGBAContext *ctx) {
    struct mCheatDevice *device = ctx->core->cheatDevice(ctx->core);
    if (!device) return;
    mCheatDeviceClear(device);
}

void mgba_set_sample_rate(MGBAContext *ctx, uint32_t sampleRate) {
    ctx->targetSampleRate = sampleRate;
    // mGBA's native rate is 32768Hz. Resampling would be needed for different rates.
    // For now, the AudioEngine handles rate differences.
}

unsigned int mgba_get_screen_width(MGBAContext *ctx) {
    return GBA_WIDTH;
}

unsigned int mgba_get_screen_height(MGBAContext *ctx) {
    return GBA_HEIGHT;
}
```

**IMPORTANT NOTES for the implementer:**
- The `color_t` type may be defined differently in mGBA headers — check `mgba-util/image.h`. If it's not `uint32_t`, cast accordingly.
- The `O_RDONLY`, `O_WRONLY`, etc. constants need `#include <fcntl.h>`.
- `mAudioBufferAvailable` and `mAudioBufferRead` are from `mgba-util/audio-buffer.h`.
- The `SAVESTATE_ALL` flag is from `mgba/core/serialize.h`.
- If any function or type is not found during compilation, check the mGBA headers in `MGBACore/include/` and adjust includes.

- [ ] **Step 3: Verify both files are syntactically correct**

The files won't compile yet (not linked into the project), but you can check syntax:

```bash
cd /Users/efmenem/Projects/CrystalBoy
clang -fsyntax-only -I MGBACore/include Bridge/MGBABridge.c
```

If there are header issues, fix them by checking the actual header paths in `MGBACore/include/`.

- [ ] **Step 4: Commit**

```bash
git add Bridge/MGBABridge.h Bridge/MGBABridge.c
git commit -m "feat: add mGBA C bridge for GBA emulation"
```

---

## Task 3: Write MGBAEmulator.swift

**Why:** The Swift wrapper that conforms to `EmulatorCore`, following the exact same pattern as `SameBoyEmulator.swift`.

**Files:**
- Create: `CrystalBoy/Core/MGBAEmulator.swift`

- [ ] **Step 1: Create MGBAEmulator.swift**

```swift
import Foundation

final class MGBAEmulator: EmulatorCore {
    private var context: OpaquePointer?
    private var videoCallback: ((UnsafePointer<UInt32>) -> Void)?
    private var audioCallback: ((Int16, Int16) -> Void)?

    // GBA button bitmask mapping
    // mGBA: A=0, B=1, SELECT=2, START=3, RIGHT=4, LEFT=5, UP=6, DOWN=7, R=8, L=9
    private var keyState: UInt32 = 0

    var screenWidth: Int {
        guard let ctx = context else { return 240 }
        return Int(mgba_get_screen_width(ctx))
    }

    var screenHeight: Int {
        guard let ctx = context else { return 160 }
        return Int(mgba_get_screen_height(ctx))
    }

    init() {
        context = mgba_create()
        registerCallbacks()
    }

    deinit {
        if let context {
            mgba_destroy(context)
        }
    }

    func loadROM(url: URL) throws {
        guard let ctx = context else { return }
        let loaded = mgba_load_rom(ctx, url.path)
        if !loaded {
            throw NSError(domain: "CrystalBoy", code: 2,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load GBA ROM: \(url.lastPathComponent)"])
        }
    }

    func unloadROM() {
        guard let context else { return }
        mgba_destroy(context)
        self.context = mgba_create()
        keyState = 0
        registerCallbacks()
    }

    func runFrame() {
        guard let ctx = context else { return }
        mgba_set_keys(ctx, keyState)
        mgba_run_frame(ctx)
    }

    func setInput(button: GameButton, pressed: Bool) {
        // Map GameButton to GBA bitmask position
        let bit: Int
        switch button {
        case .a:      bit = 0
        case .b:      bit = 1
        case .select: bit = 2
        case .start:  bit = 3
        case .right:  bit = 4
        case .left:   bit = 5
        case .up:     bit = 6
        case .down:   bit = 7
        case .r:      bit = 8
        case .l:      bit = 9
        default:      return // Ignore buttons not used by GBA
        }

        if pressed {
            keyState |= UInt32(1 << bit)
        } else {
            keyState &= ~UInt32(1 << bit)
        }
    }

    func setVideoCallback(_ callback: @escaping (UnsafePointer<UInt32>) -> Void) {
        videoCallback = callback
    }

    func setAudioCallback(_ callback: @escaping (Int16, Int16) -> Void) {
        audioCallback = callback
    }

    func setSampleRate(_ rate: UInt32) {
        guard let ctx = context else { return }
        mgba_set_sample_rate(ctx, rate)
    }

    func saveBattery(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return mgba_save_battery(ctx, url.path)
    }

    func loadBattery(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return mgba_load_battery(ctx, url.path)
    }

    func saveState(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return mgba_save_state(ctx, url.path)
    }

    func loadState(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return mgba_load_state(ctx, url.path)
    }

    func setRewindLength(seconds: Double) {
        // mGBA doesn't have built-in rewind like SameBoy
        // Rewind would need to be implemented via save state snapshots
        // For now, this is a no-op
    }

    func rewindPop() -> Bool {
        // Not implemented for GBA
        return false
    }

    func addCheat(code: String, description: String) {
        guard let ctx = context else { return }
        mgba_add_cheat(ctx, code, description)
    }

    func removeAllCheats() {
        guard let ctx = context else { return }
        mgba_remove_all_cheats(ctx)
    }

    // MARK: - Private

    private func registerCallbacks() {
        guard let ctx = context else { return }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        mgba_set_user_data(ctx, selfPtr)

        mgba_set_video_callback(ctx) { userData, pixels in
            guard let userData, let pixels else { return }
            let emulator = Unmanaged<MGBAEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.videoCallback?(pixels)
        }

        mgba_set_audio_callback(ctx) { userData, left, right in
            guard let userData else { return }
            let emulator = Unmanaged<MGBAEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.audioCallback?(left, right)
        }
    }
}
```

- [ ] **Step 2: Commit (won't compile yet — needs project.yml changes)**

```bash
git add CrystalBoy/Core/MGBAEmulator.swift
git commit -m "feat: add MGBAEmulator.swift conforming to EmulatorCore"
```

---

## Task 4: Update Project Configuration and Activate GBA

**Why:** Wire everything together — project.yml, bridging header, ConsoleType, GameSession.

**Files:**
- Modify: `project.yml`
- Modify: `CrystalBoy/CrystalBoy-Bridging-Header.h`
- Modify: `CrystalBoy/Core/ConsoleType.swift`
- Modify: `CrystalBoy/App/GameSession.swift`

- [ ] **Step 1: Update bridging header**

Add to `CrystalBoy/CrystalBoy-Bridging-Header.h`:
```c
#import "../Bridge/MGBABridge.h"
```

- [ ] **Step 2: Update project.yml**

Update `HEADER_SEARCH_PATHS` to include mGBA headers:
```yaml
        HEADER_SEARCH_PATHS:
          - "$(SRCROOT)/SameBoyCore/include"
          - "$(SRCROOT)/MGBACore/include"
          - "$(SRCROOT)/Bridge"
```

Update `LIBRARY_SEARCH_PATHS` to include mGBA:
```yaml
        LIBRARY_SEARCH_PATHS:
          - "$(SRCROOT)/SameBoyCore"
          - "$(SRCROOT)/MGBACore"
```

Update `OTHER_LDFLAGS` to link mGBA:
```yaml
        OTHER_LDFLAGS:
          - "-lsameboy"
          - "-lmgba"
          - "-lm"
```

Update Bridge compiler flags to include mGBA headers:
```yaml
      - path: Bridge
        type: group
        compilerFlags:
          - "-I$(SRCROOT)/SameBoyCore/include"
          - "-I$(SRCROOT)/MGBACore/include"
```

- [ ] **Step 3: Regenerate Xcode project**

```bash
cd /Users/efmenem/Projects/CrystalBoy
xcodegen generate
```

- [ ] **Step 4: Update ConsoleType.availableCores**

In `CrystalBoy/Core/ConsoleType.swift`, change:
```swift
    static let availableCores: Set<ConsoleType> = [.gb, .gbc]
```
To:
```swift
    static let availableCores: Set<ConsoleType> = [.gb, .gbc, .gba]
```

- [ ] **Step 5: Update GameSession.makeEmulator**

In `CrystalBoy/App/GameSession.swift`, update the factory:
```swift
    private func makeEmulator(for rom: ROMItem) -> EmulatorCore? {
        switch rom.consoleType {
        case .gb, .gbc:
            return SameBoyEmulator(isColorGB: rom.consoleType == .gbc)
        case .gba:
            return MGBAEmulator()
        case .nes, .snes, .genesis:
            return nil
        }
    }
```

- [ ] **Step 6: Update EmulationThread frame rate for GBA**

In `CrystalBoy/Core/EmulationThread.swift`, the frame rate is hardcoded to `1.0 / 59.7275` (GB). For GBA, the frame rate is the same (~59.73 FPS), so no change needed. But note this for future cores (NES = 60.098 FPS).

- [ ] **Step 7: Verify it compiles**

```bash
cd /Users/efmenem/Projects/CrystalBoy
xcodebuild -scheme CrystalBoy -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -30
```

If compilation fails:
- **Linker errors** about undefined mGBA symbols → check `libmgba.a` is in `MGBACore/` and `OTHER_LDFLAGS` has `-lmgba`
- **Header not found** → check `HEADER_SEARCH_PATHS` and `compilerFlags` in project.yml
- **Type mismatches in MGBABridge.c** → check mGBA header types (`color_t`, `mColor`, etc.) and adjust casts
- **Missing `fcntl.h`** → add `#include <fcntl.h>` to MGBABridge.c

Fix any compilation issues before proceeding.

- [ ] **Step 8: Commit**

```bash
git add project.yml CrystalBoy/CrystalBoy-Bridging-Header.h CrystalBoy/Core/ConsoleType.swift CrystalBoy/App/GameSession.swift CrystalBoy.xcodeproj/
git commit -m "feat: activate GBA emulation via mGBA core"
```

---

## Task 5: Final Verification

- [ ] **Step 1: Clean build**

```bash
cd /Users/efmenem/Projects/CrystalBoy
xcodebuild clean -scheme CrystalBoy -destination 'platform=macOS' -quiet
xcodebuild -scheme CrystalBoy -destination 'platform=macOS,arch=arm64' build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Test with a GBA ROM**

1. Place a `.gba` ROM in the ROM folder
2. Launch the app
3. Library should show the ROM with a blue "GBA" badge
4. Filter pills should include "GBA"
5. Double-click to play → GBA game should load and render at 240x160
6. Controls: Arrow keys + Z (A) + X (B) + A (L) + S (R) + Enter (Start) + Backspace (Select)
7. Save/load states should work (F5/F7)
8. Cheats modal (star icon or Cmd+K) should work
9. Volume controls should work
10. Back to library (Esc) should work

- [ ] **Step 3: Verify GB/GBC still works**

Open a GB/GBC ROM and verify nothing is broken.

- [ ] **Step 4: Commit any fixes**

```bash
git add -A
git commit -m "fix: resolve issues from GBA integration"
```

---

## Known Limitations (GBA vs GB/GBC)

- **No rewind:** mGBA doesn't have built-in rewind like SameBoy. `setRewindLength` and `rewindPop` are no-ops for GBA.
- **Audio sample rate:** mGBA outputs at 32768 Hz vs SameBoy's 48000 Hz. The AudioEngine should handle this via `setSampleRate`, but there may be pitch/speed issues if the rates don't match.
- **Battery saves:** mGBA handles saves internally via `mCoreAutoloadSave`. The bridge's `save_battery`/`load_battery` use `savedataClone`/`loadSave` which may behave differently than SameBoy's direct file I/O.
- **Pixel format:** mGBA outputs XBGR8, bridge converts to ARGB for CGImage compatibility. This adds a small per-frame cost (240*160 pixel conversions).
