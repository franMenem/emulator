import Foundation
import AppKit

struct ROMItem: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let consoleType: ConsoleType

    init(url: URL) {
        self.url = url
        self.name = url.deletingPathExtension().lastPathComponent
        self.consoleType = ConsoleType.from(extension: url.pathExtension) ?? .gb
    }

    /// Convenience for backward compat — true if GBC
    var isColor: Bool { consoleType == .gbc }
}

final class LibraryManager: ObservableObject {
    @Published var roms: [ROMItem] = []
    @Published var folderURL: URL?
    @Published var selectedFilter: ConsoleType?

    private let defaultsKey = "CrystalBoy.ROMFolder"
    private var accessedURL: URL?

    init() {
        if let bookmark = UserDefaults.standard.data(forKey: defaultsKey) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, bookmarkDataIsStale: &isStale) {
                startAccess(url)
                folderURL = url
                // Refresh stale bookmark
                if isStale {
                    if let fresh = try? url.bookmarkData(options: .withSecurityScope) {
                        UserDefaults.standard.set(fresh, forKey: defaultsKey)
                    }
                }
                scan()
            }
        }
    }

    deinit {
        accessedURL?.stopAccessingSecurityScopedResource()
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
            startAccess(url)
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

        // Only scan extensions for cores that are actually available
        roms = contents
            .filter { ConsoleType.availableExtensions.contains($0.pathExtension.lowercased()) }
            .map { ROMItem(url: $0) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var filteredROMs: [ROMItem] {
        guard let filter = selectedFilter else { return roms }
        return roms.filter { $0.consoleType == filter }
    }

    /// Console types that have at least one ROM
    var availableConsoleTypes: [ConsoleType] {
        let types = Set(roms.map { $0.consoleType })
        return ConsoleType.allCases.filter { types.contains($0) }
    }

    /// Import a .sav file for a given ROM. Copies it next to the ROM with matching name.
    func importSave(for rom: ROMItem) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.data]
        panel.allowsOtherFileTypes = true
        panel.message = "Select the .sav file for \(rom.name)"

        if panel.runModal() == .OK, let sourceURL = panel.url {
            let destURL = rom.url.deletingPathExtension().appendingPathExtension("sav")
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    // Backup existing save
                    let backupURL = destURL.appendingPathExtension("backup")
                    try? FileManager.default.removeItem(at: backupURL)
                    try FileManager.default.moveItem(at: destURL, to: backupURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
            } catch {
                print("Failed to import save: \(error)")
            }
        }
    }

    private func startAccess(_ url: URL) {
        accessedURL?.stopAccessingSecurityScopedResource()
        _ = url.startAccessingSecurityScopedResource()
        accessedURL = url
    }
}
