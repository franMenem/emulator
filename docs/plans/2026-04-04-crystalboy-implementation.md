# CrystalBoy Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS Game Boy Color emulator wrapping SameBoy's core in a minimal SwiftUI app.

**Architecture:** SameBoy compiled as libsameboy.a → C bridge with user_data context → Swift EmulatorCore protocol → CGImage rendering + AVAudioEngine + GCController input → minimal SwiftUI UI.

**Tech Stack:** Swift 6.2, SwiftUI, C (SameBoy core), AVAudioEngine, GCController, CGImage/CALayer.

**Spec:** `docs/specs/2026-04-04-crystalboy-design.md`

---

## File Map

### New Files to Create

| File | Responsibility |
|---|---|
| `SameBoyCore/build.sh` | Script to clone and compile SameBoy as libsameboy.a |
| `SameBoyCore/module.modulemap` | Expose SameBoy C headers to Swift |
| `Bridge/SameBoyBridge.h` | C bridge header: wrapper functions with opaque context |
| `Bridge/SameBoyBridge.c` | C bridge implementation: manages GB_gameboy_t, routes callbacks |
| `CrystalBoy/Core/EmulatorCore.swift` | Protocol defining generic emulator interface |
| `CrystalBoy/Core/SameBoyEmulator.swift` | Protocol implementation wrapping the C bridge |
| `CrystalBoy/Core/EmulationThread.swift` | Dedicated thread running the emulation loop |
| `CrystalBoy/Rendering/GameView.swift` | NSView subclass rendering frame buffer via CGImage |
| `CrystalBoy/Input/InputManager.swift` | Keyboard + gamepad input handling |
| `CrystalBoy/Input/KeyBindings.swift` | Configurable key mappings persisted in UserDefaults |
| `CrystalBoy/Audio/AudioEngine.swift` | AVAudioEngine + AVAudioSourceNode for audio output |
| `CrystalBoy/Save/SaveManager.swift` | Battery saves (.sav) auto-save + save states (slots) |
| `CrystalBoy/Features/CheatManager.swift` | Game Shark / Game Genie cheat management |
| `CrystalBoy/Library/LibraryManager.swift` | ROM folder scanning |
| `CrystalBoy/Library/LibraryView.swift` | ROM list UI |
| `CrystalBoy/Game/GameScreen.swift` | Game screen: GameView + toast overlay + pause logic |
| `CrystalBoy/Settings/ControlsSettingsView.swift` | Key binding configuration modal |
| `CrystalBoy/App/CrystalBoyApp.swift` | App entry point |
| `CrystalBoy/App/AppState.swift` | Navigation and global state |
| `CrystalBoy/CrystalBoy-Bridging-Header.h` | Xcode bridging header importing SameBoyBridge.h |

---

## Task 1: Compile SameBoy as Static Library

**Why first:** Everything depends on this. If it fails, we fallback to Gambatte.

**Files:**
- Create: `SameBoyCore/build.sh`

- [ ] **Step 1: Create build script**

```bash
#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAMEBOY_DIR="$SCRIPT_DIR/SameBoy"
OUTPUT_DIR="$SCRIPT_DIR"

# Clone SameBoy if not present
if [ ! -d "$SAMEBOY_DIR" ]; then
    git clone https://github.com/LIJI32/SameBoy.git "$SAMEBOY_DIR"
fi

cd "$SAMEBOY_DIR"
git checkout v1.0.3

# Build the core library only
make lib CONF=release CC="clang -arch arm64"

# Copy artifacts
cp build/lib/libsameboy.a "$OUTPUT_DIR/libsameboy.a"
mkdir -p "$OUTPUT_DIR/include"
cp -R build/include/sameboy/* "$OUTPUT_DIR/include/"

echo "Done: libsameboy.a and headers in $OUTPUT_DIR"
```

- [ ] **Step 2: Run the build script**

```bash
cd /Users/efmenem/Projects/CrystalBoy
chmod +x SameBoyCore/build.sh
./SameBoyCore/build.sh
```

- [ ] **Step 3: Validate the build**

```bash
# Check library exists and has GB_ symbols
file SameBoyCore/libsameboy.a
nm SameBoyCore/libsameboy.a | grep "GB_run_frame"
nm SameBoyCore/libsameboy.a | grep "GB_set_pixels_output"
nm SameBoyCore/libsameboy.a | grep "GB_set_user_data"
ls SameBoyCore/include/gb.h
```

Expected: `libsameboy.a` is an arm64 archive, symbols found, `gb.h` exists.

- [ ] **Step 4: Create module map for Swift**

Create `SameBoyCore/module.modulemap`:

```
module SameBoyCore {
    header "include/gb.h"
    link "sameboy"
    export *
}
```

- [ ] **Step 5: Build boot ROMs (optional)**

```bash
cd /Users/efmenem/Projects/CrystalBoy/SameBoyCore/SameBoy
make bootroms
mkdir -p ../BootROMs
cp build/bin/BootROMs/cgb_boot.bin ../BootROMs/
cp build/bin/BootROMs/dmg_boot.bin ../BootROMs/
```

If RGBDS is not installed, skip this step — SameBoy works without boot ROMs (skips boot animation).

- [ ] **Step 6: Commit**

```bash
git init /Users/efmenem/Projects/CrystalBoy
cd /Users/efmenem/Projects/CrystalBoy
echo "SameBoyCore/SameBoy/" >> .gitignore
echo ".DS_Store" >> .gitignore
git add SameBoyCore/build.sh SameBoyCore/module.modulemap SameBoyCore/libsameboy.a SameBoyCore/include/ .gitignore docs/
git commit -m "feat: compile SameBoy core as static library"
```

**Checkpoint:** `nm SameBoyCore/libsameboy.a | grep GB_run_frame` shows the symbol.

---

## Task 2: Xcode Project + C Bridge

**Files:**
- Create: `Bridge/SameBoyBridge.h`
- Create: `Bridge/SameBoyBridge.c`
- Create: `CrystalBoy/CrystalBoy-Bridging-Header.h`
- Create: Xcode project

- [ ] **Step 1: Create Xcode project**

Create a new macOS App project in Xcode:
- Product name: CrystalBoy
- Team: None
- Organization: Personal
- Interface: SwiftUI
- Language: Swift
- Location: `/Users/efmenem/Projects/CrystalBoy/`

