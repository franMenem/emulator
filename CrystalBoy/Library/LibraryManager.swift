import Foundation
import AppKit

struct ROMItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let isColor: Bool // .gbc vs .gb

    init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.isColor = url.pathExtension.lowercased() == "gbc"
    }
}

final class LibraryManager: ObservableObject {
    @Published var roms: [ROMItem] = []
    @Published var folderURL: URL?

    private let defaultsKey = "CrystalBoy.ROMFolder"

    init() {
        if let bookmark = UserDefaults.standard.data(forKey: defaultsKey) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale) {
                _ = url.startAccessingSecurityScopedResource()
                folderURL = url
                scan()
            }
        }
    }

    func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select your ROMs folder"

        if panel.runModal() == .OK, let url = panel.url {
            let bookmark = try? url.bookmarkData(options: .withSecurityScope)
            UserDefaults.standard.set(bookmark, forKey: defaultsKey)
            _ = url.startAccessingSecurityScopedResource()
            folderURL = url
            scan()
        }
    }

    func scan() {
        guard let folderURL else { return }
        let fileManager = FileManager.default
        guard let contents = try? fileManager.contentsOfDirectory(
            at: folderURL, includingPropertiesForKeys: nil
        ) else { return }

        roms = contents
            .filter { ["gb", "gbc"].contains($0.pathExtension.lowercased()) }
            .map { ROMItem(url: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
