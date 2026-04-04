import Foundation

struct Cheat: Codable, Identifiable {
    let id: UUID
    let code: String
    let description: String
    var enabled: Bool
}

final class CheatManager {
    private let emulator: EmulatorCore
    private(set) var cheats: [Cheat] = []
    private var cheatsEnabled = true

    var onToast: ((String) -> Void)?

    init(emulator: EmulatorCore) {
        self.emulator = emulator
    }

    func addCheat(code: String, description: String) {
        let cheat = Cheat(id: UUID(), code: code, description: description, enabled: true)
        cheats.append(cheat)
        reapplyCheats()
    }

    func toggleCheats() {
        cheatsEnabled.toggle()
        reapplyCheats()
        onToast?(cheatsEnabled ? "Cheats ON" : "Cheats OFF")
    }

    private func reapplyCheats() {
        emulator.removeAllCheats()
        if cheatsEnabled {
            for cheat in cheats where cheat.enabled {
                emulator.addCheat(code: cheat.code, description: cheat.description)
            }
        }
    }
}
