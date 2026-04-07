import Foundation

final class GenesisEmulator: EmulatorCore {
    private var context: OpaquePointer?
    private var videoCallback: ((UnsafePointer<UInt32>) -> Void)?
    private var audioCallback: ((Int16, Int16) -> Void)?
    private var keyState: UInt32 = 0

    var screenWidth: Int {
        guard let ctx = context else { return 320 }
        return Int(genesis_get_screen_width(ctx))
    }

    var screenHeight: Int {
        guard let ctx = context else { return 224 }
        return Int(genesis_get_screen_height(ctx))
    }

    init() {
        context = genesis_create()
        registerCallbacks()
    }

    deinit {
        if let context {
            genesis_destroy(context)
        }
    }

    func loadROM(url: URL) throws {
        guard let ctx = context else { return }
        let loaded = genesis_load_rom(ctx, url.path)
        if !loaded {
            throw NSError(domain: "CrystalBoy", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load ROM: \(url.lastPathComponent)"])
        }
    }

    func unloadROM() {
        guard let context else { return }
        genesis_destroy(context)
        self.context = genesis_create()
        keyState = 0
        registerCallbacks()
    }

    func runFrame() {
        guard let ctx = context else { return }
        genesis_run_frame(ctx)
    }

    func setInput(button: GameButton, pressed: Bool) {
        guard let ctx = context else { return }
        guard let bit = genesisBit(for: button) else { return }
        if pressed {
            keyState |= (1 << bit)
        } else {
            keyState &= ~(1 << bit)
        }
        genesis_set_keys(ctx, keyState)
    }

    func setVideoCallback(_ callback: @escaping (UnsafePointer<UInt32>) -> Void) {
        videoCallback = callback
    }

    func setAudioCallback(_ callback: @escaping (Int16, Int16) -> Void) {
        audioCallback = callback
    }

    func setSampleRate(_ rate: UInt32) {
        guard let ctx = context else { return }
        genesis_set_sample_rate(ctx, rate)
    }

    func saveBattery(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return genesis_save_battery(ctx, url.path)
    }

    func loadBattery(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return genesis_load_battery(ctx, url.path)
    }

    func saveState(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return genesis_save_state(ctx, url.path)
    }

    func loadState(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return genesis_load_state(ctx, url.path)
    }

    func setRewindLength(seconds: Double) {
        // Genesis Plus GX libretro core does not support rewind; no-op
    }

    func rewindPop() -> Bool {
        // Genesis Plus GX libretro core does not support rewind; no-op
        return false
    }

    func addCheat(code: String, description: String) {
        guard let ctx = context else { return }
        genesis_add_cheat(ctx, code, description)
    }

    func removeAllCheats() {
        guard let ctx = context else { return }
        genesis_remove_all_cheats(ctx)
    }

    // MARK: - Private

    /// Maps a GameButton to the libretro JOYPAD button ID for Genesis.
    /// Genesis A=Y(1), B=B(0), C=A(8), X=X(9), Y=L(10), Z=R(11), Start=3
    /// Up=4, Down=5, Left=6, Right=7
    /// Genesis has no Select button.
    private func genesisBit(for button: GameButton) -> UInt32? {
        switch button {
        case .a:        return 1   // Genesis A → RETRO_DEVICE_ID_JOYPAD_Y
        case .b:        return 0   // Genesis B → RETRO_DEVICE_ID_JOYPAD_B
        case .genesisC: return 8   // Genesis C → RETRO_DEVICE_ID_JOYPAD_A
        case .genesisX: return 9   // Genesis X → RETRO_DEVICE_ID_JOYPAD_X
        case .genesisY: return 10  // Genesis Y → RETRO_DEVICE_ID_JOYPAD_L
        case .genesisZ: return 11  // Genesis Z → RETRO_DEVICE_ID_JOYPAD_R
        case .start:    return 3   // RETRO_DEVICE_ID_JOYPAD_START
        case .up:       return 4   // RETRO_DEVICE_ID_JOYPAD_UP
        case .down:     return 5   // RETRO_DEVICE_ID_JOYPAD_DOWN
        case .left:     return 6   // RETRO_DEVICE_ID_JOYPAD_LEFT
        case .right:    return 7   // RETRO_DEVICE_ID_JOYPAD_RIGHT
        default:        return nil // Genesis has no Select button
        }
    }

    private func registerCallbacks() {
        guard let ctx = context else { return }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        genesis_set_user_data(ctx, selfPtr)

        genesis_set_video_callback(ctx) { userData, pixels in
            guard let userData, let pixels else { return }
            let emulator = Unmanaged<GenesisEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.videoCallback?(pixels)
        }

        genesis_set_audio_callback(ctx) { userData, left, right in
            guard let userData else { return }
            let emulator = Unmanaged<GenesisEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.audioCallback?(left, right)
        }
    }
}
