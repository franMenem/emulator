# Multi-Console Phase 0: Shared Infrastructure

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor CrystalBoy's infrastructure to support multiple console types, add volume control, library filtering, expanded input, dynamic aspect ratio, and an app icon — all before adding any new emulator cores.

**Architecture:** Add `ConsoleType` enum that drives everything: ROM scanning, core instantiation, input mapping, aspect ratio, badge colors. Volume control at AudioEngine level via `mainMixerNode.outputVolume`. Library filters as horizontal pills. FrameRenderer made dynamic for variable resolutions.

**Tech Stack:** Swift 6.2, SwiftUI, AVAudioEngine, Carbon.HIToolbox, CGImage.

**Spec:** `docs/superpowers/specs/2026-04-06-multi-console-design.md`

---

## File Map

### New Files to Create

| File | Responsibility |
|---|---|
| `CrystalBoy/Core/ConsoleType.swift` | Console type enum with extensions, display names, badge colors, default button mappings |

### Files to Modify

| File | Changes |
|---|---|
| `CrystalBoy/Core/EmulatorCore.swift` | Expand `GameButton` enum with L, R, X, Y, Genesis buttons |
| `CrystalBoy/Input/KeyBindings.swift` | Add volume actions, per-console button actions to `EmulatorAction`; add `actions(for consoleType:)` filtering |
| `CrystalBoy/Input/InputManager.swift` | Add volume up/down/mute handling, wire to AudioEngine |
| `CrystalBoy/Audio/AudioEngine.swift` | Add `setVolume()`, `volume` property, `toggleMute()`, UserDefaults persistence |
| `CrystalBoy/Library/LibraryManager.swift` | Replace `isColor` with `consoleType` in ROMItem, scan all extensions, add `selectedFilter` |
| `CrystalBoy/Library/LibraryView.swift` | Add filter pills row, update badge to use ConsoleType |
| `CrystalBoy/Rendering/GameView.swift` | Make FrameRenderer dynamic (width/height from core), dynamic aspect ratio |
| `CrystalBoy/Game/GameToolbar.swift` | Add volume slider + mute button to toolbar, add `volume`/`isMuted` to ToolbarState |
| `CrystalBoy/App/GameSession.swift` | Accept ConsoleType, instantiate correct core, pass volume state |
| `CrystalBoy/App/AppState.swift` | No changes needed |
| `CrystalBoy/Settings/ControlsSettingsView.swift` | Filter displayed actions by active console type |
| `Resources/Assets.xcassets/AppIcon.appiconset/` | Add 1024x1024 app icon |

---

## Task 1: Create ConsoleType Enum

**Why first:** Everything else depends on this enum — ROMItem, LibraryManager, GameSession, InputManager all reference it.

**Files:**
- Create: `CrystalBoy/Core/ConsoleType.swift`

- [ ] **Step 1: Create ConsoleType.swift**

```swift
import SwiftUI

enum ConsoleType: String, CaseIterable, Codable {
    case gb, gbc, gba, nes, snes, genesis

    var displayName: String {
        switch self {
        case .gb: return "Game Boy"
        case .gbc: return "GBC"
        case .gba: return "GBA"
        case .nes: return "NES"
        case .snes: return "SNES"
        case .genesis: return "Genesis"
        }
    }

    var extensions: [String] {
        switch self {
        case .gb: return ["gb"]
        case .gbc: return ["gbc"]
        case .gba: return ["gba"]
        case .nes: return ["nes"]
        case .snes: return ["sfc", "smc"]
        case .genesis: return ["md", "gen"]
        }
    }

    var badgeColor: Color {
        switch self {
        case .gb: return .gray
        case .gbc: return .purple
        case .gba: return .indigo
        case .nes: return .red
        case .snes: return .blue
        case .genesis: return .orange
        }
    }

    /// Console types with compiled cores available. Update as cores are added in Phases 1-4.
    static let availableCores: Set<ConsoleType> = [.gb, .gbc]

    /// File extensions for available cores only
    static var availableExtensions: Set<String> {
        Set(availableCores.flatMap { $0.extensions })
    }

    /// All supported file extensions across all consoles
    static var allExtensions: Set<String> {
        Set(allCases.flatMap { $0.extensions })
    }

    /// Determine console type from a file extension
    static func from(extension ext: String) -> ConsoleType? {
        let lower = ext.lowercased()
        return allCases.first { $0.extensions.contains(lower) }
    }
}
```

- [ ] **Step 2: Add file to Xcode project**

The new file must be included in the CrystalBoy target. Check if the project uses folder references (auto-includes new files) or group references (requires manual add):

```bash
# If this returns 0, the file is NOT in the project and must be added
grep -c "ConsoleType" CrystalBoy.xcodeproj/project.pbxproj
```

If not found: open Xcode, right-click the `Core/` group → "Add Files to CrystalBoy" → select `ConsoleType.swift` → ensure "Add to targets: CrystalBoy" is checked. Alternatively, if the project uses folder references, the file is picked up automatically.

**Note:** This applies to ALL new files created in this plan. Any new `.swift` file must be verified as part of the Xcode target.

