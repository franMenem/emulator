import Foundation
import AppKit

/// Owns all game-session state: emulator, thread, audio, input, saves, cheats.
/// Lives as a @StateObject so SwiftUI doesn't reset it.
@MainActor
final class GameSession: ObservableObject {
    let renderer = FrameRenderer()

    private(set) var emulator: SameBoyEmulator?
    private(set) var emuThread: EmulationThread?
    private(set) var inputManager: InputManager?
    private(set) var audioEngine: AudioEngine?
    private(set) var saveManager: SaveManager?
    private(set) var cheatManager: CheatManager?

    @Published var manuallyPaused = false

    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var activeObserver: NSObjectProtocol?

    init() {
        setupNotifications()
    }

    nonisolated deinit {
        // Notification observers are removed automatically when the object is deallocated
        // Game cleanup should have been called by the app lifecycle before this point
    }

    // MARK: - Game Lifecycle

    func startGame(rom: ROMItem, appState: AppState) {
        // Clean up any previous session
        stopGame()

        let emu = SameBoyEmulator(isColorGB: rom.isColor)

        // Audio
        let audio = AudioEngine()
        audio.start()
        emu.setSampleRate(audio.currentSampleRate)
        emu.setAudioCallback { [weak audio] left, right in
            audio?.pushSample(left: left, right: right)
        }

        // Video
        let renderer = self.renderer
        emu.setVideoCallback { pixels in
            renderer.updateFrame(pixels: pixels)
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

        // Emulation thread
        let thread = EmulationThread(emulator: emu)

        // Input
        let input = InputManager(emulator: emu, emuThread: thread)
        input.audioEngine = audio
        thread.inputManager = input

        // Saves
        let saves = SaveManager(emulator: emu, emuThread: thread)
        saves.setROM(url: rom.url)
        saves.onToast = { msg in
            Task { @MainActor in appState.showToast(msg) }
        }

        // Cheats
        let cheats = CheatManager(emulator: emu)
        cheats.onToast = { msg in
            Task { @MainActor in appState.showToast(msg) }
        }

        // Wire input actions
        input.onSaveState = { saves.saveState() }
        input.onLoadState = { saves.loadState() }
        input.onPrevSlot = { saves.prevSlot() }
        input.onNextSlot = { saves.nextSlot() }
        input.onToggleCheats = { cheats.toggleCheats() }
        input.onPause = { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.manuallyPaused.toggle()
                if self.manuallyPaused {
                    thread.pause()
                    appState.showToast("Paused")
                } else {
                    thread.resume()
                    appState.showToast("Resumed")
                }
            }
        }
        input.onBackToLibrary = { [weak self] in
            Task { @MainActor in
                self?.stopGame()
                appState.currentScreen = .library
            }
        }

        // Store references
        self.emulator = emu
        self.emuThread = thread
        self.inputManager = input
        self.audioEngine = audio
        self.saveManager = saves
        self.cheatManager = cheats
        self.manuallyPaused = false

        // Keyboard monitors (stored for cleanup)
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

    func stopGame() {
        // Remove keyboard monitors first
        if let m = keyDownMonitor { NSEvent.removeMonitor(m); keyDownMonitor = nil }
        if let m = keyUpMonitor { NSEvent.removeMonitor(m); keyUpMonitor = nil }

        // Save before stopping emulation
        saveManager?.cleanup()

        emuThread?.stop()
        audioEngine?.stop()

        emulator = nil
        emuThread = nil
        inputManager = nil
        audioEngine = nil
        saveManager = nil
        cheatManager = nil
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
