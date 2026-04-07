# CrystalBoy

Native macOS multi-console retro emulator built with SwiftUI.

## Consoles

| Console | Core | Extensions |
|---|---|---|
| Game Boy | SameBoy | `.gb` |
| Game Boy Color | SameBoy | `.gbc` |
| Game Boy Advance | mGBA | `.gba` |
| NES | Nestopia (libretro) | `.nes` |
| SNES | Snes9x (libretro) | `.sfc` `.smc` |
| Sega Genesis | Genesis Plus GX (libretro) | `.md` `.gen` |

## Features

- Pixel-perfect rendering with nearest-neighbor scaling
- Save states (10 slots per game)
- Battery saves (auto-save every 5 seconds)
- Rewind (GB/GBC — hold R)
- Cheats (Game Genie / GameShark) with per-game persistence
- Speed control (25% - 400%)
- Volume control with mute
- Keyboard + gamepad support (per-console mapping)
- ROM library with console filter pills
- Fast forward (hold Tab)

## Controls

### Keyboard (default)

| Action | Key |
|---|---|
| D-Pad | Arrow keys |
| A | Z |
| B | X |
| Start | Enter |
| Select | Backspace |
| L / R (GBA/SNES) | A / S |
| X / Y (SNES) | D / C |
| Save State | F5 |
| Load State | F7 |
| Rewind (hold) | R |
| Fast Forward (hold) | Tab |
| Volume Up / Down | ] / [ |
| Mute | M |
| Pause | Space |
| Cheats | Cmd+K |
| Back to Library | Esc |
| Help Overlay | Hold H |

### Gamepad

| Console | A | B | X | Y | L1 | R1 | L2 | R2 |
|---|---|---|---|---|---|---|---|---|
| GB/GBC/NES | A | B | — | Cheats | Rewind | FF | Save | Load |
| GBA | A | B | — | Cheats | L | R | Save | Load |
| SNES | A | B | X | Y | L | R | Save | Load |
| Genesis | C | B | X | A | Y | Z | Save | Load |

## Build

Requires:
- macOS 14.0+
- Xcode 16+
- cmake (`brew install cmake`)
- XcodeGen (`brew install xcodegen`)

```bash
# Clone
git clone https://github.com/franMenem/emulator.git
cd emulator

# Generate Xcode project
xcodegen generate

# Build
xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build

# Or open in Xcode
open CrystalBoy.xcodeproj
```

The emulator cores (`.a` files) are pre-compiled and included in the repo. To rebuild them from source:

```bash
./SameBoyCore/build.sh    # Game Boy / GBC
./MGBACore/build.sh        # GBA
./NestopiaCore/build.sh    # NES
./Snes9xCore/build.sh      # SNES
./GenesisCore/build.sh     # Genesis
```

## Usage

1. Open CrystalBoy
2. Select your ROMs folder
3. Double-click a game to play
4. Use filter pills to browse by console

ROMs are detected by file extension — put all your games in one folder.

## Architecture

```
SwiftUI App
  ├── LibraryManager (ROM scanning, filtering)
  ├── GameSession (orchestrator)
  │     ├── EmulatorCore protocol
  │     │     ├── SameBoyEmulator (GB/GBC)
  │     │     ├── MGBAEmulator (GBA)
  │     │     ├── NestopiaEmulator (NES)
  │     │     ├── Snes9xEmulator (SNES)
  │     │     └── GenesisEmulator (Genesis)
  │     ├── EmulationThread
  │     ├── AudioEngine
  │     ├── InputManager
  │     ├── SaveManager
  │     └── CheatManager
  └── UI (SwiftUI views)
```

Each emulator core is compiled as a static C library with a thin C bridge that Swift calls via a bridging header.

## License

For personal use only. Emulator cores have their own licenses:
- SameBoy: MIT
- mGBA: MPL 2.0
- Nestopia: GPL-2.0
- Snes9x: Non-commercial
- Genesis Plus GX: Non-commercial