- [ ] **Step 3: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED. If it fails with "cannot find type 'ConsoleType'", the file is not in the target — see Step 2.

- [ ] **Step 4: Commit**

```bash
git add CrystalBoy/Core/ConsoleType.swift
git commit -m "feat: add ConsoleType enum for multi-console support"
```

---

## Task 2: Expand GameButton Enum

**Why:** Existing `GameButton` only has 8 GB buttons. New consoles need L, R, X, Y, and Genesis buttons. Must be done before input system changes.

**Files:**
- Modify: `CrystalBoy/Core/EmulatorCore.swift`

- [ ] **Step 1: Expand GameButton in EmulatorCore.swift**

Replace the existing `GameButton` enum:

```swift
enum GameButton: Int, CaseIterable {
    // Shared (all consoles)
    case right = 0, left, up, down, a, b, select, start
    // GBA / SNES / Genesis shoulder buttons
    case l, r
    // SNES face buttons
    case x, y
    // Genesis 6-button extras
    case genesisC, genesisX, genesisY, genesisZ

    /// Buttons used by a given console type
    static func buttons(for console: ConsoleType) -> [GameButton] {
        switch console {
        case .gb, .gbc:
            return [.up, .down, .left, .right, .a, .b, .select, .start]
        case .gba:
            return [.up, .down, .left, .right, .a, .b, .l, .r, .select, .start]
        case .nes:
            return [.up, .down, .left, .right, .a, .b, .select, .start]
        case .snes:
            return [.up, .down, .left, .right, .a, .b, .x, .y, .l, .r, .select, .start]
        case .genesis:
            return [.up, .down, .left, .right, .a, .b, .genesisC, .genesisX, .genesisY, .genesisZ, .start]
        }
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED (existing code only uses the first 8 values, so no breakage)

- [ ] **Step 3: Commit**

```bash
git add CrystalBoy/Core/EmulatorCore.swift
git commit -m "feat: expand GameButton enum for multi-console buttons"
```

---

## Task 3: Update EmulatorAction and KeyBindings for New Buttons + Volume

**Why:** `EmulatorAction` maps keyboard keys to actions. Needs new game button actions (L, R, X, Y, Genesis) and volume actions (volumeUp, volumeDown, mute).

**Files:**
- Modify: `CrystalBoy/Input/KeyBindings.swift`

- [ ] **Step 1: Add new cases to EmulatorAction**

In `KeyBindings.swift`, add new cases to the `EmulatorAction` enum. Add after the existing `select` case:

```swift
enum EmulatorAction: String, CaseIterable, Codable {
    // Game buttons — shared
    case up, down, left, right, a, b, start, select
    // Game buttons — GBA/SNES
    case buttonL, buttonR
    // Game buttons — SNES
    case buttonX, buttonY
    // Game buttons — Genesis
    case genesisC, genesisX, genesisY, genesisZ
    // Save/Load
    case saveState, loadState, prevSlot, nextSlot
    // Speed
    case rewind, fastForward, speedUp, speedDown, speedReset
    // Volume
    case volumeUp, volumeDown, mute
    // Emulator
    case pause, toggleCheats, showHelp, backToLibrary
```

- [ ] **Step 2: Update the `category` property**

```swift
    var category: ActionCategory {
        switch self {
        case .up, .down, .left, .right, .a, .b, .start, .select,
             .buttonL, .buttonR, .buttonX, .buttonY,
             .genesisC, .genesisX, .genesisY, .genesisZ:
            return .gameButtons
        case .saveState, .loadState, .prevSlot, .nextSlot:
            return .saveLoad
        case .rewind, .fastForward, .speedUp, .speedDown, .speedReset:
            return .speed
        case .volumeUp, .volumeDown, .mute:
            return .volume
        case .pause, .toggleCheats, .showHelp, .backToLibrary:
            return .emulator
        }
    }
```

- [ ] **Step 3: Add `volume` to ActionCategory**

```swift
enum ActionCategory: String, CaseIterable {
    case gameButtons = "Game Buttons"
    case saveLoad = "Save & Load"
    case speed = "Speed"
    case volume = "Volume"
    case emulator = "Emulator"
}
```

- [ ] **Step 4: Update `gameButton` property**

```swift
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
        case .buttonL: return .l
        case .buttonR: return .r
        case .buttonX: return .x
        case .buttonY: return .y
        case .genesisC: return .genesisC
        case .genesisX: return .genesisX
        case .genesisY: return .genesisY
        case .genesisZ: return .genesisZ
        default: return nil
        }
    }
```

- [ ] **Step 5: Update `defaultKeyCode` property**

Add cases for the new actions:

```swift
        case .buttonL: return UInt16(kVK_ANSI_A)       // A key
        case .buttonR: return UInt16(kVK_ANSI_S)       // S key
        case .buttonX: return UInt16(kVK_ANSI_D)       // D key
        case .buttonY: return UInt16(kVK_ANSI_C)       // C key
        case .genesisC: return UInt16(kVK_ANSI_C)      // C key
        case .genesisX: return UInt16(kVK_ANSI_D)      // D key
        case .genesisY: return UInt16(kVK_ANSI_F)      // F key
        case .genesisZ: return UInt16(kVK_ANSI_V)      // V key
        case .volumeUp: return UInt16(kVK_ANSI_RightBracket)   // ]
        case .volumeDown: return UInt16(kVK_ANSI_LeftBracket)  // [
        case .mute: return UInt16(kVK_ANSI_M)                  // M
