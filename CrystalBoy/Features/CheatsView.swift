import SwiftUI

struct CheatsView: View {
    @ObservedObject var cheatManager: CheatManager
    @State private var newCode = ""
    @State private var newDescription = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Cheats")
                    .font(.title2.bold())
                Spacer()
                if !cheatManager.cheats.isEmpty {
                    Button("Remove All") {
                        cheatManager.removeAllCheats()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red)
                    .font(.caption)
                }
            }
            .padding()

            Divider()

            // Cheat list
            if cheatManager.cheats.isEmpty {
                Spacer()
                Text("No cheats added")
                    .foregroundStyle(.gray)
                Text("Add Game Genie or GameShark codes below")
                    .font(.caption)
                    .foregroundStyle(.gray.opacity(0.7))
                Spacer()
            } else {
                List {
                    ForEach(cheatManager.cheats) { cheat in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cheat.code)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.white)
                                if !cheat.description.isEmpty {
                                    Text(cheat.description)
                                        .font(.caption)
                                        .foregroundStyle(.gray)
                                }
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { cheat.enabled },
                                set: { _ in cheatManager.toggleCheat(id: cheat.id) }
                            ))
                            .toggleStyle(.switch)
                            .labelsHidden()

                            Button {
                                cheatManager.removeCheat(id: cheat.id)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundStyle(.red.opacity(0.7))
                            }
                            .buttonStyle(.plain)
                        }
                        .listRowBackground(Color(white: 0.12))
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            Divider()

            // Add cheat form
            HStack(spacing: 8) {
                TextField("Code", text: $newCode)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .padding(6)
                    .background(Color(white: 0.15))
                    .cornerRadius(4)
                    .frame(minWidth: 140)

                TextField("Description (optional)", text: $newDescription)
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background(Color(white: 0.15))
                    .cornerRadius(4)

                Button("Add") {
                    let code = newCode.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !code.isEmpty else { return }
                    cheatManager.addCheat(code: code, description: newDescription.trimmingCharacters(in: .whitespacesAndNewlines))
                    newCode = ""
                    newDescription = ""
                }
                .buttonStyle(.bordered)
                .disabled(newCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            Divider()

            // Footer
            HStack {
                Text("Global toggle: F9")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 450)
    }
}
