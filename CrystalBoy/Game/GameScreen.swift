import SwiftUI

struct GameScreen: View {
    @ObservedObject var renderer: FrameRenderer
    @ObservedObject var appState: AppState
    var keyBindings: KeyBindings?

    var body: some View {
        ZStack {
            GameView(renderer: renderer)
                .background(Color.black)

            // Help overlay
            if appState.showHelp {
                helpOverlay
            }

            // Toast overlay
            if let toast = appState.toastMessage {
                VStack {
                    Spacer()
                    Text(toast)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(6)
                        .padding(.bottom, 20)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeOut(duration: 0.3), value: appState.toastMessage)
            }
        }
    }

    private var helpOverlay: some View {
        VStack(spacing: 12) {
            Text("CONTROLS")
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)

            HStack(alignment: .top, spacing: 24) {
                // Left column: Game + Speed
                VStack(alignment: .leading, spacing: 4) {
                    helpSection("Game Buttons", category: .gameButtons)
                    Spacer().frame(height: 8)
                    helpSection("Speed", category: .speed)
                }

                // Right column: Save + Emulator
                VStack(alignment: .leading, spacing: 4) {
                    helpSection("Save & Load", category: .saveLoad)
                    Spacer().frame(height: 8)
                    helpSection("Emulator", category: .emulator)
                }
            }

            Text("Release H to close")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.gray)
        }
        .padding(20)
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func helpSection(_ title: String, category: ActionCategory) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .foregroundStyle(.yellow)

        ForEach(EmulatorAction.actions(for: category), id: \.self) { action in
            HStack(spacing: 8) {
                Text(keyName(for: action))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .frame(width: 60, alignment: .trailing)
                Text(action.displayName)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.white)
            }
        }
    }

    private func keyName(for action: EmulatorAction) -> String {
        guard let bindings = keyBindings,
              let code = bindings.keyCode(for: action) else {
            return action.defaultKeyName
        }
        return keyCodeName(code)
    }

    private func keyCodeName(_ keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            0x7E: "Up", 0x7D: "Down", 0x7B: "Left", 0x7C: "Right",
            0x24: "Enter", 0x33: "Bksp", 0x31: "Space", 0x30: "Tab", 0x35: "Esc",
            0x06: "Z", 0x07: "X", 0x0F: "R",
            0x18: "+", 0x1B: "-", 0x1D: "0",
            0x78: "F2", 0x63: "F3", 0x60: "F5", 0x62: "F7", 0x65: "F9",
        ]
        return names[keyCode] ?? "K\(keyCode)"
    }
}

// Default key names for when no KeyBindings available
extension EmulatorAction {
    var defaultKeyName: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .a: return "Z"
        case .b: return "X"
        case .start: return "Enter"
        case .select: return "Bksp"
        case .saveState: return "F5"
        case .loadState: return "F7"
        case .prevSlot: return "F2"
        case .nextSlot: return "F3"
        case .rewind: return "R"
        case .fastForward: return "Tab"
        case .speedUp: return "+"
        case .speedDown: return "-"
        case .speedReset: return "0"
        case .pause: return "Space"
        case .toggleCheats: return "F9"
        case .showHelp: return "H"
        case .backToLibrary: return "Esc"
        }
    }
}
