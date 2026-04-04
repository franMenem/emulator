import Foundation

final class SaveManager {
    private let emulator: EmulatorCore
    private weak var emuThread: EmulationThread?
    private var romURL: URL?
    private var currentSlot: Int = 0
    private var autoSaveTimer: Timer?

    var onToast: ((String) -> Void)?

    init(emulator: EmulatorCore, emuThread: EmulationThread) {
        self.emulator = emulator
        self.emuThread = emuThread
    }

    func setROM(url: URL) {
        romURL = url
        // Load battery save if exists
        if let savURL = batteryURL, FileManager.default.fileExists(atPath: savURL.path) {
            _ = emulator.loadBattery(from: savURL)
        }
        startAutoSave()
    }

    // MARK: - Battery Saves (.sav)

    private var batteryURL: URL? {
        romURL?.deletingPathExtension().appendingPathExtension("sav")
    }

    func saveBattery() {
        guard let url = batteryURL else { return }
        // Pause emulation to avoid racing with runFrame on the emu thread
        emuThread?.pause()
        _ = emulator.saveBattery(to: url)
        emuThread?.resume()
    }

    private func startAutoSave() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.saveBattery()
        }
    }

    // MARK: - Save States

    private var saveStatesDir: URL? {
        guard let romURL else { return nil }
        let name = romURL.deletingPathExtension().lastPathComponent
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("CrystalBoy/SaveStates/\(name)")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func saveState() {
        guard let dir = saveStatesDir else { return }
        let url = dir.appendingPathComponent("slot-\(currentSlot).state")
        emuThread?.pause()
        let ok = emulator.saveState(to: url)
        if let batURL = batteryURL {
            _ = emulator.saveBattery(to: batURL)
        }
        emuThread?.resume()
        if ok { onToast?("Saved Slot \(currentSlot)") }
    }

    func loadState() {
        guard let dir = saveStatesDir else { return }
        let url = dir.appendingPathComponent("slot-\(currentSlot).state")
        guard FileManager.default.fileExists(atPath: url.path) else {
            onToast?("Slot \(currentSlot) is empty")
            return
        }
        emuThread?.pause()
        let ok = emulator.loadState(from: url)
        emuThread?.resume()
        if ok { onToast?("Loaded Slot \(currentSlot)") }
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