Configure build settings:
- Add `SameBoyCore/` to Header Search Paths
- Add `SameBoyCore/libsameboy.a` to Link Binary with Libraries
- Set Bridging Header to `CrystalBoy/CrystalBoy-Bridging-Header.h`
- Add `-lm` to Other Linker Flags

- [ ] **Step 2: Write the C bridge header**

`Bridge/SameBoyBridge.h`:

```c
#ifndef SameBoyBridge_h
#define SameBoyBridge_h

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>

// Opaque handle
typedef struct SBContext SBContext;

// Callbacks from C to Swift
typedef void (*SBVideoCallback)(void *userData, const uint32_t *pixels);
typedef void (*SBAudioCallback)(void *userData, int16_t left, int16_t right);

// Lifecycle
SBContext *sb_create(bool isColorGB);
void sb_destroy(SBContext *ctx);

// User data (Swift object pointer)
void sb_set_user_data(SBContext *ctx, void *userData);
void sb_set_video_callback(SBContext *ctx, SBVideoCallback callback);
void sb_set_audio_callback(SBContext *ctx, SBAudioCallback callback);

// ROM
bool sb_load_rom(SBContext *ctx, const char *path);
bool sb_load_boot_rom(SBContext *ctx, const char *path);

// Emulation
uint64_t sb_run_frame(SBContext *ctx);

// Input
void sb_set_key(SBContext *ctx, int key, bool pressed);

// Save / Load battery (SRAM)
bool sb_save_battery(SBContext *ctx, const char *path);
bool sb_load_battery(SBContext *ctx, const char *path);

// Save states
size_t sb_save_state_size(SBContext *ctx);
bool sb_save_state(SBContext *ctx, const char *path);
bool sb_load_state(SBContext *ctx, const char *path);

// Rewind
void sb_set_rewind_length(SBContext *ctx, double seconds);
bool sb_rewind_pop(SBContext *ctx);

// Cheats
void sb_add_cheat(SBContext *ctx, const char *code, const char *description);
void sb_remove_all_cheats(SBContext *ctx);

// Audio
void sb_set_sample_rate(SBContext *ctx, unsigned int sampleRate);

// Screen dimensions
unsigned int sb_get_screen_width(SBContext *ctx);
unsigned int sb_get_screen_height(SBContext *ctx);

#endif
```

- [ ] **Step 3: Write the C bridge implementation**

`Bridge/SameBoyBridge.c`:

```c
#include "SameBoyBridge.h"
#include "gb.h"
#include <stdlib.h>
#include <string.h>

struct SBContext {
    GB_gameboy_t *gb;
    uint32_t pixelBuffer[256 * 224]; // max size (SGB), GB/GBC uses 160x144
    SBVideoCallback videoCallback;
    SBAudioCallback audioCallback;
    void *userData;
};

// --- Callbacks routed to Swift ---

static uint32_t rgb_encode(GB_gameboy_t *gb, uint8_t r, uint8_t g, uint8_t b) {
    return (0xFF << 24) | (r << 16) | (g << 8) | b; // ARGB
}

static void vblank_callback(GB_gameboy_t *gb) {
    SBContext *ctx = (SBContext *)GB_get_user_data(gb);
    if (ctx->videoCallback) {
        ctx->videoCallback(ctx->userData, ctx->pixelBuffer);
    }
}

static void audio_callback(GB_gameboy_t *gb, GB_sample_t *sample) {
    SBContext *ctx = (SBContext *)GB_get_user_data(gb);
    if (ctx->audioCallback) {
        ctx->audioCallback(ctx->userData, sample->left, sample->right);
    }
}

// --- Public API ---

SBContext *sb_create(bool isColorGB) {
    SBContext *ctx = calloc(1, sizeof(SBContext));
    ctx->gb = GB_alloc();
    GB_init(ctx->gb, isColorGB ? GB_MODEL_CGB_E : GB_MODEL_DMG_B);
    GB_set_user_data(ctx->gb, ctx);
    GB_set_pixels_output(ctx->gb, ctx->pixelBuffer);
    GB_set_rgb_encode_callback(ctx->gb, rgb_encode);
    GB_set_vblank_callback(ctx->gb, vblank_callback);
    return ctx;
}

void sb_destroy(SBContext *ctx) {
    if (!ctx) return;
    GB_free(ctx->gb);
    GB_dealloc(ctx->gb);
    free(ctx);
}

void sb_set_user_data(SBContext *ctx, void *userData) {
    ctx->userData = userData;
}

void sb_set_video_callback(SBContext *ctx, SBVideoCallback callback) {
    ctx->videoCallback = callback;
}

void sb_set_audio_callback(SBContext *ctx, SBAudioCallback callback) {
    ctx->audioCallback = callback;
    if (callback) {
        GB_apu_set_sample_callback(ctx->gb, audio_callback);
    }
}

bool sb_load_rom(SBContext *ctx, const char *path) {
    return GB_load_rom(ctx->gb, path) == 0;
}

bool sb_load_boot_rom(SBContext *ctx, const char *path) {
    return GB_load_boot_rom(ctx->gb, path) == 0;
}

uint64_t sb_run_frame(SBContext *ctx) {
    return GB_run_frame(ctx->gb);
}

void sb_set_key(SBContext *ctx, int key, bool pressed) {
    GB_set_key_state(ctx->gb, (GB_key_t)key, pressed);
}

bool sb_save_battery(SBContext *ctx, const char *path) {
    return GB_save_battery(ctx->gb, path) == 0;
}

bool sb_load_battery(SBContext *ctx, const char *path) {
    return GB_load_battery(ctx->gb, path) == 0;
}

size_t sb_save_state_size(SBContext *ctx) {
    return GB_get_save_state_size(ctx->gb);
}

bool sb_save_state(SBContext *ctx, const char *path) {
    return GB_save_state(ctx->gb, path) == 0;
}

bool sb_load_state(SBContext *ctx, const char *path) {
    return GB_load_state(ctx->gb, path) == 0;
}

void sb_set_rewind_length(SBContext *ctx, double seconds) {
    GB_set_rewind_length(ctx->gb, seconds);
}

bool sb_rewind_pop(SBContext *ctx) {
    return GB_rewind_pop(ctx->gb);
}

void sb_add_cheat(SBContext *ctx, const char *code, const char *description) {
    GB_import_cheat(ctx->gb, code, description, true);
}

void sb_remove_all_cheats(SBContext *ctx) {
    size_t count;
    while (true) {
        const GB_cheat_t *const *cheats = GB_get_cheats(ctx->gb, &count);
        if (count == 0) break;
        GB_remove_cheat(ctx->gb, cheats[0]);
    }
}

void sb_set_sample_rate(SBContext *ctx, unsigned int sampleRate) {
    GB_set_sample_rate(ctx->gb, sampleRate);
}

unsigned int sb_get_screen_width(SBContext *ctx) {
    return GB_get_screen_width(ctx->gb);
}

unsigned int sb_get_screen_height(SBContext *ctx) {
    return GB_get_screen_height(ctx->gb);
}
```