```

- [ ] **Step 6: Update `displayName` property**

```swift
        case .buttonL: return "Button L"
        case .buttonR: return "Button R"
        case .buttonX: return "Button X"
        case .buttonY: return "Button Y"
        case .genesisC: return "Button C"
        case .genesisX: return "Button X"
        case .genesisY: return "Button Y"
        case .genesisZ: return "Button Z"
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .mute: return "Mute"
```

- [ ] **Step 7: Update `defaultKeyName` property**

```swift
        case .buttonL: return "A"
        case .buttonR: return "S"
        case .buttonX: return "D"
        case .buttonY: return "C"
        case .genesisC: return "C"
        case .genesisX: return "D"
        case .genesisY: return "F"
        case .genesisZ: return "V"
        case .volumeUp: return "]"
        case .volumeDown: return "["
        case .mute: return "M"
```

- [ ] **Step 8: Add console-aware action filtering**

Add this method to `EmulatorAction`:

```swift
    /// Actions relevant to a specific console type.
    /// Game buttons are filtered per console; all other categories are always included.
    static func actions(for console: ConsoleType, category: ActionCategory) -> [EmulatorAction] {
        let all = actions(for: category)
        guard category == .gameButtons else { return all }

        let consoleButtons = GameButton.buttons(for: console)
        return all.filter { action in
            guard let button = action.gameButton else { return false }
            return consoleButtons.contains(button)
        }
    }
```

- [ ] **Step 9: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 10: Commit**

```bash
git add CrystalBoy/Input/KeyBindings.swift
git commit -m "feat: add multi-console button actions and volume controls to EmulatorAction"
```

---

## Task 4: Add Volume Control to AudioEngine

**Why:** Volume needs to be controllable from the toolbar and keyboard. AudioEngine owns the AVAudioEngine, so volume control lives here.

**Files:**
- Modify: `CrystalBoy/Audio/AudioEngine.swift`

- [ ] **Step 1: Add volume properties and methods**

Add after the `private var _muted = false` line:

```swift
    private var _volume: Float = 1.0
    private let volumeDefaultsKey = "CrystalBoy.Volume"
```

Replace `init()` with:

```swift
    init() {
        ringBuffer = [Float](repeating: 0, count: bufferSize * 2)
        _volume = UserDefaults.standard.object(forKey: volumeDefaultsKey) as? Float ?? 1.0
    }
```

Add these public methods after `stop()`:

```swift
    var volume: Float {
        lock.withLock { _volume }
    }

    var isMuted: Bool {
        lock.withLock { _muted }
    }

    func setVolume(_ volume: Float) {
        let clamped = max(0.0, min(1.0, volume))
        lock.lock()
        _volume = clamped
        lock.unlock()
        engine.mainMixerNode.outputVolume = _muted ? 0 : clamped
        UserDefaults.standard.set(clamped, forKey: volumeDefaultsKey)
    }

    func toggleMute() {
        lock.lock()
        _muted.toggle()
        let muted = _muted
        let vol = _volume
        lock.unlock()
        engine.mainMixerNode.outputVolume = muted ? 0 : vol
    }
```

- [ ] **Step 2: Apply persisted volume on start**

In the `start()` method, after `try engine.start()`, add:

```swift
            engine.mainMixerNode.outputVolume = _muted ? 0 : _volume
```

- [ ] **Step 3: Remove the old `setMuted` method**

Delete the old `setMuted(_ muted: Bool)` method — replaced by `toggleMute()`.

- [ ] **Step 4: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: May fail if `setMuted` is called elsewhere. Check and fix callers if needed.

- [ ] **Step 5: Commit**

```bash
git add CrystalBoy/Audio/AudioEngine.swift
git commit -m "feat: add volume control with persistence and mute toggle to AudioEngine"
```

---

## Task 5: Wire Volume to InputManager

**Why:** Keyboard shortcuts `[`, `]`, `M` need to control volume via InputManager → AudioEngine.

**Files:**
- Modify: `CrystalBoy/Input/InputManager.swift`

- [ ] **Step 1: Add volume handling to performAction**

In `InputManager.swift`, add these cases inside the `switch action` block in `performAction`, before the `default:` case:

```swift
        case .volumeUp:
            if pressed {
                if let audio = audioEngine {
                    audio.setVolume(audio.volume + 0.1)
                    onVolumeChange?(audio.volume, audio.isMuted)
                }
            }
        case .volumeDown:
            if pressed {
                if let audio = audioEngine {
                    audio.setVolume(audio.volume - 0.1)
                    onVolumeChange?(audio.volume, audio.isMuted)
                }
            }
        case .mute:
            if pressed {
                audioEngine?.toggleMute()
                if let audio = audioEngine {
                    onVolumeChange?(audio.volume, audio.isMuted)
                }
            }
