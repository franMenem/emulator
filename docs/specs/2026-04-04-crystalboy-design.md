# CrystalBoy - Game Boy Color Emulator for macOS

## Overview

Native macOS app that wraps the SameBoy emulation core (compiled as a static C library) in a minimal SwiftUI interface. Focused on GB/GBC emulation with architecture prepared for adding more consoles in the future.

**Target:** macOS, Apple Silicon (arm64), local build only.

## Architecture

```
┌─────────────────────────────────┐
│         SwiftUI App             │
│  ┌───────────┐  ┌────────────┐  │
│  │  Library   │  │  Game View │  │
│  │  Manager   │  │  (CGImage) │  │
│  └─────┬─────┘  └─────┬──────┘  │
│        │               │         │
│  ┌─────┴───────────────┴──────┐  │
│  │     EmulatorCore Protocol  │  │
│  └─────────────┬──────────────┘  │
│                │                 │
│  ┌─────────────┴──────────────┐  │
│  │   SameBoy C Bridge         │  │
│  │   (libsameboy.a)           │  │
│  └────────────────────────────┘  │
└─────────────────────────────────┘
```

## Emulation Core

**SameBoy** (MIT license, open source) compiled as `libsameboy.a` for arm64-macos. Only the core is compiled, not the SDL/Cocoa frontend.

SameBoy natively supports all required features:
- `GB_save_state()` / `GB_load_state()` for save states
- `GB_rewind_push()` / `GB_rewind_pop()` for rewind
- Game Shark and Game Genie cheat codes
- Open-source boot ROMs included

### C Bridge

A thin C wrapper (`SameBoyBridge.c`) that:
- Manages the `GB_gameboy_t` instance
- Routes SameBoy callbacks (video, audio, input) to Swift via a stored context pointer
- Exposed to Swift via bridging header

### EmulatorCore Protocol

Minimal Swift protocol based on what SameBoy needs today:

```swift
protocol EmulatorCore {
    func loadROM(url: URL) throws
    func unloadROM()
    func runFrame() -> UnsafeBufferPointer<UInt32>
    func saveState() -> Data
    func loadState(_ data: Data) throws
    func setInput(button: GameButton, pressed: Bool)
    func setSpeed(multiplier: Float)
    func rewind(seconds: Float)
    func enableRewind(bufferSeconds: Int)
    func applyCheat(code: String, type: CheatType)
    func removeCheat()
    func audioBuffer() -> UnsafeBufferPointer<Int16>
}
```

Refactor when a second core is added, not before.

## Data Flow

```
Emulation Thread                    Main Thread (UI)
┌──────────────┐                   ┌──────────────┐
│  SameBoy     │                   │  SwiftUI     │
│  GB_run()    │──frame buffer──→  │  GameView    │
│              │                   │  (CGImage)   │
│  audio cb  ──│──audio samples──→ │  AVAudio     │
│              │                   │  SourceNode  │
│              │←──input state───  │  InputManager│
└──────────────┘                   └──────────────┘
```

- Emulation runs on a dedicated thread, ~60 FPS
- Frame buffer: double-buffered (one writes, one renders)
- Audio: SameBoy callback pushes samples to `AVAudioSourceNode`
- Input: `InputManager` maintains an atomic struct with button state, emu thread reads it each frame (no locks)
- Fast forward: run more frames per loop iteration, mute audio
- Rewind: replace `GB_run()` with `GB_rewind_pop()`
- Rewind buffer: 30 seconds by default (~2MB for GB/GBC). Not configurable in v1.

## Rendering

`CGImage` + `CALayer` via `NSViewRepresentable`. Not Metal.

- Nearest-neighbor scaling for pixel-perfect rendering
- Fixed aspect ratio 160x144 (GB/GBC native resolution)
- Black background around the game screen
- At this resolution and framerate, CGImage has zero performance overhead

If CRT/shader filters are desired later, migrate to Metal at that point.

## Audio

`AVAudioEngine` with `AVAudioSourceNode`:
- SameBoy generates audio at ~48000Hz
- Samples pushed from emulation thread via callback
- Fast forward: audio is muted (no pitch-shift complexity)

## Input

### InputManager
- Keyboard input via `NSEvent`
- Gamepad support via `GCController` (native Apple framework, auto-detects PS/Xbox/MFi controllers)
- All mappings configurable and persisted in `UserDefaults`

### Default Mapping (gamepad)

| Button | Action |
|---|---|
| D-pad / Left stick | Direction |
| X / A | A |
| O / B | B |
| Options | Start |
| Share | Select |
| L1 (hold) | Rewind |
| R1 (hold) | Fast forward |
| L2 | Save state |
| R2 | Load state |
| Triangle / Y | Toggle cheats |