- [ ] **Step 4: Create bridging header**

`CrystalBoy/CrystalBoy-Bridging-Header.h`:

```c
#import "../Bridge/SameBoyBridge.h"
```

- [ ] **Step 5: Verify project compiles**

Build the project in Xcode (Cmd+B). It should compile with no errors. The bridge functions should be visible from Swift (autocomplete `sb_create`).

- [ ] **Step 6: Commit**

```bash
git add Bridge/ CrystalBoy/
git commit -m "feat: add C bridge wrapping SameBoy core"
```

**Checkpoint:** Xcode project compiles. Typing `sb_create` in a Swift file shows autocomplete.

---

## Task 3: EmulatorCore Protocol + SameBoyEmulator

**Files:**
- Create: `CrystalBoy/Core/EmulatorCore.swift`
- Create: `CrystalBoy/Core/SameBoyEmulator.swift`

- [ ] **Step 1: Define the protocol**

`CrystalBoy/Core/EmulatorCore.swift`:

```swift
import Foundation

enum GameButton: Int {
    case right = 0, left, up, down, a, b, select, start
}

enum CheatType {
    case gameShark
    case gameGenie
}

protocol EmulatorCore: AnyObject {
    var screenWidth: Int { get }
    var screenHeight: Int { get }

    func loadROM(url: URL) throws
    func unloadROM()

    func runFrame()

    func setInput(button: GameButton, pressed: Bool)

    func setVideoCallback(_ callback: @escaping (UnsafePointer<UInt32>) -> Void)
    func setAudioCallback(_ callback: @escaping (Int16, Int16) -> Void)
    func setSampleRate(_ rate: UInt32)

    func saveBattery(to url: URL) -> Bool
    func loadBattery(from url: URL) -> Bool

    func saveState(to url: URL) -> Bool
    func loadState(from url: URL) -> Bool

    func setRewindLength(seconds: Double)
    func rewindPop() -> Bool

    func addCheat(code: String, description: String)
    func removeAllCheats()
}
```

- [ ] **Step 2: Implement SameBoyEmulator**

`CrystalBoy/Core/SameBoyEmulator.swift`:

```swift
import Foundation

final class SameBoyEmulator: EmulatorCore {
    private var context: OpaquePointer?
    private var videoCallback: ((UnsafePointer<UInt32>) -> Void)?
    private var audioCallback: ((Int16, Int16) -> Void)?

    var screenWidth: Int {
        guard let ctx = context else { return 160 }
        return Int(sb_get_screen_width(ctx))
    }

    var screenHeight: Int {
        guard let ctx = context else { return 144 }
        return Int(sb_get_screen_height(ctx))
    }

    init(isColorGB: Bool = true) {
        context = sb_create(isColorGB)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        sb_set_user_data(context, selfPtr)

        sb_set_video_callback(context) { userData, pixels in
            guard let userData, let pixels else { return }
            let emulator = Unmanaged<SameBoyEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.videoCallback?(pixels)
        }

        sb_set_audio_callback(context) { userData, left, right in
            guard let userData else { return }
            let emulator = Unmanaged<SameBoyEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.audioCallback?(left, right)
        }
    }

    deinit {
        if let context {
            sb_destroy(context)
        }
    }

    func loadROM(url: URL) throws {
        guard let ctx = context else { return }
        let loaded = sb_load_rom(ctx, url.path)
        if !loaded {
            throw NSError(domain: "CrystalBoy", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load ROM: \(url.lastPathComponent)"])
        }

        // Try loading boot ROM if available
        let bootROMPath = Bundle.main.path(forResource: "cgb_boot", ofType: "bin")
        if let bootROMPath {
            sb_load_boot_rom(ctx, bootROMPath)
        }
    }

    func unloadROM() {
        guard let context else { return }
        sb_destroy(context)
        self.context = sb_create(true)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        sb_set_user_data(self.context, selfPtr)
    }

    func runFrame() {
        guard let ctx = context else { return }
        _ = sb_run_frame(ctx)
    }

    func setInput(button: GameButton, pressed: Bool) {
        guard let ctx = context else { return }
        sb_set_key(ctx, Int32(button.rawValue), pressed)
    }

    func setVideoCallback(_ callback: @escaping (UnsafePointer<UInt32>) -> Void) {
        videoCallback = callback
    }

    func setAudioCallback(_ callback: @escaping (Int16, Int16) -> Void) {
        audioCallback = callback
    }

    func setSampleRate(_ rate: UInt32) {
        guard let ctx = context else { return }
        sb_set_sample_rate(ctx, rate)
    }

    func saveBattery(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return sb_save_battery(ctx, url.path)
    }

    func loadBattery(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return sb_load_battery(ctx, url.path)
    }

    func saveState(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return sb_save_state(ctx, url.path)
    }

    func loadState(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return sb_load_state(ctx, url.path)
    }

    func setRewindLength(seconds: Double) {
        guard let ctx = context else { return }
        sb_set_rewind_length(ctx, seconds)
    }

    func rewindPop() -> Bool {
        guard let ctx = context else { return false }
        return sb_rewind_pop(ctx)
    }

    func addCheat(code: String, description: String) {
        guard let ctx = context else { return }
        sb_add_cheat(ctx, code, description)
    }

    func removeAllCheats() {
        guard let ctx = context else { return }
        sb_remove_all_cheats(ctx)
    }
}
```

- [ ] **Step 3: Verify it compiles**

Build in Xcode. Should compile with no errors.

- [ ] **Step 4: Commit**