```

- [ ] **Step 2: Add the volume change callback**

Add to the callback properties at the top of `InputManager`:

```swift
    var onVolumeChange: ((Float, Bool) -> Void)?  // (volume, isMuted)
```

- [ ] **Step 3: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Commit**

```bash
git add CrystalBoy/Input/InputManager.swift
git commit -m "feat: wire volume up/down/mute keyboard shortcuts in InputManager"
```

---

## Task 6: Add Volume UI to Game Toolbar

**Why:** Volume slider and mute button in the toolbar next to the speed controls.

**Files:**
- Modify: `CrystalBoy/Game/GameToolbar.swift`

- [ ] **Step 1: Add volume state to ToolbarState**

In `ToolbarState` class, add:

```swift
    @Published var volume: Float = 1.0
    @Published var isMuted = false

    var onVolumeChanged: ((Float) -> Void)?
    var onToggleMute: (() -> Void)?
```

- [ ] **Step 2: Add volume controls to the toolbar**

In `GameBoyShell`, find the `// Right: Speed` section in the controls area HStack. After the speed VStack, add a volume section. Replace the entire `HStack(spacing: 0)` controls area with:

```swift
            // Controls area
            HStack(spacing: 0) {
                // Left: Save/Load
                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        shellButton("SAVE", icon: "square.and.arrow.down") {
                            toolbarState.onSave?()
                        }
                        shellButton("LOAD", icon: "square.and.arrow.up") {
                            toolbarState.onLoad?()
                        }
                    }
                    HStack(spacing: 4) {
                        slotButton("◀") { toolbarState.onPrevSlot?() }
                        Text("Slot \(toolbarState.currentSlot)")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                            .frame(width: 40)
                        slotButton("▶") { toolbarState.onNextSlot?() }
                    }
                }
                .frame(maxWidth: .infinity)

                // Center: Pause
                Button(action: { toolbarState.onTogglePause?() }) {
                    VStack(spacing: 2) {
                        Image(systemName: toolbarState.isPaused ? "play.fill" : "pause.fill")
                            .font(.system(size: 16))
                        Text(toolbarState.isPaused ? "PLAY" : "PAUSE")
                            .font(.system(size: 7, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(width: 50, height: 44)
                    .background(shellDark)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Right: Speed + Volume
                VStack(spacing: 6) {
                    // Speed
                    HStack(spacing: 4) {
                        Image(systemName: "gauge.medium")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(speedLabel)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(toolbarState.speed == 1.0 ? .white.opacity(0.5) : .cyan)
                    }
                    Slider(value: $toolbarState.speed, in: 0.25...4.0, step: 0.05)
                        .tint(.cyan)
                        .frame(width: 120)
                        .onChange(of: toolbarState.speed) { _, val in
                            toolbarState.onSpeedChanged?(val)
                        }
                    if toolbarState.speed != 1.0 {
                        Button("Reset to 100%") {
                            toolbarState.speed = 1.0
                            toolbarState.onSpeedChanged?(1.0)
                        }
                        .font(.system(size: 9))
                        .buttonStyle(.plain)
                        .foregroundStyle(.cyan.opacity(0.7))
                    }

                    // Volume
                    HStack(spacing: 4) {
                        Button(action: { toolbarState.onToggleMute?() }) {
                            Image(systemName: volumeIcon)
                                .font(.system(size: 10))
                                .foregroundStyle(toolbarState.isMuted ? .red.opacity(0.6) : .white.opacity(0.4))
                        }
                        .buttonStyle(.plain)

                        Text(volumeLabel)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(toolbarState.isMuted ? .red.opacity(0.5) : .white.opacity(0.5))
                    }
                    Slider(value: $toolbarState.volume, in: 0...1, step: 0.1)
                        .tint(toolbarState.isMuted ? .red.opacity(0.5) : .green)
                        .frame(width: 120)
                        .onChange(of: toolbarState.volume) { _, val in
                            toolbarState.onVolumeChanged?(val)
                        }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
```

- [ ] **Step 3: Add volume helper computed properties**

Add to `GameBoyShell` after `speedLabel`:

```swift
    private var volumeIcon: String {
        if toolbarState.isMuted { return "speaker.slash.fill" }
        if toolbarState.volume == 0 { return "speaker.fill" }
        if toolbarState.volume < 0.5 { return "speaker.wave.1.fill" }
        return "speaker.wave.2.fill"
    }

    private var volumeLabel: String {
        toolbarState.isMuted ? "MUTE" : "\(Int(round(toolbarState.volume * 100)))%"
    }
```

- [ ] **Step 4: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add CrystalBoy/Game/GameToolbar.swift
git commit -m "feat: add volume slider and mute button to game toolbar"
```

---

## Task 7: Wire Volume in GameSession

**Why:** GameSession creates all components — needs to connect volume toolbar ↔ AudioEngine ↔ InputManager.

**Files:**
- Modify: `CrystalBoy/App/GameSession.swift`

- [ ] **Step 1: Wire volume in startGame()**

In `GameSession.startGame()`, after the line `input.onSpeedChange = { ... }`, add:

```swift
        input.onVolumeChange = { [weak self] volume, muted in
            Task { @MainActor in
                self?.toolbarState.volume = volume
                self?.toolbarState.isMuted = muted
            }
        }
