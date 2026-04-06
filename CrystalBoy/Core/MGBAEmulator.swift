import Foundation

final class MGBAEmulator: EmulatorCore {
    private var context: OpaquePointer?
    private var videoCallback: ((UnsafePointer<UInt32>) -> Void)?
    private var audioCallback: ((Int16, Int16) -> Void)?
    private var keyState: UInt32 = 0

    var screenWidth: Int {
        guard let ctx = context else { return 240 }
        return Int(mgba_get_screen_width(ctx))
    }

    var screenHeight: Int {
        guard let ctx = context else { return 160 }
        return Int(mgba_get_screen_height(ctx))
    }

    init() {
        context = mgba_create()
        registerCallbacks()
    }

    deinit {
        if let context {
            mgba_destroy(context)
        }
    }

    func loadROM(url: URL) throws {
        guard let ctx = context else { return }
        let loaded = mgba_load_rom(ctx, url.path)
        if !loaded {
            throw NSError(domain: "CrystalBoy", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load ROM: \(url.lastPathComponent)"])
        }
    }

    func unloadROM() {
        guard let context else { return }
        mgba_destroy(context)
        self.context = mgba_create()
        keyState = 0
        registerCallbacks()
    }

    func runFrame() {
        guard let ctx = context else { return }
        mgba_run_frame(ctx)
    }

    func setInput(button: GameButton, pressed: Bool) {
        guard let ctx = context else { return }
        guard let bit = gbaBit(for: button) else { return }
        if pressed {
            keyState |= (1 << bit)
        } else {
            keyState &= ~(1 << bit)
        }
        mgba_set_keys(ctx, keyState)
    }

    func setVideoCallback(_ callback: @escaping (UnsafePointer<UInt32>) -> Void) {
        videoCallback = callback
    }

    func setAudioCallback(_ callback: @escaping (Int16, Int16) -> Void) {
        audioCallback = callback
    }

    func setSampleRate(_ rate: UInt32) {
        guard let ctx = context else { return }
        mgba_set_sample_rate(ctx, rate)
    }

    func saveBattery(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return mgba_save_battery(ctx, url.path)
    }

    func loadBattery(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return mgba_load_battery(ctx, url.path)
    }

    func saveState(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return mgba_save_state(ctx, url.path)
    }

    func loadState(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return mgba_load_state(ctx, url.path)
    }

    func setRewindLength(seconds: Double) {
        // mGBA does not have built-in rewind support; no-op
    }

    func rewindPop() -> Bool {
        // mGBA does not have built-in rewind support; no-op
        return false
    }

    func addCheat(code: String, description: String) {
        guard let ctx = context else { return }
        mgba_add_cheat(ctx, code, description)
    }

    func removeAllCheats() {
        guard let ctx = context else { return }
        mgba_remove_all_cheats(ctx)
    }

    // MARK: - Private

    /// Maps a GameButton to the GBA key bitmask bit index.
    /// GBA bitmask: A=0, B=1, SELECT=2, START=3, RIGHT=4, LEFT=5, UP=6, DOWN=7, R=8, L=9
    private func gbaBit(for button: GameButton) -> UInt32? {
        switch button {
        case .a:      return 0
        case .b:      return 1
        case .select: return 2
        case .start:  return 3
        case .right:  return 4
        case .left:   return 5
        case .up:     return 6
        case .down:   return 7
        case .r:      return 8
        case .l:      return 9
        default:      return nil
        }
    }

    private func registerCallbacks() {
        guard let ctx = context else { return }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        mgba_set_user_data(ctx, selfPtr)

        mgba_set_video_callback(ctx) { userData, pixels in
            guard let userData, let pixels else { return }
            let emulator = Unmanaged<MGBAEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.videoCallback?(pixels)
        }

        mgba_set_audio_callback(ctx) { userData, left, right in
            guard let userData else { return }
            let emulator = Unmanaged<MGBAEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.audioCallback?(left, right)
        }
    }
}