```bash
git add CrystalBoy/Core/
git commit -m "feat: add EmulatorCore protocol and SameBoy implementation"
```

**Checkpoint:** Project compiles. `SameBoyEmulator` conforms to `EmulatorCore`.

---

## Task 4: Rendering (GameView)

**Files:**
- Create: `CrystalBoy/Rendering/GameView.swift`

- [ ] **Step 1: Implement GameView**

`CrystalBoy/Rendering/GameView.swift`:

```swift
import Cocoa
import SwiftUI

final class GameNSView: NSView {
    private var currentFrame: CGImage?
    private let width = 160
    private let height = 144

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor
        layer?.magnificationFilter = .nearest
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) not implemented")
    }

    func updateFrame(pixels: UnsafePointer<UInt32>) {
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

        guard let context = CGContext(
            data: UnsafeMutablePointer(mutating: pixels),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return }

        currentFrame = context.makeImage()
        DispatchQueue.main.async { [weak self] in
            self?.needsDisplay = true
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let currentFrame, let cgContext = NSGraphicsContext.current?.cgContext else { return }

        cgContext.interpolationQuality = .none // nearest neighbor

        let viewAspect = bounds.width / bounds.height
        let gameAspect = CGFloat(width) / CGFloat(height)

        var drawRect: CGRect
        if viewAspect > gameAspect {
            let drawHeight = bounds.height
            let drawWidth = drawHeight * gameAspect
            drawRect = CGRect(x: (bounds.width - drawWidth) / 2, y: 0, width: drawWidth, height: drawHeight)
        } else {
            let drawWidth = bounds.width
            let drawHeight = drawWidth / gameAspect
            drawRect = CGRect(x: 0, y: (bounds.height - drawHeight) / 2, width: drawWidth, height: drawHeight)
        }

        // Black background
        cgContext.setFillColor(NSColor.black.cgColor)
        cgContext.fill(bounds)

        cgContext.draw(currentFrame, in: drawRect)
    }
}

struct GameView: NSViewRepresentable {
    let gameNSView: GameNSView

    func makeNSView(context: Context) -> GameNSView {
        gameNSView
    }

    func updateNSView(_ nsView: GameNSView, context: Context) {}
}
```

- [ ] **Step 2: Verify it compiles**

Build in Xcode.

- [ ] **Step 3: Commit**

```bash
git add CrystalBoy/Rendering/
git commit -m "feat: add GameView with CGImage pixel-perfect rendering"
```

**Checkpoint:** Compiles. GameView is ready to receive pixel data.

---

## Task 5: Emulation Thread + First Boot

**Files:**
- Create: `CrystalBoy/Core/EmulationThread.swift`
- Modify: `CrystalBoy/App/CrystalBoyApp.swift`

- [ ] **Step 1: Implement EmulationThread**

`CrystalBoy/Core/EmulationThread.swift`:

```swift
import Foundation

final class EmulationThread {
    private var thread: Thread?
    private var isRunning = false
    private var isPaused = false
    private let emulator: EmulatorCore
    private var speedMultiplier: Float = 1.0

    init(emulator: EmulatorCore) {
        self.emulator = emulator
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isPaused = false
        thread = Thread { [weak self] in
            self?.runLoop()
        }
        thread?.name = "com.crystalboy.emulation"
        thread?.qualityOfService = .userInteractive
        thread?.start()
    }

    func stop() {
        isRunning = false
        thread = nil
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
    }

    func setSpeed(_ multiplier: Float) {
        speedMultiplier = multiplier
    }

    private func runLoop() {
        let targetFrameTime: TimeInterval = 1.0 / 59.7275 // GB frame rate

        while isRunning {
            if isPaused {
                Thread.sleep(forTimeInterval: 0.01)
                continue
            }

            let frameStart = CACurrentMediaTime()

            let framesToRun = max(1, Int(speedMultiplier))
            for _ in 0..<framesToRun {
                emulator.runFrame()
            }

            // Throttle to real-time (skip if fast forwarding)
            if speedMultiplier <= 1.0 {
                let elapsed = CACurrentMediaTime() - frameStart
                let sleepTime = targetFrameTime - elapsed
                if sleepTime > 0 {
                    Thread.sleep(forTimeInterval: sleepTime)
                }
            }
        }
    }
}
```

- [ ] **Step 2: Create minimal app to test first boot**

Replace `CrystalBoy/App/CrystalBoyApp.swift`:

```swift
import SwiftUI

@main
struct CrystalBoyApp: App {
    @State private var gameNSView = GameNSView(frame: .zero)
    @State private var emulator: SameBoyEmulator?
    @State private var emuThread: EmulationThread?

    var body: some Scene {
        Window("CrystalBoy", id: "main") {
            GameView(gameNSView: gameNSView)
                .frame(minWidth: 320, minHeight: 288)
                .background(Color.black)
                .onAppear { bootTestROM() }
        }
        .defaultSize(width: 480, height: 432)
    }

    private func bootTestROM() {
        let emu = SameBoyEmulator(isColorGB: true)

        emu.setVideoCallback { [gameNSView] pixels in
            gameNSView.updateFrame(pixels: pixels)
        }

        // Hardcode ROM path for testing
        let romPath = "/Users/efmenem/Library/Containers/org.agiapplications.Game-Emulator/Data/Documents/ROMs/Pokemon - Crystal Version (USA, Europe) (Rev 1).gbc"

        do {
            try emu.loadROM(url: URL(fileURLWithPath: romPath))
        } catch {
            print("Failed to load ROM: \(error)")
            return
        }

        let thread = EmulationThread(emulator: emu)
        thread.start()

        self.emulator = emu
        self.emuThread = thread
    }
}
```

- [ ] **Step 3: Run the app**

Run in Xcode (Cmd+R). Expected: Pokemon Crystal boots and displays on screen (no audio, no input yet).

- [ ] **Step 4: Commit**

```bash
git add CrystalBoy/Core/EmulationThread.swift CrystalBoy/App/
git commit -m "feat: emulation thread + first successful ROM boot"
```

**Checkpoint: MILESTONE 1** — Pokemon Crystal running on screen. This validates the entire core pipeline: SameBoy → Bridge → Swift → CGImage.

---

## Task 6: Keyboard Input