```

After the line `toolbarState.currentSlot = 0`, add:

```swift
        toolbarState.volume = audio.volume
        toolbarState.isMuted = audio.isMuted

        toolbarState.onVolumeChanged = { [weak audio] vol in
            audio?.setVolume(vol)
        }
        toolbarState.onToggleMute = { [weak self, weak audio] in
            audio?.toggleMute()
            if let audio {
                Task { @MainActor in
                    self?.toolbarState.isMuted = audio.isMuted
                }
            }
        }
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add CrystalBoy/App/GameSession.swift
git commit -m "feat: wire volume controls between toolbar, AudioEngine, and InputManager"
```

---

## Task 8: Update ROMItem and LibraryManager for Multi-Console

**Why:** ROMItem needs `consoleType` instead of `isColor`. LibraryManager needs to scan all extensions and support filtering.

**Files:**
- Modify: `CrystalBoy/Library/LibraryManager.swift`

- [ ] **Step 1: Replace ROMItem**

Replace the entire `ROMItem` struct:

```swift
struct ROMItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let consoleType: ConsoleType

    init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.consoleType = ConsoleType.from(extension: url.pathExtension) ?? .gb
    }

    /// Convenience for backward compat — true if GBC
    var isColor: Bool { consoleType == .gbc }
}
```

- [ ] **Step 2: Add filter state and update scan()**

Add to `LibraryManager` properties:

```swift
    @Published var selectedFilter: ConsoleType?
