import Foundation

final class SaveManager {
    private let emulator: EmulatorCore
    private var romURL: URL?
    private var currentSlot: Int = 0
    private var autoSaveTimer: Timer?

    var onToast: ((String) -> Void)?

    init(emulator: EmulatorCore) {
        self.emulator = emulator
    }

    func setROM(url: URL) {
        romURL = url
        // Load battery save if exists
        let savURL = batteryURL
        if FileManager.default.fileExists(atPath: savURL.path) {
            _ = emulator.loadBattery(from: savURL)
        }
        startAutoSave()
    }

    // MARK: - Battery Saves (.sav)

    private var batteryURL: URL {
        guard let romURL else { fatalError("ROM not set") }
        return romURL.deletingPathExtension().appendingPathExtension("sav")
    }

    func saveBattery() {
        _ = emulator.saveBattery(to: batteryURL)
    }

    private func startAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.saveBattery()
        }
    }

    // MARK: - Save States

    private var saveStatesDir: URL {
        guard let romURL else { fatalError("ROM not set") }
        let name = romURL.deletingPathExtension().lastPathComponent
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CrystalBoy/SaveStates/\(name)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func saveState() {
        let url = saveStatesDir.appendingPathComponent("slot-\(currentSlot).state")
        if emulator.saveState(to: url) {
            onToast?("Saved Slot \(currentSlot)")
        }
        saveBattery()
    }

    func loadState() {
        let url = saveStatesDir.appendingPathComponent("slot-\(currentSlot).state")
        guard FileManager.default.fileExists(atPath: url.path) else {
            onToast?("Slot \(currentSlot) is empty")
            return
        }
        if emulator.loadState(from: url) {
            onToast?("Loaded Slot \(currentSlot)")
        }
    }

    func nextSlot() {
        currentSlot = (currentSlot + 1) % 10
        onToast?("Slot \(currentSlot)")
    }

    func prevSlot() {
        currentSlot = (currentSlot - 1 + 10) % 10
        onToast?("Slot \(currentSlot)")
    }

    func cleanup() {
        autoSaveTimer?.invalidate()
        saveBattery()
    }
}