**Files:**
- Create: `CrystalBoy/Input/InputManager.swift`
- Create: `CrystalBoy/Input/KeyBindings.swift`

- [ ] **Step 1: Define KeyBindings**

`CrystalBoy/Input/KeyBindings.swift`:

```swift
import Carbon.HIToolbox

enum EmulatorAction: String, CaseIterable, Codable {
    // Game buttons
    case up, down, left, right, a, b, start, select
    // Emulator actions
    case saveState, loadState, prevSlot, nextSlot
    case rewind, fastForward, pause
    case toggleCheats
    case backToLibrary

    var gameButton: GameButton? {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .a: return .a
        case .b: return .b
        case .start: return .start
        case .select: return .select
        default: return nil
        }
    }

    var defaultKeyCode: UInt16 {
        switch self {
        case .up: return UInt16(kVK_UpArrow)
        case .down: return UInt16(kVK_DownArrow)
        case .left: return UInt16(kVK_LeftArrow)
        case .right: return UInt16(kVK_RightArrow)
        case .a: return UInt16(kVK_ANSI_Z)
        case .b: return UInt16(kVK_ANSI_X)
        case .start: return UInt16(kVK_Return)
        case .select: return UInt16(kVK_Delete)
        case .rewind: return UInt16(kVK_ANSI_R)
        case .fastForward: return UInt16(kVK_Tab)
        case .saveState: return UInt16(kVK_F5)
        case .loadState: return UInt16(kVK_F7)
        case .prevSlot: return UInt16(kVK_F2)
        case .nextSlot: return UInt16(kVK_F3)
        case .toggleCheats: return UInt16(kVK_F9)
        case .pause: return UInt16(kVK_Space)
        case .backToLibrary: return UInt16(kVK_Escape)
        }
    }
}

final class KeyBindings {
    private let defaultsKey = "CrystalBoy.KeyBindings"
    private var bindings: [UInt16: EmulatorAction]

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            var map: [UInt16: EmulatorAction] = [:]
            for (keyStr, actionStr) in saved {
                if let key = UInt16(keyStr), let action = EmulatorAction(rawValue: actionStr) {
                    map[key] = action
                }
            }
            bindings = map
        } else {
            bindings = Self.defaultBindings()
        }
    }

    func action(for keyCode: UInt16) -> EmulatorAction? {
        bindings[keyCode]
    }

    func setBinding(keyCode: UInt16, action: EmulatorAction) {
        // Remove old binding for this action
        bindings = bindings.filter { $0.value != action }
        bindings[keyCode] = action
        save()
    }

    func keyCode(for action: EmulatorAction) -> UInt16? {
        bindings.first(where: { $0.value == action })?.key
    }

    private func save() {
        var dict: [String: String] = [:]
        for (key, action) in bindings {
            dict[String(key)] = action.rawValue
        }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private static func defaultBindings() -> [UInt16: EmulatorAction] {
        var map: [UInt16: EmulatorAction] = [:]
        for action in EmulatorAction.allCases {
            map[action.defaultKeyCode] = action
        }
        return map
    }
}
```

- [ ] **Step 2: Implement InputManager**

`CrystalBoy/Input/InputManager.swift`:

```swift
import GameController
import Cocoa

final class InputManager {
    let keyBindings = KeyBindings()
    private let emulator: EmulatorCore
    private var emuThread: EmulationThread?

    // Callbacks for emulator-level actions
    var onSaveState: (() -> Void)?
    var onLoadState: (() -> Void)?
    var onPrevSlot: (() -> Void)?
    var onNextSlot: (() -> Void)?
    var onToggleCheats: (() -> Void)?
    var onPause: (() -> Void)?
    var onBackToLibrary: (() -> Void)?

    // Hold-state tracking for rewind/fast forward
    private var isRewinding = false
    private var isFastForwarding = false

    init(emulator: EmulatorCore, emuThread: EmulationThread?) {
        self.emulator = emulator
        self.emuThread = emuThread
        setupGamepad()
    }

    func setEmuThread(_ thread: EmulationThread) {
        self.emuThread = thread
    }

    func handleKeyDown(event: NSEvent) -> Bool {
        guard !event.isARepeat else { return true }
        guard let action = keyBindings.action(for: event.keyCode) else { return false }
        performAction(action, pressed: true)
        return true
    }

    func handleKeyUp(event: NSEvent) -> Bool {
        guard let action = keyBindings.action(for: event.keyCode) else { return false }
        performAction(action, pressed: false)
        return true
    }

    private func performAction(_ action: EmulatorAction, pressed: Bool) {
        // Game buttons
        if let button = action.gameButton {
            emulator.setInput(button: button, pressed: pressed)
            return
        }

        // Emulator actions (trigger on press only, except hold actions)
        switch action {
        case .rewind:
            isRewinding = pressed
            // Rewind is handled in the emu loop
        case .fastForward:
            isFastForwarding = pressed
            emuThread?.setSpeed(pressed ? 4.0 : 1.0)
        case .saveState:
            if pressed { onSaveState?() }
        case .loadState:
            if pressed { onLoadState?() }
        case .prevSlot:
            if pressed { onPrevSlot?() }
        case .nextSlot:
            if pressed { onNextSlot?() }
        case .toggleCheats:
            if pressed { onToggleCheats?() }
        case .pause:
            if pressed { onPause?() }
        case .backToLibrary:
            if pressed { onBackToLibrary?() }
        default:
            break
        }
    }

    var isRewindActive: Bool { isRewinding }

    // MARK: - Gamepad

    private func setupGamepad() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] notification in
            if let controller = notification.object as? GCController {
                self?.configureGamepad(controller)
            }
        }

        // Configure already-connected controllers
        for controller in GCController.controllers() {
            configureGamepad(controller)
        }
    }

    private func configureGamepad(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .up, pressed: pressed)
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .down, pressed: pressed)
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .left, pressed: pressed)
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .right, pressed: pressed)
        }
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .a, pressed: pressed)
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .b, pressed: pressed)
        }
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .start, pressed: pressed)
        }
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .select, pressed: pressed)
        }
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.performAction(.rewind, pressed: pressed)
        }
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.performAction(.fastForward, pressed: pressed)
        }
        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.onSaveState?() }
        }
        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.onLoadState?() }
        }
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.onToggleCheats?() }
        }
    }
}
```

- [ ] **Step 3: Verify it compiles and test keyboard input**

