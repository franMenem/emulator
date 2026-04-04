import Foundation

enum GameButton: Int {
    case right = 0, left, up, down, a, b, select, start
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
