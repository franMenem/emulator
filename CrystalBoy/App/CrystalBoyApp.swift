import SwiftUI

@main
struct CrystalBoyApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var library = LibraryManager()
    @StateObject private var session = GameSession()
    @State private var showControlsSettings = false

    var body: some Scene {
        Window("CrystalBoy", id: "main") {
            Group {
                switch appState.currentScreen {
                case .library:
                    LibraryView(library: library) { rom in
                        session.startGame(rom: rom, appState: appState)
                    }
                case .game:
                    GameScreen(renderer: session.renderer, appState: appState, keyBindings: session.inputManager?.keyBindings)
                }
            }
            .frame(minWidth: 320, minHeight: 288)
            .background(Color.black)
            .sheet(isPresented: $showControlsSettings) {
                if let bindings = session.inputManager?.keyBindings {
                    ControlsSettingsView(keyBindings: bindings)
                } else {
                    ControlsSettingsView(keyBindings: KeyBindings())
                }
            }
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
}