Build and run. Navigate the Pokemon Crystal menus with arrow keys, Z (A), X (B), Enter (Start).

- [ ] **Step 4: Commit**

```bash
git add CrystalBoy/Input/
git commit -m "feat: add keyboard and gamepad input with configurable bindings"
```

**Checkpoint: MILESTONE 2** — Pokemon Crystal playable with keyboard. Can navigate menus and play the game.

---

## Task 7: Audio

**Files:**
- Create: `CrystalBoy/Audio/AudioEngine.swift`

- [ ] **Step 1: Implement AudioEngine**

`CrystalBoy/Audio/AudioEngine.swift`:

```swift
import AVFoundation

final class AudioEngine {
    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let sampleRate: Double = 48000
    private let bufferSize = 4096
    private var ringBuffer: [Float] = []
    private var writeIndex = 0
    private var readIndex = 0
    private let lock = NSLock()
    private var muted = false

    init() {
        ringBuffer = [Float](repeating: 0, count: bufferSize * 2) // stereo
    }

    func start() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

        sourceNode = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, bufferList -> OSStatus in
            guard let self else { return noErr }

            let ablPointer = UnsafeMutableAudioBufferListPointer(bufferList)
            let frames = Int(frameCount)

            self.lock.lock()
            for frame in 0..<frames {
                let available = (self.writeIndex - self.readIndex + self.bufferSize * 2) % (self.bufferSize * 2)
                if available >= 2 {
                    let left = self.ringBuffer[self.readIndex]
                    let right = self.ringBuffer[(self.readIndex + 1) % (self.bufferSize * 2)]
                    self.readIndex = (self.readIndex + 2) % (self.bufferSize * 2)

                    for buffer in ablPointer {
                        let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                        if buffer == ablPointer[0] {
                            ptr[frame] = left
                        } else {
                            ptr[frame] = right
                        }
                    }
                } else {
                    // Underrun: output silence
                    for buffer in ablPointer {
                        let ptr = buffer.mData!.assumingMemoryBound(to: Float.self)
                        ptr[frame] = 0
                    }
                }
            }
            self.lock.unlock()

            return noErr
        }

        guard let sourceNode else { return }

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)

        do {
            try engine.start()
        } catch {
            print("AudioEngine failed to start: \(error)")
        }
    }

    func stop() {
        engine.stop()
    }

    func setMuted(_ muted: Bool) {
        self.muted = muted
    }

    /// Called from emulation thread with each audio sample pair
    func pushSample(left: Int16, right: Int16) {
        if muted { return }

        let leftFloat = Float(left) / Float(Int16.max)
        let rightFloat = Float(right) / Float(Int16.max)

        lock.lock()
        ringBuffer[writeIndex] = leftFloat
        ringBuffer[(writeIndex + 1) % (bufferSize * 2)] = rightFloat
        writeIndex = (writeIndex + 2) % (bufferSize * 2)
        lock.unlock()
    }

    var currentSampleRate: UInt32 { UInt32(sampleRate) }
}
```

- [ ] **Step 2: Wire audio into emulator**

In the app's boot code, add:

```swift
let audioEngine = AudioEngine()
audioEngine.start()

emu.setSampleRate(audioEngine.currentSampleRate)
emu.setAudioCallback { [audioEngine] left, right in
    audioEngine.pushSample(left: left, right: right)
}
```

- [ ] **Step 3: Verify audio works**

Run the app. Expected: Pokemon Crystal music and sound effects play.

- [ ] **Step 4: Commit**

```bash
git add CrystalBoy/Audio/
git commit -m "feat: add audio engine with ring buffer"
```

**Checkpoint: MILESTONE 3** — Full audio/video/input working. The game is fully playable.

---

## Task 8: Save System

**Files:**
- Create: `CrystalBoy/Save/SaveManager.swift`

- [ ] **Step 1: Implement SaveManager**

`CrystalBoy/Save/SaveManager.swift`:

```swift
import Foundation

final class SaveManager {
    private let emulator: EmulatorCore
    private var romURL: URL?
    private var currentSlot: Int = 0
    private var autoSaveTimer: Timer?
    private var sramDirty = false

    var onToast: ((String) -> Void)?

    init(emulator: EmulatorCore) {
        self.emulator = emulator
    }

    func setROM(url: URL) {
        romURL = url
        // Load battery save if exists
        let savURL = batteryURL
        if FileManager.default.fileExists(atPath: savURL.path) {
            _ = emulator.loadBattery(from: savURL)
        }
        startAutoSave()
    }

    // MARK: - Battery Saves (.sav)

    private var batteryURL: URL {
        guard let romURL else { fatalError("ROM not set") }
        return romURL.deletingPathExtension().appendingPathExtension("sav")
    }

    func saveBattery() {
        _ = emulator.saveBattery(to: batteryURL)
    }

    func markSRAMDirty() {
        sramDirty = true
    }

    private func startAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self, self.sramDirty else { return }
            self.saveBattery()
            self.sramDirty = false
        }
    }

    // MARK: - Save States

    private var saveStatesDir: URL {
        guard let romURL else { fatalError("ROM not set") }
        let md5 = romURL.lastPathComponent // simplified; use actual MD5 in production
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CrystalBoy/SaveStates/\(md5)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func saveState() {
        let url = saveStatesDir.appendingPathComponent("slot-\(currentSlot).state")
        if emulator.saveState(to: url) {
            onToast?("Saved Slot \(currentSlot)")
        }
        saveBattery() // Also flush battery save
    }

    func loadState() {
        let url = saveStatesDir.appendingPathComponent("slot-\(currentSlot).state")
        guard FileManager.default.fileExists(atPath: url.path) else {
            onToast?("Slot \(currentSlot) is empty")
            return
        }
        if emulator.loadState(from: url) {
            onToast?("Loaded Slot \(currentSlot)")
        }
    }

    func nextSlot() {
        currentSlot = (currentSlot + 1) % 10
        onToast?("Slot \(currentSlot)")
    }

    func prevSlot() {
        currentSlot = (currentSlot - 1 + 10) % 10
        onToast?("Slot \(currentSlot)")
    }

    func cleanup() {
        autoSaveTimer?.invalidate()
        saveBattery()
    }
}
```

- [ ] **Step 2: Wire save manager to input actions and test**

