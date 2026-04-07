import Foundation
import AppKit

/// Owns all game-session state: emulator, thread, audio, input, saves, cheats.
/// Lives as a @StateObject so SwiftUI doesn't reset it.
@MainActor
final class GameSession: ObservableObject {
    let renderer = FrameRenderer()
    let toolbarState = ToolbarState()

    private(set) var emulator: EmulatorCore?
    private(set) var emuThread: EmulationThread?
    private(set) var inputManager: InputManager?
    private(set) var audioEngine: AudioEngine?
    private(set) var saveManager: SaveManager?
    private(set) var cheatManager: CheatManager?

    @Published var manuallyPaused = false
    @Published var activeConsoleType: ConsoleType?

    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?

    init() {
        setupNotifications()
    }

    nonisolated deinit {}

    // MARK: - Game Lifecycle

    func startGame(rom: ROMItem, appState: AppState) {
        stopGame()

        guard let emu = makeEmulator(for: rom) else {
            return
        }
        activeConsoleType = rom.consoleType

        // Audio
        let audio = AudioEngine()
        let audioRate: Double
        switch rom.consoleType {
        case .gba: audioRate = 32768
        case .snes: audioRate = 32040
        case .genesis: audioRate = 44100
        default: audioRate = 48000
        }
        audio.start(sampleRate: audioRate)
        emu.setSampleRate(audio.currentSampleRate)
        emu.setAudioCallback { [weak audio] left, right in
            audio?.pushSample(left: left, right: right)
        }

        // Video — read width/height dynamically for cores that change resolution (e.g. SNES hi-res)
        let renderer = self.renderer
        let defaultW = emu.screenWidth
        let defaultH = emu.screenHeight
        emu.setVideoCallback { [weak emu] pixels in
            let w = emu?.screenWidth ?? defaultW
            let h = emu?.screenHeight ?? defaultH
            renderer.updateFrame(pixels: pixels, width: w, height: h)
        }

        // Rewind
        emu.setRewindLength(seconds: 30)

        // Load ROM
        do {
            try emu.loadROM(url: rom.url)
        } catch {
            print("Failed to load ROM: \(error)")
            audio.stop()
            return
        }

        // Emulation thread — use correct FPS per console
        let fps: Double
        switch rom.consoleType {
        case .gb, .gbc, .gba: fps = 59.7275
        case .nes, .snes: fps = 60.0988
        case .genesis: fps = 59.922
        }
        let thread = EmulationThread(emulator: emu, targetFPS: fps)

        // Input
        let input = InputManager(emulator: emu, emuThread: thread, consoleType: rom.consoleType)
        input.audioEngine = audio
        thread.inputManager = input

        // Saves — setROM must be after loadROM so libretro cores have SRAM initialized
        let saves = SaveManager(emulator: emu, emuThread: thread)
        saves.onToast = { msg in
            Task { @MainActor in appState.showToast(msg) }
        }
        saves.setROM(url: rom.url)

        // Cheats
        let cheats = CheatManager(emulator: emu)
        cheats.onToast = { msg in
            Task { @MainActor in appState.showToast(msg) }
        }
        cheats.setROM(url: rom.url)

        // Wire keyboard input actions
        input.onSaveState = { [weak self] in
            saves.saveState()
            Task { @MainActor in self?.toolbarState.currentSlot = saves.currentSlotIndex }
        }
        input.onLoadState = { saves.loadState() }
        input.onPrevSlot = { [weak self] in
            saves.prevSlot()
            Task { @MainActor in self?.toolbarState.currentSlot = saves.currentSlotIndex }
        }
        input.onNextSlot = { [weak self] in
            saves.nextSlot()
            Task { @MainActor in self?.toolbarState.currentSlot = saves.currentSlotIndex }
        }
        input.onToggleCheats = { cheats.toggleCheats() }
        input.onShowHelp = { show in
            Task { @MainActor in appState.showHelp = show }
        }
        input.onSpeedChange = { [weak self] speed in
            Task { @MainActor in
                self?.toolbarState.speed = speed
            }
        }
        input.onVolumeChange = { [weak self] volume, muted in
            Task { @MainActor in
                self?.toolbarState.volume = volume
                self?.toolbarState.isMuted = muted
            }
        }
        input.onPause = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.togglePause(thread: thread, appState: appState)
            }
        }
        input.onBackToLibrary = { [weak self] in
            Task { @MainActor in
                self?.stopGame()
                appState.currentScreen = .library
            }
        }

        // Wire toolbar button actions
        toolbarState.isPaused = false
        toolbarState.speed = 1.0
        toolbarState.currentSlot = 0

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

        toolbarState.onTogglePause = { [weak self] in
            self?.togglePause(thread: thread, appState: appState)
        }
        toolbarState.onSave = { [weak self] in
            saves.saveState()
            Task { @MainActor in self?.toolbarState.currentSlot = saves.currentSlotIndex }
        }
        toolbarState.onLoad = { saves.loadState() }
        toolbarState.onPrevSlot = { [weak self] in
            saves.prevSlot()
            Task { @MainActor in self?.toolbarState.currentSlot = saves.currentSlotIndex }
        }
        toolbarState.onNextSlot = { [weak self] in
            saves.nextSlot()
            Task { @MainActor in self?.toolbarState.currentSlot = saves.currentSlotIndex }
        }
        toolbarState.onSpeedChanged = { [weak self] speed in
            thread.setSpeed(speed)
            self?.inputManager?.setSpeedFromSlider(speed)
        }

        // Store references
        self.emulator = emu
        self.emuThread = thread
        self.inputManager = input
        self.audioEngine = audio
        self.saveManager = saves
        self.cheatManager = cheats
        self.manuallyPaused = false

        // Keyboard monitors
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            input.handleKeyDown(event: event) ? nil : event
        }
        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            input.handleKeyUp(event: event) ? nil : event
        }

        // Start
        thread.start()
        appState.currentScreen = .game(rom.url)
    }

    private func togglePause(thread: EmulationThread, appState: AppState) {
        manuallyPaused.toggle()
        toolbarState.isPaused = manuallyPaused
        if manuallyPaused {
            thread.pause()
            appState.showToast("Paused")
        } else {
            thread.resume()
            appState.showToast("Resumed")
        }
    }

    func stopGame() {
        if let m = keyDownMonitor { NSEvent.removeMonitor(m); keyDownMonitor = nil }
        if let m = keyUpMonitor { NSEvent.removeMonitor(m); keyUpMonitor = nil }

        saveManager?.cleanup()
        emuThread?.stop()
        audioEngine?.stop()

        emulator = nil
        emuThread = nil
        inputManager = nil
        audioEngine = nil
        saveManager = nil
        cheatManager = nil
        activeConsoleType = nil
    }

    // MARK: - Core Factory

    private func makeEmulator(for rom: ROMItem) -> EmulatorCore? {
        switch rom.consoleType {
        case .gb, .gbc:
            return SameBoyEmulator(isColorGB: rom.consoleType == .gbc)
        case .gba:
            return MGBAEmulator()
        case .nes:
            return NestopiaEmulator()
        case .snes:
            return Snes9xEmulator()
        case .genesis:
            return GenesisEmulator()
        }
    }

    // MARK: - Focus Notifications

    private func setupNotifications() {
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.emuThread?.pause()
        }
        activeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, !self.manuallyPaused else { return }
            self.emuThread?.resume()
        }
    }
}
