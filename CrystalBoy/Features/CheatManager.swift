import Foundation
import Combine

struct Cheat: Codable, Identifiable {
    let id: UUID
    let code: String
    let description: String
    var enabled: Bool
}

final class CheatManager: ObservableObject {
    private let emulator: EmulatorCore
    @Published private(set) var cheats: [Cheat] = []
    @Published private(set) var cheatsEnabled = true
    private var romName: String?

    var onToast: ((String) -> Void)?

    init(emulator: EmulatorCore) {
        self.emulator = emulator
    }

    func setROM(url: URL) {
        romName = url.deletingPathExtension().lastPathComponent
        loadFromDisk()
        reapplyCheats()
    }

    func addCheat(code: String, description: String) {
        let cheat = Cheat(id: UUID(), code: code, description: description, enabled: true)
        cheats.append(cheat)
        reapplyCheats()
        saveToDisk()
    }

    func removeCheat(id: UUID) {
        cheats.removeAll { $0.id == id }
        reapplyCheats()
        saveToDisk()
    }

    func removeAllCheats() {
        cheats.removeAll()
        emulator.removeAllCheats()
        saveToDisk()
    }

    func toggleCheat(id: UUID) {
        guard let index = cheats.firstIndex(where: { $0.id == id }) else { return }
        cheats[index].enabled.toggle()
        reapplyCheats()
        saveToDisk()
    }

    func toggleCheats() {
        cheatsEnabled.toggle()
        reapplyCheats()
        onToast?(cheatsEnabled ? "Cheats ON" : "Cheats OFF")
    }

    // MARK: - Private

    private func reapplyCheats() {
        emulator.removeAllCheats()
        if cheatsEnabled {
            for cheat in cheats where cheat.enabled {
                emulator.addCheat(code: cheat.code, description: cheat.description)
            }
        }
    }

    // MARK: - Persistence

    private var cheatsFileURL: URL? {
        guard let romName else { return nil }
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CrystalBoy/Cheats")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("\(romName).json")
    }

    private func saveToDisk() {
        guard let url = cheatsFileURL else { return }
        guard let data = try? JSONEncoder().encode(cheats) else { return }
        try? data.write(to: url)
    }

    private func loadFromDisk() {
        guard let url = cheatsFileURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let loaded = try? JSONDecoder().decode([Cheat].self, from: data) else {
            cheats = []
            return
        }
        cheats = loaded
    }
}