Connect `InputManager.onSaveState`, `onLoadState`, `onPrevSlot`, `onNextSlot` to `SaveManager`. Test: save with F5, load with F7, switch slots with F2/F3.

- [ ] **Step 3: Commit**

```bash
git add CrystalBoy/Save/
git commit -m "feat: add save manager with battery auto-save and state slots"
```

**Checkpoint:** Save in Pokemon, close app, reopen → progress persisted. Save states work with F5/F7.

---

## Task 9: Rewind + Fast Forward + Cheats

**Files:**
- Create: `CrystalBoy/Features/CheatManager.swift`
- Modify: `CrystalBoy/Core/EmulationThread.swift`

- [ ] **Step 1: Add rewind support to EmulationThread**

Modify `EmulationThread.runLoop()` to check `inputManager.isRewindActive`:

```swift
// Inside runLoop(), replace the frame execution block:
if inputManager?.isRewindActive == true {
    _ = emulator.rewindPop()
} else {
    let framesToRun = max(1, Int(speedMultiplier))
    for _ in 0..<framesToRun {
        emulator.runFrame()
    }
}
```

Add `inputManager` property to `EmulationThread` and set rewind length on ROM load:

```swift
emulator.setRewindLength(seconds: 30)
```

- [ ] **Step 2: Wire fast forward audio mute**

When fast forwarding, mute audio:

```swift
// In InputManager.performAction for .fastForward:
audioEngine?.setMuted(pressed)
```

- [ ] **Step 3: Implement CheatManager**

`CrystalBoy/Features/CheatManager.swift`:

```swift
import Foundation

struct Cheat: Codable, Identifiable {
    let id: UUID
    let code: String
    let description: String
    var enabled: Bool
}

final class CheatManager {
    private let emulator: EmulatorCore
    private(set) var cheats: [Cheat] = []
    private var cheatsEnabled = true

    var onToast: ((String) -> Void)?

    init(emulator: EmulatorCore) {
        self.emulator = emulator
    }

    func addCheat(code: String, description: String) {
        let cheat = Cheat(id: UUID(), code: code, description: description, enabled: true)
        cheats.append(cheat)
        reapplyCheats()
    }

    func toggleCheats() {
        cheatsEnabled.toggle()
        reapplyCheats()
        onToast?(cheatsEnabled ? "Cheats ON" : "Cheats OFF")
    }

    private func reapplyCheats() {
        emulator.removeAllCheats()
        if cheatsEnabled {
            for cheat in cheats where cheat.enabled {
                emulator.addCheat(code: cheat.code, description: cheat.description)
            }
        }
    }
}
```

- [ ] **Step 4: Test all features**

- Hold R: game rewinds
- Hold Tab: game speeds up, audio mutes
- Release Tab: normal speed, audio returns

- [ ] **Step 5: Commit**

```bash
git add CrystalBoy/Features/ CrystalBoy/Core/EmulationThread.swift
git commit -m "feat: add rewind, fast forward, and cheat support"
```

**Checkpoint:** Rewind, fast forward, and cheats all functional.

---

## Task 10: Library UI

**Files:**
- Create: `CrystalBoy/Library/LibraryManager.swift`
- Create: `CrystalBoy/Library/LibraryView.swift`
- Create: `CrystalBoy/App/AppState.swift`
- Modify: `CrystalBoy/App/CrystalBoyApp.swift`

- [ ] **Step 1: Implement LibraryManager**

`CrystalBoy/Library/LibraryManager.swift`:

```swift
import Foundation

struct ROMItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isColor: Bool // .gbc vs .gb

    init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.isColor = url.pathExtension.lowercased() == "gbc"
    }
}

final class LibraryManager: ObservableObject {
    @Published var roms: [ROMItem] = []
    @Published var folderURL: URL?

    private let defaultsKey = "CrystalBoy.ROMFolder"

    init() {
        if let bookmark = UserDefaults.standard.data(forKey: defaultsKey) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale) {
                _ = url.startAccessingSecurityScopedResource()
                folderURL = url
                scan()
            }
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select your ROMs folder"

        if panel.runModal() == .OK, let url = panel.url {
            let bookmark = try? url.bookmarkData(options: .withSecurityScope)
            UserDefaults.standard.set(bookmark, forKey: defaultsKey)
            _ = url.startAccessingSecurityScopedResource()
            folderURL = url
            scan()
        }
    }

    func scan() {
        guard let folderURL else { return }
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: folderURL, includingPropertiesForKeys: nil
        ) else { return }

        roms = contents
            .filter { ["gb", "gbc"].contains($0.pathExtension.lowercased()) }
            .map { ROMItem(url: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
```

- [ ] **Step 2: Implement LibraryView**

`CrystalBoy/Library/LibraryView.swift`:

```swift
import SwiftUI

struct LibraryView: View {
    @ObservedObject var library: LibraryManager
    var onSelectROM: (ROMItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("CrystalBoy")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button("Select Folder") {
                    library.selectFolder()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(white: 0.1))

            // ROM list
            if library.roms.isEmpty {
                Spacer()
                if library.folderURL == nil {
                    Text("Select a folder with your ROMs")
                        .foregroundStyle(.gray)
                } else {
                    Text("No .gb or .gbc files found")
                        .foregroundStyle(.gray)
                }
                Spacer()
            } else {
                List(library.roms) { rom in
                    HStack {
                        Text(rom.isColor ? "GBC" : "GB")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rom.isColor ? Color.purple : Color.gray)
                            .cornerRadius(4)
                        Text(rom.name)
                            .foregroundStyle(.white)
                    }
                    .listRowBackground(Color(white: 0.12))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onSelectROM(rom)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(white: 0.08))
    }
}
```

- [ ] **Step 3: Implement AppState**

`CrystalBoy/App/AppState.swift`:

```swift
import Foundation

enum AppScreen {
    case library
    case game(URL)
}

final class AppState: ObservableObject {
    @Published var currentScreen: AppScreen = .library
    @Published var toastMessage: String?

    func showToast(_ message: String) {
        toastMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if self?.toastMessage == message {
                self?.toastMessage = nil
            }
        }
    }
}
```

- [ ] **Step 4: Rewrite CrystalBoyApp with navigation**

Replace `CrystalBoyApp.swift` with full navigation between library and game screen, wiring all managers together. Remove the hardcoded ROM path.

