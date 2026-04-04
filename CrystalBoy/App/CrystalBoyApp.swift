import SwiftUI

@main
struct CrystalBoyApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var library = LibraryManager()
    @State private var showControlsSettings = false

    // Game session state
    @State private var gameNSView = GameNSView(frame: .zero)
    @State private var emulator: SameBoyEmulator?
    @State private var emuThread: EmulationThread?
    @State private var inputManager: InputManager?
    @State private var audioEngine: AudioEngine?
    @State private var saveManager: SaveManager?
    @State private var cheatManager: CheatManager?
    @State private var manuallyPaused = false

    var body: some Scene {
        Window("CrystalBoy", id: "main") {
            Group {
                switch appState.currentScreen {
                case .library:
                    LibraryView(library: library) { rom in
                        startGame(rom: rom)
                    }
                case .game:
                    GameScreen(gameNSView: gameNSView, appState: appState)
                }
            }
            .frame(minWidth: 320, minHeight: 288)
            .background(Color.black)
            .onAppear { setupNotifications() }
        }
        .defaultSize(width: 480, height: 432)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Controls...") {
                    showControlsSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    // MARK: - Game Lifecycle

    private func startGame(rom: ROMItem) {
        let emu = SameBoyEmulator(isColorGB: rom.isColor)

        // Audio
        let audio = AudioEngine()
        audio.start()
        emu.setSampleRate(audio.currentSampleRate)
        emu.setAudioCallback { [audio] left, right in
            audio.pushSample(left: left, right: right)
        }

        // Video
        emu.setVideoCallback { [gameNSView] pixels in
            gameNSView.updateFrame(pixels: pixels)
        }

        // Rewind
        emu.setRewindLength(seconds: 30)

        // Load ROM
        do {
            try emu.loadROM(url: rom.url)
        } catch {
            print("Failed to load ROM: \(error)")
            return
        }

        // Emulation thread
        let thread = EmulationThread(emulator: emu)

        // Input
        let input = InputManager(emulator: emu, emuThread: thread)
        input.audioEngine = audio
        thread.inputManager = input

        // Saves
        let saves = SaveManager(emulator: emu)
        saves.setROM(url: rom.url)
        saves.onToast = { [appState] msg in
            DispatchQueue.main.async { appState.showToast(msg) }
        }

        // Cheats
        let cheats = CheatManager(emulator: emu)
        cheats.onToast = { [appState] msg in
            DispatchQueue.main.async { appState.showToast(msg) }
        }

        // Wire input actions
        input.onSaveState = { [saves] in saves.saveState() }
        input.onLoadState = { [saves] in saves.loadState() }
        input.onPrevSlot = { [saves] in saves.prevSlot() }
        input.onNextSlot = { [saves] in saves.nextSlot() }
        input.onToggleCheats = { [cheats] in cheats.toggleCheats() }
        input.onPause = { [weak thread, appState] in
            guard let thread else { return }
            manuallyPaused.toggle()
            if manuallyPaused {
                thread.pause()
                DispatchQueue.main.async { appState.showToast("Paused") }
            } else {
                thread.resume()
                DispatchQueue.main.async { appState.showToast("Resumed") }
            }
        }
        input.onBackToLibrary = { [appState] in
            DispatchQueue.main.async {
                stopGame()
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

        // Start keyboard monitoring
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return input.handleKeyDown(event: event) ? nil : event
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyUp) { event in
            return input.handleKeyUp(event: event) ? nil : event
        }

        // Start
        thread.start()
        appState.currentScreen = .game(rom.url)
    }

    private func stopGame() {
        emuThread?.stop()
        audioEngine?.stop()
        saveManager?.cleanup()

        emulator = nil
        emuThread = nil
        inputManager = nil
        audioEngine = nil
        saveManager = nil
        cheatManager = nil
    }

    // MARK: - Focus Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil, queue: .main
        ) { _ in
            emuThread?.pause()
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil, queue: .main
        ) { _ in
            if !manuallyPaused {
                emuThread?.resume()
            }
        }
    }
}
