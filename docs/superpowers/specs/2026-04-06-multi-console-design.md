# CrystalBoy Multi-Console Support + Volume Control

## Overview

Extend CrystalBoy from a GB/GBC-only emulator to a multi-console retro emulator supporting GBA, NES, SNES, and Sega Genesis. Add volume control and library filtering by console.

**Approach:** Infrastructure first, then one core at a time (GBA → NES → SNES → Genesis).

## Console System

New `ConsoleType` enum identifies each system:

```swift
enum ConsoleType: String, CaseIterable {
    case gb, gbc, gba, nes, snes, genesis

    var displayName: String { ... }  // "Game Boy", "GBA", etc.
    var extensions: [String] { ... } // ["gb"], ["gbc"], ["gba"], ["nes"], ["sfc", "smc"], ["md", "gen"]
    var badgeColor: Color { ... }    // Distinct color per console
}
```

- `ROMItem` gains `consoleType: ConsoleType` replacing `isColor: Bool`. Determined by file extension.
- `GameSession.startGame()` uses `consoleType` to instantiate the correct core via a simple switch.
- `LibraryManager.scan()` expands to scan all supported extensions.

## Input System — GameButton Expansion

The current `GameButton` enum only has 8 Game Boy buttons. It must be expanded to support all consoles:

```swift
enum GameButton: Int {
    // Shared (all consoles)
    case right = 0, left, up, down, a, b, select, start
    // GBA / SNES
    case l, r
    // SNES
    case x, y
    // Genesis (6-button)
    case genesisC, genesisX, genesisY, genesisZ
}
```

Each core only uses the buttons it needs — unused buttons are simply ignored. `InputManager` and `KeyBindings` are updated to show only the relevant buttons for the active console's configuration screen. Default keyboard/gamepad mappings are defined per `ConsoleType`.

## Volume Control

Handled at the `AudioEngine` level (not per-core) via `AVAudioEngine.mainMixerNode.outputVolume`.

```swift
// AudioEngine.swift
func setVolume(_ volume: Float) {
    engine.mainMixerNode.outputVolume = volume
}
```

**UI:** Slider in the game screen toolbar (next to speed slider) + speaker icon for mute toggle.

**Keyboard shortcuts:**
- `[` / `]` — volume down/up (10% steps)
- `M` — toggle mute

**Persistence:** Volume level saved in `UserDefaults`. Mute state is temporary (resets on new game).

## Library Filters

Horizontal row of pill/chip buttons above the ROM list:

```
[ Todas ] [ GB ] [ GBC ] [ GBA ] [ NES ] [ SNES ] [ Genesis ]
```

- Active filter is highlighted (white bg, black text). Inactive are dimmed (dark bg, gray text).
- Only filters with at least 1 ROM are shown. "Todas" always visible.
- Filter state: `@Published var selectedFilter: ConsoleType?` in `LibraryManager` — `nil` = all.
- Empty state adapts: "No ROMs found" vs "No GBA ROMs found".

## Emulation Cores

Each core follows the same pattern as SameBoy: compile as static lib → C bridge → Swift wrapper conforming to `EmulatorCore`.

### GBA — mGBA
- **Repo:** https://github.com/mgba-emu/mgba (MIT)
- **Build:** CMake → `libmgba.a` (arm64-macos)
- **Resolution:** 240x160
- **Extensions:** `.gba`
- **Cheats:** GameShark Advance, CodeBreaker

### NES — Nestopia UE
- **Repo:** https://github.com/0ldsk00l/nestopia (GPL-2.0)
- **Build:** Makefile → `libnestopia.a`
- **Resolution:** 256x240
- **Extensions:** `.nes`
- **Cheats:** Game Genie (NES)
- **Note:** C++ core, bridge needs `extern "C"` wrapper

