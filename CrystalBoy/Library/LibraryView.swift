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

            // Filter pills
            if !library.availableConsoleTypes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        filterPill(label: "All", isActive: library.selectedFilter == nil) {
                            library.selectedFilter = nil
                        }
                        ForEach(library.availableConsoleTypes, id: \.self) { console in
                            filterPill(
                                label: console.displayName,
                                isActive: library.selectedFilter == console
                            ) {
                                library.selectedFilter = console
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color(white: 0.1))
            }

            // ROM list
            if library.filteredROMs.isEmpty {
                Spacer()
                if library.folderURL == nil {
                    Text("Select a folder with your ROMs")
                        .foregroundStyle(.gray)
                } else if library.selectedFilter != nil {
                    Text("No \(library.selectedFilter!.displayName) ROMs found")
                        .foregroundStyle(.gray)
                } else {
                    Text("No ROMs found")
                        .foregroundStyle(.gray)
                }
                Spacer()
            } else {
                List(library.filteredROMs) { rom in
                    HStack {
                        Text(rom.consoleType.displayName)
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rom.consoleType.badgeColor)
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

    private func filterPill(label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(isActive ? .black : .gray)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isActive ? Color.white : Color(white: 0.2))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func hasSaveFile(for rom: ROMItem) -> Bool {
        let savURL = rom.url.deletingPathExtension().appendingPathExtension("sav")
        return FileManager.default.fileExists(atPath: savURL.path)
    }
}
