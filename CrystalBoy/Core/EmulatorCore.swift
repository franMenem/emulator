import Foundation

enum GameButton: Int, CaseIterable {
    // Shared (all consoles)
    case right = 0, left, up, down, a, b, select, start
    // GBA / SNES / Genesis shoulder buttons
    case l, r
    // SNES face buttons
    case x, y
    // Genesis 6-button extras
    case genesisC, genesisX, genesisY, genesisZ

    /// Buttons used by a given console type
    static func buttons(for console: ConsoleType) -> [GameButton] {
        switch console {
        case .gb, .gbc:
            return [.up, .down, .left, .right, .a, .b, .select, .start]
        case .gba:
            return [.up, .down, .left, .right, .a, .b, .l, .r, .select, .start]
        case .nes:
            return [.up, .down, .left, .right, .a, .b, .select, .start]
        case .snes:
            return [.up, .down, .left, .right, .a, .b, .x, .y, .l, .r, .select, .start]
        case .genesis:
            return [.up, .down, .left, .right, .a, .b, .genesisC, .genesisX, .genesisY, .genesisZ, .start]
        }
    }
}

protocol EmulatorCore: AnyObject {
    var screenWidth: Int { get }
    var screenHeight: Int { get }

    func loadROM(url: URL) throws
    func unloadROM()

    func runFrame()

    func setInput(button: GameButton, pressed: Bool)

    func setVideoCallback(_ callback: @escaping (UnsafePointer<UInt32>) -> Void)
    func setAudioCallback(_ callback: @escaping (Int16, Int16) -> Void)
    func setSampleRate(_ rate: UInt32)

    func saveBattery(to url: URL) -> Bool
    func loadBattery(from url: URL) -> Bool

    func saveState(to url: URL) -> Bool
    func loadState(from url: URL) -> Bool

    func setRewindLength(seconds: Double)
    func rewindPop() -> Bool

    func addCheat(code: String, description: String)
    func removeAllCheats()
}
