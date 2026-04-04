import SwiftUI
import Carbon.HIToolbox

struct ControlsSettingsView: View {
    let keyBindings: KeyBindings
    @State private var listeningFor: EmulatorAction?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Text("Controls")
                .font(.headline)
                .padding()

            List {
                ForEach(EmulatorAction.allCases, id: \.self) { action in
                    HStack {
                        Text(action.displayName)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if listeningFor == action {
                            Text("Press a key...")
                                .foregroundStyle(.yellow)
                                .italic()
                        } else {
                            Text(keyBindings.keyCode(for: action).map { keyCodeName($0) } ?? "None")
                                .foregroundStyle(.gray)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        listeningFor = action
                    }
                }
            }
            .listStyle(.plain)

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .background(Color(white: 0.1))
    }

    private func keyCodeName(_ keyCode: UInt16) -> String {
        let names: [UInt16: String] = [
            UInt16(kVK_UpArrow): "Up",
            UInt16(kVK_DownArrow): "Down",
            UInt16(kVK_LeftArrow): "Left",
            UInt16(kVK_RightArrow): "Right",
            UInt16(kVK_Return): "Enter",
            UInt16(kVK_Delete): "Backspace",
            UInt16(kVK_Space): "Space",
            UInt16(kVK_Tab): "Tab",
            UInt16(kVK_Escape): "Esc",
            UInt16(kVK_ANSI_Z): "Z",
            UInt16(kVK_ANSI_X): "X",
            UInt16(kVK_ANSI_R): "R",
            UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
            UInt16(kVK_F5): "F5", UInt16(kVK_F7): "F7",
            UInt16(kVK_F9): "F9",
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }
}