```

Replace the `scan()` method:

```swift
    func scan() {
        guard let folderURL else { return }
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: folderURL, includingPropertiesForKeys: nil
        ) else { return }

        // Only scan extensions for cores that are actually available
        roms = contents
            .filter { ConsoleType.availableExtensions.contains($0.pathExtension.lowercased()) }
            .map { ROMItem(url: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
```

Note: As each core is added in Phases 1-4, simply add the console type to `ConsoleType.availableCores` and the library will automatically pick up those ROM files.

- [ ] **Step 3: Add filtered roms computed property**

Add to `LibraryManager`:

```swift
    var filteredROMs: [ROMItem] {
        guard let filter = selectedFilter else { return roms }
        return roms.filter { $0.consoleType == filter }
    }

    /// Console types that have at least one ROM
    var availableConsoleTypes: [ConsoleType] {
        let types = Set(roms.map { $0.consoleType })
        return ConsoleType.allCases.filter { types.contains($0) }
    }
```

- [ ] **Step 4: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: May have errors in LibraryView where `isColor` was used for badge. Fix in next task.

- [ ] **Step 5: Commit**

```bash
git add CrystalBoy/Library/LibraryManager.swift
git commit -m "feat: update ROMItem with ConsoleType and add library filtering"
```

---

## Task 9: Update LibraryView with Console Filters

**Why:** Add filter pill buttons and update badge colors to use ConsoleType.

**Files:**
- Modify: `CrystalBoy/Library/LibraryView.swift`

- [ ] **Step 1: Replace the entire LibraryView**

```swift
import SwiftUI

struct LibraryView: View {
    @ObservedObject var library: LibraryManager
    var onSelectROM: (ROMItem) -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("CrystalBoy")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.gray)
                .help("Controls Settings")

                Button("Select Folder") {
                    library.selectFolder()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(white: 0.1))

            // Filter pills
            if !library.availableConsoleTypes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        filterPill(label: "All", isActive: library.selectedFilter == nil) {
                            library.selectedFilter = nil
                        }
                        ForEach(library.availableConsoleTypes, id: \.self) { console in
                            filterPill(
                                label: console.displayName,
                                isActive: library.selectedFilter == console
                            ) {
                                library.selectedFilter = console
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(white: 0.1))
            }

            // ROM list
            if library.filteredROMs.isEmpty {
                Spacer()
                if library.folderURL == nil {
                    Text("Select a folder with your ROMs")
                        .foregroundStyle(.gray)
                } else if library.selectedFilter != nil {
                    Text("No \(library.selectedFilter!.displayName) ROMs found")
                        .foregroundStyle(.gray)
                } else {
                    Text("No ROMs found")
                        .foregroundStyle(.gray)
                }
                Spacer()
            } else {
                List(library.filteredROMs) { rom in
                    HStack {
                        Text(rom.consoleType.displayName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rom.consoleType.badgeColor)
                            .cornerRadius(4)
                        Text(rom.name)
                            .foregroundStyle(.white)
                        Spacer()
                        if hasSaveFile(for: rom) {
                            Text("SAV")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(3)
                        }
                    }
                    .listRowBackground(Color(white: 0.12))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onSelectROM(rom)
                    }
                    .contextMenu {
                        Button("Play") { onSelectROM(rom) }
                        Divider()
                        Button("Import Save (.sav)...") {
                            library.importSave(for: rom)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // Footer hint
            HStack {
                Text("Double-click to play  |  Hold H in-game for controls")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(white: 0.1))
        }
        .background(Color(white: 0.08))
    }

    private func filterPill(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? .black : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isActive ? Color.white : Color(white: 0.2))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func hasSaveFile(for rom: ROMItem) -> Bool {
        let savURL = rom.url.deletingPathExtension().appendingPathExtension("sav")
        return FileManager.default.fileExists(atPath: savURL.path)
    }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add CrystalBoy/Library/LibraryView.swift
git commit -m "feat: add console filter pills and multi-console badges to library"
```

---

## Task 10: Make FrameRenderer and GameView Dynamic

**Why:** Currently hardcoded to 160x144 (GB resolution). Needs to work with any resolution from the active EmulatorCore.

**Files:**
- Modify: `CrystalBoy/Rendering/GameView.swift`

- [ ] **Step 1: Make FrameRenderer resolution-aware**

Replace the entire `FrameRenderer` class:

```swift
@MainActor
final class FrameRenderer: ObservableObject {
    @Published var currentFrame: CGImage?
    @Published var screenWidth: Int = 160
    @Published var screenHeight: Int = 144

    nonisolated func updateFrame(pixels: UnsafePointer<UInt32>, width: Int, height: Int) {
        let byteCount = width * height * 4
        let data = Data(bytes: pixels, count: byteCount)

        guard let provider = CGDataProvider(data: data as CFData) else { return }

        let image = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )

        guard let image else { return }

        DispatchQueue.main.async { [weak self] in
            self?.currentFrame = image
            self?.screenWidth = width
            self?.screenHeight = height
        }
    }
}
```

- [ ] **Step 2: Update GameView to use dynamic aspect ratio**

Replace the `GameView` struct:

```swift
struct GameView: View {
    @ObservedObject var renderer: FrameRenderer

    private var aspectRatio: CGFloat {
        guard renderer.screenHeight > 0 else { return 10.0 / 9.0 }
        return CGFloat(renderer.screenWidth) / CGFloat(renderer.screenHeight)
    }

    var body: some View {
        if let cgImage = renderer.currentFrame {
            Image(decorative: cgImage, scale: 1.0)
                .interpolation(.none)
                .resizable()
                .aspectRatio(aspectRatio, contentMode: .fit)
        } else {
            Color.black
                .aspectRatio(aspectRatio, contentMode: .fit)
        }
    }
}
```

- [ ] **Step 3: Update GameBoyShell aspect ratio**

In `GameToolbar.swift`, find the line:
```swift
                .aspectRatio(CGFloat(160) / CGFloat(144), contentMode: .fit)
```

Replace with:
```swift
                .aspectRatio(CGFloat(renderer.screenWidth) / CGFloat(max(1, renderer.screenHeight)), contentMode: .fit)
```

`GameBoyShell` already has `renderer` as a property so this works directly.

- [ ] **Step 4: Update video callback in GameSession**

In `GameSession.swift`, find the video callback:
```swift
        emu.setVideoCallback { pixels in
            renderer.updateFrame(pixels: pixels)
        }
```

Replace with:
```swift
        let width = emu.screenWidth
        let height = emu.screenHeight
        emu.setVideoCallback { pixels in
            renderer.updateFrame(pixels: pixels, width: width, height: height)
        }
```

- [ ] **Step 5: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add CrystalBoy/Rendering/GameView.swift CrystalBoy/Game/GameToolbar.swift CrystalBoy/App/GameSession.swift
git commit -m "feat: make renderer and game view support dynamic resolutions"
```

---

## Task 11: Refactor GameSession for Multi-Console Core Instantiation

**Why:** GameSession currently hardcodes `SameBoyEmulator`. Needs to instantiate the correct core based on ROM's console type.

**Files:**
- Modify: `CrystalBoy/App/GameSession.swift`

- [ ] **Step 1: Add core factory method**

Add this method to `GameSession`:

```swift
    private func makeEmulator(for rom: ROMItem) -> EmulatorCore? {
        switch rom.consoleType {
        case .gb, .gbc:
            return SameBoyEmulator(isColorGB: rom.consoleType == .gbc)
        case .gba, .nes, .snes, .genesis:
            return nil  // Core not yet implemented
        }
    }
```

- [ ] **Step 2: Use factory in startGame()**

In `startGame()`, replace:
```swift
        let emu = SameBoyEmulator(isColorGB: rom.isColor)
```

With:
```swift
        guard let emu = makeEmulator(for: rom) else {
            // Core not available for this console type
            return
        }
```

- [ ] **Step 3: Store emulator as protocol type**

In `GameSession`, change:
```swift
    private(set) var emulator: SameBoyEmulator?
```
To:
```swift
    private(set) var emulator: EmulatorCore?
```

- [ ] **Step 4: Update SameBoy-specific boot ROM loading**

The `SameBoyEmulator.loadROM()` internally handles boot ROMs, so no change needed — the protocol `loadROM(url:)` is what GameSession calls.

- [ ] **Step 5: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add CrystalBoy/App/GameSession.swift
git commit -m "feat: refactor GameSession to use core factory for multi-console support"
```

---

## Task 12: Update ControlsSettingsView for Per-Console Filtering

**Why:** Settings should only show buttons relevant to the active console (e.g., no L/R when playing GB).

**Files:**
- Modify: `CrystalBoy/Settings/ControlsSettingsView.swift`

- [ ] **Step 1: Add consoleType parameter**

Add to `ControlsSettingsView`:

```swift
    var consoleType: ConsoleType?
```

- [ ] **Step 2: Update sectionView to filter by console**

Replace the `sectionView` method:

```swift
    @ViewBuilder
    private func sectionView(for category: ActionCategory) -> some View {
        let actions: [EmulatorAction]
        if category == .gameButtons, let console = consoleType {
            actions = EmulatorAction.actions(for: console, category: category)
        } else {
            actions = EmulatorAction.actions(for: category)
        }

        if !actions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(category.rawValue)
                    .font(.headline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 2) {
                    ForEach(actions, id: \.self) { action in
                        HStack {
                            Text(action.displayName)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if listeningFor == action {
                                Text("Press a key...")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.yellow)
                                    .frame(width: 120, alignment: .trailing)
                            } else {
                                Text(keyBindings.keyCode(for: action).map { keyCodeName($0) } ?? "—")
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(4)
                                    .frame(width: 120, alignment: .trailing)
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(listeningFor == action ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(4)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            listeningFor = action
                        }
                    }
                }
            }
        }
    }
```

- [ ] **Step 3: Update callers in CrystalBoyApp.swift**

In `CrystalBoyApp.swift`, update the sheet content to pass consoleType. Replace:

```swift
            .sheet(isPresented: $showControlsSettings) {
                if let bindings = session.inputManager?.keyBindings {
                    ControlsSettingsView(keyBindings: bindings)
                } else {
                    ControlsSettingsView(keyBindings: KeyBindings())
                }
            }
```

With:

```swift
            .sheet(isPresented: $showControlsSettings) {
                if let bindings = session.inputManager?.keyBindings {
                    ControlsSettingsView(keyBindings: bindings, consoleType: session.activeConsoleType)
                } else {
                    ControlsSettingsView(keyBindings: KeyBindings(), consoleType: nil)
                }
            }
```

- [ ] **Step 4: Add activeConsoleType to GameSession**

In `GameSession.swift`, add a property:

```swift
    @Published var activeConsoleType: ConsoleType?
```

In `startGame()`, after `let emu = makeEmulator(for: rom)`, add:

```swift
        activeConsoleType = rom.consoleType
```

In `stopGame()`, add:

```swift
        activeConsoleType = nil
```

- [ ] **Step 5: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add CrystalBoy/Settings/ControlsSettingsView.swift CrystalBoy/App/CrystalBoyApp.swift CrystalBoy/App/GameSession.swift
git commit -m "feat: filter controls settings by active console type"
```

---

## Task 13: Add App Icon

**Why:** The app needs a custom icon.

**Files:**
- Create: `CrystalBoy/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `CrystalBoy/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png`

- [ ] **Step 1: Create the AppIcon.appiconset directory**

```bash
mkdir -p /Users/efmenem/Projects/CrystalBoy/CrystalBoy/Resources/Assets.xcassets/AppIcon.appiconset
```

- [ ] **Step 2: Create Contents.json**

Write to `CrystalBoy/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`:

```json
{
  "images" : [
    {
      "filename" : "icon_1024.png",
      "idiom" : "mac",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
```

- [ ] **Step 3: Generate the icon programmatically**

Create a 1024x1024 PNG icon using a Swift script or a design tool. The icon should be a crystal/gem shape with a pixel-art retro aesthetic on a dark background. Use purple as the primary color (matching the app's GBC purple theme).

One approach: create a simple Swift script that uses CoreGraphics to draw the icon:

```bash
cat > /tmp/gen_icon.swift << 'SWIFT'
import Cocoa

let size = 1024
let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

let ctx = NSGraphicsContext.current!.cgContext

// Background: dark rounded rect
ctx.setFillColor(CGColor(red: 0.12, green: 0.08, blue: 0.18, alpha: 1))
let bgPath = CGPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), cornerWidth: 200, cornerHeight: 200, transform: nil)
ctx.addPath(bgPath)
ctx.fillPath()

// Crystal shape (hexagonal gem) — centered
let cx = Double(size) / 2
let cy = Double(size) / 2
let gemW = 340.0
let gemH = 440.0
let topW = 260.0
let topH = 140.0

// Main gem body (purple gradient)
let gemPath = CGMutablePath()
gemPath.move(to: CGPoint(x: cx, y: cy + gemH / 2))           // bottom point
gemPath.addLine(to: CGPoint(x: cx - gemW / 2, y: cy))        // left
gemPath.addLine(to: CGPoint(x: cx - topW / 2, y: cy + topH)) // top-left
gemPath.addLine(to: CGPoint(x: cx + topW / 2, y: cy + topH)) // top-right
gemPath.addLine(to: CGPoint(x: cx + gemW / 2, y: cy))        // right
gemPath.closeSubpath()

// Light purple fill
ctx.addPath(gemPath)
ctx.setFillColor(CGColor(red: 0.55, green: 0.35, blue: 0.80, alpha: 1))
ctx.fillPath()

// Left facet (darker)
let leftFacet = CGMutablePath()
leftFacet.move(to: CGPoint(x: cx, y: cy + gemH / 2))
leftFacet.addLine(to: CGPoint(x: cx - gemW / 2, y: cy))
leftFacet.addLine(to: CGPoint(x: cx, y: cy + topH))
leftFacet.closeSubpath()
ctx.addPath(leftFacet)
ctx.setFillColor(CGColor(red: 0.40, green: 0.25, blue: 0.65, alpha: 1))
ctx.fillPath()

// Right facet (lightest)
let rightFacet = CGMutablePath()
rightFacet.move(to: CGPoint(x: cx, y: cy + gemH / 2))
rightFacet.addLine(to: CGPoint(x: cx + gemW / 2, y: cy))
rightFacet.addLine(to: CGPoint(x: cx, y: cy + topH))
rightFacet.closeSubpath()
ctx.addPath(rightFacet)
ctx.setFillColor(CGColor(red: 0.65, green: 0.45, blue: 0.90, alpha: 1))
ctx.fillPath()

// Pixel grid overlay (retro feel) — subtle grid lines
ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.05))
ctx.setLineWidth(1)
let gridSize = 32
for i in stride(from: 0, to: size, by: gridSize) {
    ctx.move(to: CGPoint(x: i, y: 0))
    ctx.addLine(to: CGPoint(x: i, y: size))
    ctx.move(to: CGPoint(x: 0, y: i))
    ctx.addLine(to: CGPoint(x: size, y: i))
}
ctx.strokePath()

