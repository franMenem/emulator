import SwiftUI

struct LibraryView: View {
    @ObservedObject var library: LibraryManager
    var onSelectROM: (ROMItem) -> Void
    var onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("CrystalBoy")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Button {
                    onOpenSettings()
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.gray)
                .help("Controls Settings")

                Button("Select Folder") {
                    library.selectFolder()
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(white: 0.1))

            // ROM list
            if library.roms.isEmpty {
                Spacer()
                if library.folderURL == nil {
                    Text("Select a folder with your ROMs")
                        .foregroundStyle(.gray)
                } else {
                    Text("No .gb or .gbc files found")
                        .foregroundStyle(.gray)
                }
                Spacer()
            } else {
                List(library.roms) { rom in
                    HStack {
                        Text(rom.isColor ? "GBC" : "GB")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rom.isColor ? Color.purple : Color.gray)
                            .cornerRadius(4)
                        Text(rom.name)
                            .foregroundStyle(.white)
                        Spacer()
                        if hasSaveFile(for: rom) {
                            Text("SAV")
                                .font(.caption2)
                                .foregroundStyle(.green)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(3)
                        }
                    }
                    .listRowBackground(Color(white: 0.12))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onSelectROM(rom)
                    }
                    .contextMenu {
                        Button("Play") { onSelectROM(rom) }
                        Divider()
                        Button("Import Save (.sav)...") {
                            library.importSave(for: rom)
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            // Footer hint
            HStack {
                Text("Double-click to play  |  Hold H in-game for controls")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color(white: 0.1))
        }
        .background(Color(white: 0.08))
    }

    private func hasSaveFile(for rom: ROMItem) -> Bool {
        let savURL = rom.url.deletingPathExtension().appendingPathExtension("sav")
        return FileManager.default.fileExists(atPath: savURL.path)
    }
}