### SNES — Snes9x
- **Repo:** https://github.com/snes9xgit/snes9x (non-commercial)
- **Build:** CMake → `libsnes9x.a`
- **Resolution:** 256x224
- **Extensions:** `.sfc`, `.smc`
- **Cheats:** Game Genie (SNES), Pro Action Replay
- **Note:** Non-commercial license — ok for personal use, not App Store

### Genesis — Genesis Plus GX
- **Repo:** https://github.com/ekeeke/Genesis-Plus-GX (permissive)
- **Build:** Makefile → `libgenesis.a`
- **Resolution:** 320x224
- **Extensions:** `.md`, `.gen` (`.bin` excluded — too ambiguous across systems)
- **Cheats:** Game Genie (Genesis), Pro Action Replay

### File Structure Per Core

```
<CoreName>Core/
  lib<corename>.a
  include/
  build.sh
Bridge/
  <CoreName>Bridge.h
  <CoreName>Bridge.c    (.cpp for Nestopia)
CrystalBoy/Core/
  <CoreName>Emulator.swift
```

## Dynamic Aspect Ratio and Window Sizing

`GameView` reads `EmulatorCore.screenWidth/screenHeight` to set the correct aspect ratio per console. The window adapts when switching between games of different consoles.

Default window size uses 3x multiplier based on core resolution:
- GB/GBC: 480x432 (160x144 × 3) — current behavior
- GBA: 720x480 (240x160 × 3)
- NES: 768x720 (256x240 × 3)
- SNES: 768x672 (256x224 × 3)
- Genesis: 960x672 (320x224 × 3)

## Core Availability

`LibraryManager` only scans extensions for cores that are actually compiled and available. A simple check: if `lib<corename>.a` is bundled in the app, that console's extensions are included in the scan. ROMs for unavailable cores don't appear in the library — no disabled/grayed-out states needed.

## Implementation Order

### Phase 0 — Shared Infrastructure
1. `ConsoleType` enum + `ROMItem` refactor
2. `GameButton` expansion + `InputManager`/`KeyBindings` per-console mappings
3. Volume control in `AudioEngine` + UI (slider, keys, mute)
4. Console filter buttons in `LibraryView`
5. `GameSession` refactored to instantiate cores by type
6. `GameView` dynamic aspect ratio
7. `LibraryManager.scan()` updated for all extensions
8. App icon

### Phase 1 — GBA (mGBA)
Compile mGBA → C bridge → `MGBAEmulator.swift` → test

### Phase 2 — NES (Nestopia UE)
Compile Nestopia → C/C++ bridge → `NestopiaEmulator.swift` → test

### Phase 3 — SNES (Snes9x)
Compile Snes9x → C bridge → `Snes9xEmulator.swift` → test

### Phase 4 — Genesis (Genesis Plus GX)
Compile Genesis Plus GX → C bridge → `GenesisEmulator.swift` → test

## App Icon

Add a custom app icon to `Assets.xcassets`. Design: a crystal/gem shape with a retro pixel aesthetic, representing the multi-console nature of the app. Single 1024x1024 PNG source — Xcode generates all required sizes automatically.

## What Doesn't Change

- Save states, battery saves, rewind, cheats — work through `EmulatorCore` protocol
- `InputManager` — updated for expanded `GameButton` but same architecture
- `SaveManager`, `CheatManager` — untouched, depend on protocol
- App name remains "CrystalBoy"

## Risks

| Risk | Mitigation |
|---|---|
| Nestopia is C++, bridge more complex | Standard `extern "C"` wrapper pattern |
| Snes9x non-commercial license | Ok for personal use, don't publish to App Store |
| A core doesn't compile cleanly on arm64-macos | Each core has alternatives (e.g., FCEUX instead of Nestopia) |
| `.md` extension conflicts with Markdown files | Only scanned within ROM folder, not a problem |
| Nestopia UE repo has low maintenance activity | Fallback to FCEUX if compilation issues arise |
| Different audio sample rates per core | `setSampleRate` already in protocol, each bridge must implement it |