// Shine highlight
ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.15))
let shine = CGMutablePath()
shine.move(to: CGPoint(x: cx - topW / 2 + 20, y: cy + topH - 10))
shine.addLine(to: CGPoint(x: cx - 30, y: cy + topH - 10))
shine.addLine(to: CGPoint(x: cx - gemW / 2 + 40, y: cy + 20))
shine.closeSubpath()
ctx.addPath(shine)
ctx.fillPath()

image.unlockFocus()

// Save as PNG
let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let rep = NSBitmapImageRep(cgImage: cgImage)
rep.size = NSSize(width: size, height: size)
let pngData = rep.representation(using: .png, properties: [:])!
try! pngData.write(to: URL(fileURLWithPath: "/Users/efmenem/Projects/CrystalBoy/CrystalBoy/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png"))
print("Icon generated!")
SWIFT
swift /tmp/gen_icon.swift
```

If the script approach doesn't work, alternatively create a simple 1024x1024 purple gem icon using any image editor and place it at the path above.

- [ ] **Step 4: Verify the icon file exists**

```bash
file /Users/efmenem/Projects/CrystalBoy/CrystalBoy/Resources/Assets.xcassets/AppIcon.appiconset/icon_1024.png
```

Expected: PNG image data, 1024 x 1024

- [ ] **Step 5: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 6: Commit**

```bash
git add CrystalBoy/Resources/Assets.xcassets/AppIcon.appiconset/
git commit -m "feat: add crystal gem app icon"
```

---

## Task 14: Update Help Overlay for Volume Controls

**Why:** The in-game help overlay (Hold H) needs to show the new volume controls section.

**Files:**
- Modify: `CrystalBoy/Game/GameToolbar.swift`

- [ ] **Step 1: Update helpOverlay in GameBoyShell**

Find the `helpOverlay` computed property. Add the volume section. Replace the `HStack(alignment: .top, spacing: 24)` inside it:

```swift
            HStack(alignment: .top, spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    helpSection("Game Buttons", category: .gameButtons)
                    Spacer().frame(height: 8)
                    helpSection("Speed", category: .speed)
                }
                VStack(alignment: .leading, spacing: 4) {
                    helpSection("Save & Load", category: .saveLoad)
                    Spacer().frame(height: 8)
                    helpSection("Volume", category: .volume)
                    Spacer().frame(height: 8)
                    helpSection("Emulator", category: .emulator)
                }
            }
