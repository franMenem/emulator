import SwiftUI

struct LibraryView: View {
    @ObservedObject var library: LibraryManager
    var onSelectROM: (ROMItem) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("CrystalBoy")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
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
                    }
                    .listRowBackground(Color(white: 0.12))
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onSelectROM(rom)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color(white: 0.08))
    }
}
