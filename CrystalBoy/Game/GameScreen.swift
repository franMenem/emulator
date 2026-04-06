import SwiftUI

struct GameScreen: View {
    @ObservedObject var renderer: FrameRenderer
    @ObservedObject var appState: AppState
    @ObservedObject var toolbarState: ToolbarState
    var keyBindings: KeyBindings?
    var onBack: () -> Void
    var onSettings: () -> Void

    var body: some View {
        GameBoyShell(
            renderer: renderer,
            appState: appState,
            toolbarState: toolbarState,
            keyBindings: keyBindings,
            onBack: onBack,
            onSettings: onSettings
        )
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.06))
    }
}