### Default Mapping (keyboard)

| Key | Action |
|---|---|
| Arrow keys | Direction |
| Z | A |
| X | B |
| Enter | Start |
| Backspace | Select |
| R (hold) | Rewind |
| Tab (hold) | Fast forward |
| F5 | Save state |
| F7 | Load state |
| F2 / F3 | Previous / Next save slot |
| F9 | Toggle cheats |
| Esc | Back to library (pause) |
| Space | Pause / Resume |

## UI Design

Minimal. Two screens only.

### Library Screen
- Dark background, flat list of detected ROMs
- Each ROM shows: game name + GB/GBC badge
- Double-click or Enter opens the game
- Top bar: button to configure ROM folder
- No sidebar, no categories, no filters

### Game Screen
- Game fills the window, centered, black borders
- Pixel-perfect scaling, no blur
- No visible controls — all via keyboard/gamepad
- `Esc` returns to library (auto-pause)
- `Space` pauses/resumes emulation
- Auto-pause when: window loses focus, app goes to background, window is minimized
- Auto-resume when: window regains focus (only if it was auto-paused, not manually paused)
- macOS menu bar has: save/load state, configure controls, speed options

### Window
- Default size: 480x432 (160x144 scaled 3x)
- Resizable, maintains 10:9 aspect ratio
- Minimum size: 320x288 (2x scale)
- Fullscreen supported via standard macOS green button

### Controls Settings (modal)
- List of actions on the left, assigned button on the right
- Click an action → "Press a key or button" → captures input
- Nothing else

### Visual Style
Dark theme. Black/dark gray/white only. No decorative icons, no animations.

## Project Structure

```
CrystalBoy/
├── CrystalBoy.xcodeproj
├── SameBoyCore/
│   ├── libsameboy.a
│   ├── sameboy.h
│   └── BootROMs/
├── Bridge/
│   ├── SameBoyBridge.h
│   └── SameBoyBridge.c
├── Core/
│   ├── EmulatorCore.swift
│   └── SameBoyEmulator.swift
├── Audio/
│   └── AudioEngine.swift
├── Input/
│   ├── InputManager.swift
│   └── KeyBindings.swift
├── Rendering/
│   └── GameView.swift
├── Library/
│   ├── LibraryView.swift
│   └── LibraryManager.swift
├── Game/
│   └── GameScreen.swift
├── Settings/
│   └── ControlsSettingsView.swift
├── App/
│   ├── CrystalBoyApp.swift
│   └── AppState.swift
└── Resources/
    └── Assets.xcassets
```

## Save System

### Battery Saves (.sav)
SameBoy uses standard 32KB `.sav` files — fully compatible with the user's existing Pokemon Crystal saves. No conversion needed.

- `.sav` files live next to the ROM file (e.g., `Pokemon Crystal.gbc` → `Pokemon Crystal.sav`)
- Auto-save to disk every 5 seconds when SRAM is dirty (prevents data loss on crash)
- Also saves on: pause, Esc to library, quit app, load state

### Save States
- 10 numbered slots per game (0-9)
- Stored in `~/Library/Application Support/CrystalBoy/SaveStates/<rom-md5>/slot-N.state`
- Keyboard: Shift+1-0 to save, 1-0 to load
- Gamepad: L2 saves to current slot, R2 loads from current slot, bump slot with D-pad up/down while holding L2
- Overwrite without confirmation (fast workflow, slots are cheap)
- On save/load/slot change: brief toast overlay (e.g., "Saved Slot 3", "Loaded Slot 3") that fades after 1 second. Small white text, bottom-center of game screen.

## ROM Library

### Default Folder
- First launch: prompts user to select a folder
- Persisted in `UserDefaults`
- Scans for `.gb` and `.gbc` files (non-recursive, top level only)
- User can change folder anytime from Library screen

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| SameBoy hard to compile as standalone lib | Blocks everything | Fallback to Gambatte (simpler build) |
| C↔Swift threading bugs | Crashes | Simple design: one emu thread, double buffer, atomic input |
| Audio sync issues on fast forward | Glitchy audio | Mute audio during fast forward |

## SOLID Principles

- **S**: Each file has one responsibility
- **O**: EmulatorCore protocol allows new cores without changing existing code
- **L**: Any EmulatorCore implementation works interchangeably
- **I**: Protocol is minimal, only what the app needs
- **D**: App depends on protocol, not on SameBoy directly
