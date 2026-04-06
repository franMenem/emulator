import SwiftUI

@main
struct CrystalBoyApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var library = LibraryManager()
    @StateObject private var session = GameSession()
    @State private var showControlsSettings = false
    @State private var showCheats = false

    var body: some Scene {
        Window("CrystalBoy", id: "main") {
            Group {
                switch appState.currentScreen {
                case .library:
                    LibraryView(library: library) { rom in
                        session.startGame(rom: rom, appState: appState)
                    } onOpenSettings: {
                        showControlsSettings = true
                    }
                case .game:
                    GameScreen(
                        renderer: session.renderer,
                        appState: appState,
                        toolbarState: session.toolbarState,
                        keyBindings: session.inputManager?.keyBindings,
                        onBack: {
                            session.stopGame()
                            appState.currentScreen = .library
                        },
                        onSettings: {
                            showControlsSettings = true
                        },
                        onCheats: {
                            showCheats = true
                        }
                    )
                }
            }
            .frame(minWidth: 400, minHeight: 450)
            .background(Color(white: 0.06))
            .sheet(isPresented: $showControlsSettings) {
                if let bindings = session.inputManager?.keyBindings {
                    ControlsSettingsView(keyBindings: bindings, consoleType: session.activeConsoleType)
                } else {
                    ControlsSettingsView(keyBindings: KeyBindings(), consoleType: nil)
                }
            }
            .sheet(isPresented: $showCheats) {
                if let cheats = session.cheatManager {
                    CheatsView(cheatManager: cheats)
                }
            }
        }
        .defaultSize(width: 520, height: 580)
        .commands {
            CommandGroup(after: .appSettings) {
                Button("Controls...") {
                    showControlsSettings = true
                }
                .keyboardShortcut(",", modifiers: .command)

                Button("Cheats...") {
                    showCheats = true
                }
                .keyboardShortcut("k", modifiers: .command)
            }
        }
    }
}
