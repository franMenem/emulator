import SwiftUI
import Carbon.HIToolbox

struct ControlsSettingsView: View {
    let keyBindings: KeyBindings
    @State private var listeningFor: EmulatorAction?
    @State private var keyMonitor: Any?
    @State private var refreshID = UUID()
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
            .id(refreshID)

            HStack {
                Spacer()
                Button("Done") {
                    stopListening()
                    dismiss()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .background(Color(white: 0.1))
        .onChange(of: listeningFor) { _, action in
            if action != nil {
                startListening()
            } else {
                stopListening()
            }
        }
        .onDisappear {
            stopListening()
        }
    }

    private func startListening() {
        stopListening()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let action = listeningFor else { return event }
            keyBindings.setBinding(keyCode: event.keyCode, action: action)
            listeningFor = nil
            refreshID = UUID() // force list refresh
            return nil
        }
    }

    private func stopListening() {
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
            keyMonitor = nil
        }
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
            UInt16(kVK_ANSI_A): "A", UInt16(kVK_ANSI_B): "B",
            UInt16(kVK_ANSI_C): "C", UInt16(kVK_ANSI_D): "D",
            UInt16(kVK_ANSI_E): "E", UInt16(kVK_ANSI_F): "F",
            UInt16(kVK_ANSI_G): "G", UInt16(kVK_ANSI_H): "H",
            UInt16(kVK_ANSI_I): "I", UInt16(kVK_ANSI_J): "J",
            UInt16(kVK_ANSI_K): "K", UInt16(kVK_ANSI_L): "L",
            UInt16(kVK_ANSI_M): "M", UInt16(kVK_ANSI_N): "N",
            UInt16(kVK_ANSI_O): "O", UInt16(kVK_ANSI_P): "P",
            UInt16(kVK_ANSI_Q): "Q", UInt16(kVK_ANSI_S): "S",
            UInt16(kVK_ANSI_T): "T", UInt16(kVK_ANSI_U): "U",
            UInt16(kVK_ANSI_V): "V", UInt16(kVK_ANSI_W): "W",
            UInt16(kVK_ANSI_Y): "Y",
            UInt16(kVK_F1): "F1", UInt16(kVK_F2): "F2", UInt16(kVK_F3): "F3",
            UInt16(kVK_F4): "F4", UInt16(kVK_F5): "F5", UInt16(kVK_F6): "F6",
            UInt16(kVK_F7): "F7", UInt16(kVK_F8): "F8", UInt16(kVK_F9): "F9",
            UInt16(kVK_F10): "F10", UInt16(kVK_F11): "F11", UInt16(kVK_F12): "F12",
        ]
        return names[keyCode] ?? "Key \(keyCode)"
    }
}