```

- [ ] **Step 2: Verify it compiles**

Run: `cd /Users/efmenem/Projects/CrystalBoy && xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add CrystalBoy/Game/GameToolbar.swift
git commit -m "feat: add volume controls section to help overlay"
```

---

## Task 15: Final Verification

**Why:** Ensure everything compiles and the GB/GBC emulation still works correctly after all refactoring.

- [ ] **Step 1: Clean build**

```bash
cd /Users/efmenem/Projects/CrystalBoy
xcodebuild clean -scheme CrystalBoy -destination 'platform=macOS'
xcodebuild -scheme CrystalBoy -destination 'platform=macOS' build 2>&1 | tail -20
```

Expected: BUILD SUCCEEDED

- [ ] **Step 2: Test manually**

Launch the app and verify:
1. Library shows existing GB/GBC ROMs with correct badges
2. Filter pills show "All" + available console types
3. Opening a GB/GBC ROM still works as before
4. Volume slider appears in toolbar
5. `[` / `]` / `M` keys control volume
6. Help overlay (H) shows Volume section
7. Settings shows only GB buttons when playing a GB game

- [ ] **Step 3: Commit any fixes**

If any compilation or runtime fixes were needed, commit them:

```bash
git add -A
git commit -m "fix: resolve issues from Phase 0 integration"
```