- [ ] **Step 5: Test full flow**

Launch app → see library → select folder → double-click ROM → game plays → Esc → back to library.

- [ ] **Step 6: Commit**

```bash
git add CrystalBoy/Library/ CrystalBoy/App/
git commit -m "feat: add ROM library with folder selection and navigation"
```

**Checkpoint:** Full app flow working: library → game → library.

---

## Task 11: Game Screen + Toast + Pause Logic

**Files:**
- Create: `CrystalBoy/Game/GameScreen.swift`

- [ ] **Step 1: Implement GameScreen**

`CrystalBoy/Game/GameScreen.swift`:

```swift
import SwiftUI

struct GameScreen: View {
    let gameNSView: GameNSView
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            GameView(gameNSView: gameNSView)
                .background(Color.black)

            // Toast overlay
            if let toast = appState.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(6)
                        .padding(.bottom, 20)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.3), value: appState.toastMessage)
            }
        }
    }
}
```

- [ ] **Step 2: Add auto-pause on focus loss**

In the main app, observe `NSApplication` notifications:

```swift
NotificationCenter.default.addObserver(forName: NSApplication.didResignActiveNotification, ...) {
    emuThread.pause()  // auto-pause
}
NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, ...) {
    if !manuallyPaused { emuThread.resume() }  // auto-resume only
}
```

- [ ] **Step 3: Add window configuration**

Set aspect ratio constraint and minimum size:

```swift
Window("CrystalBoy", id: "main") { ... }
    .defaultSize(width: 480, height: 432)
    .windowResizability(.contentSize)
```

Apply aspect ratio on the GameView: `.aspectRatio(CGFloat(160)/CGFloat(144), contentMode: .fit)`

- [ ] **Step 4: Test toast, pause, window resize**

- Save state → toast appears "Saved Slot 0" → fades after 1s
- Switch to another app → game pauses → switch back → resumes
- Resize window → aspect ratio maintained
- Space → pauses → Space → resumes → switch app → switch back → stays paused

- [ ] **Step 5: Commit**

```bash
git add CrystalBoy/Game/
git commit -m "feat: add game screen with toast overlay and auto-pause"
```

**Checkpoint:** Game screen polished with toast, pause logic, and proper window behavior.

---

## Task 12: Controls Settings Modal

**Files:**
- Create: `CrystalBoy/Settings/ControlsSettingsView.swift`

- [ ] **Step 1: Implement ControlsSettingsView**

`CrystalBoy/Settings/ControlsSettingsView.swift`:

```swift
import SwiftUI
import Carbon.HIToolbox

struct ControlsSettingsView: View {
    let keyBindings: KeyBindings
    @State private var listeningFor: EmulatorAction?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Controls")
                .font(.headline)
                .padding()

            List {
                ForEach(EmulatorAction.allCases, id: \.self) { action in
                    HStack {
                        Text(action.displayName)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if listeningFor == action {
                            Text("Press a key...")
                                .foregroundStyle(.yellow)
                                .italic()
                        } else {
                            Text(keyBindings.keyCode(for: action).map { keyCodeName($0) } ?? "None")
                                .foregroundStyle(.gray)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        listeningFor = action
                    }
                }
            }
            .listStyle(.plain)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .background(Color(white: 0.1))
        .onKeyDown { keyCode in
            if let action = listeningFor {
                keyBindings.setBinding(keyCode: keyCode, action: action)
                listeningFor = nil
            }
        }
    }

    private func keyCodeName(_ keyCode: UInt16) -> String {
        // Map common key codes to names
        let names: [UInt16: String] = [
            UInt16(kVK_UpArrow): "Up",
            UInt16(kVK_DownArrow): "Down",
            UInt16(kVK_LeftArrow): "Left",
            UInt16(kVK_RightArrow): "Right",
            UInt16(kVK_Return): "Enter",
            UInt16(kVK_Delete): "Backspace",
            UInt16(kVK_Space): "Space",
            UInt16(kVK_Tab): "Tab",
            UInt16(kVK_Escape): "Esc",
            UInt16(kVK_ANSI_Z): "Z",
            UInt16(kVK_ANSI_X): "X",
            UInt16(kVK_ANSI_R): "R",
            UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
            UInt16(kVK_F5): "F5", UInt16(kVK_F7): "F7",
            UInt16(kVK_F9): "F9",
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }
}

extension EmulatorAction {
    var displayName: String {
        switch self {
        case .up: return "D-Pad Up"
        case .down: return "D-Pad Down"
        case .left: return "D-Pad Left"
        case .right: return "D-Pad Right"
        case .a: return "Button A"
        case .b: return "Button B"
        case .start: return "Start"
        case .select: return "Select"
        case .saveState: return "Save State"
        case .loadState: return "Load State"
        case .prevSlot: return "Previous Slot"
        case .nextSlot: return "Next Slot"
        case .rewind: return "Rewind (hold)"
        case .fastForward: return "Fast Forward (hold)"
        case .pause: return "Pause"
        case .toggleCheats: return "Toggle Cheats"
        case .backToLibrary: return "Back to Library"
        }
    }
}
```

- [ ] **Step 2: Add menu bar item to open settings**

In the app, add a macOS menu command:

```swift
.commands {
    CommandGroup(after: .appSettings) {
        Button("Controls...") {
            showControlsSettings = true
        }
        .keyboardShortcut(",", modifiers: .command)
    }
}
```

- [ ] **Step 3: Test rebinding**

Open settings → click "Button A" → press M → now M is the A button in-game. Close settings, verify it works. Relaunch app, verify binding persisted.

- [ ] **Step 4: Commit**

```bash
git add CrystalBoy/Settings/
git commit -m "feat: add controls settings modal with key rebinding"
```

**Checkpoint:** Full app complete. All features from spec implemented.

---

## Summary of Milestones

| Milestone | Tasks | What works |
|---|---|---|
| **M1: First boot** | 1-5 | ROM renders on screen |
| **M2: Playable** | 6 | Keyboard input works |
| **M3: Full AV** | 7 | Audio + video + input |
| **M4: Persistent** | 8 | Battery saves + save states |
| **M5: Features** | 9 | Rewind + fast forward + cheats |
| **M6: Complete** | 10-12 | Library + settings + polish |
