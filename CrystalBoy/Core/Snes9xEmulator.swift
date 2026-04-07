import Foundation

final class Snes9xEmulator: EmulatorCore {
    private var context: OpaquePointer?
    private var videoCallback: ((UnsafePointer<UInt32>) -> Void)?
    private var audioCallback: ((Int16, Int16) -> Void)?
    private var keyState: UInt32 = 0

    var screenWidth: Int {
        guard let ctx = context else { return 256 }
        return Int(snes9x_get_screen_width(ctx))
    }

    var screenHeight: Int {
        guard let ctx = context else { return 224 }
        return Int(snes9x_get_screen_height(ctx))
    }

    init() {
        context = snes9x_create()
        registerCallbacks()
    }

    deinit {
        if let context {
            snes9x_destroy(context)
        }
    }

    func loadROM(url: URL) throws {
        guard let ctx = context else { return }
        let loaded = snes9x_load_rom(ctx, url.path)
        if !loaded {
            throw NSError(domain: "CrystalBoy", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load ROM: \(url.lastPathComponent)"])
        }
    }

    func unloadROM() {
        guard let context else { return }
        snes9x_destroy(context)
        self.context = snes9x_create()
        keyState = 0
        registerCallbacks()
    }

    func runFrame() {
        guard let ctx = context else { return }
        snes9x_run_frame(ctx)
    }

    func setInput(button: GameButton, pressed: Bool) {
        guard let ctx = context else { return }
        guard let bit = snesBit(for: button) else { return }
        if pressed {
            keyState |= (1 << bit)
        } else {
            keyState &= ~(1 << bit)
        }
        snes9x_set_keys(ctx, keyState)
    }

    func setVideoCallback(_ callback: @escaping (UnsafePointer<UInt32>) -> Void) {
        videoCallback = callback
    }

    func setAudioCallback(_ callback: @escaping (Int16, Int16) -> Void) {
        audioCallback = callback
    }

    func setSampleRate(_ rate: UInt32) {
        guard let ctx = context else { return }
        snes9x_set_sample_rate(ctx, rate)
    }

    func saveBattery(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return snes9x_save_battery(ctx, url.path)
    }

    func loadBattery(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return snes9x_load_battery(ctx, url.path)
    }

    func saveState(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return snes9x_save_state(ctx, url.path)
    }

    func loadState(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return snes9x_load_state(ctx, url.path)
    }

    func setRewindLength(seconds: Double) {
        // snes9x libretro core does not support rewind; no-op
    }

    func rewindPop() -> Bool {
        // snes9x libretro core does not support rewind; no-op
        return false
    }

    func addCheat(code: String, description: String) {
        guard let ctx = context else { return }
        snes9x_add_cheat(ctx, code, description)
    }

    func removeAllCheats() {
        guard let ctx = context else { return }
        snes9x_remove_all_cheats(ctx)
    }

    // MARK: - Private

    /// Maps a GameButton to the libretro JOYPAD button ID for SNES.
    /// B=0, Y=1, SELECT=2, START=3, UP=4, DOWN=5, LEFT=6, RIGHT=7, A=8, X=9, L=10, R=11
    private func snesBit(for button: GameButton) -> UInt32? {
        switch button {
        case .b:      return 0   // RETRO_DEVICE_ID_JOYPAD_B
        case .y:      return 1   // RETRO_DEVICE_ID_JOYPAD_Y
        case .select: return 2   // RETRO_DEVICE_ID_JOYPAD_SELECT
        case .start:  return 3   // RETRO_DEVICE_ID_JOYPAD_START
        case .up:     return 4   // RETRO_DEVICE_ID_JOYPAD_UP
        case .down:   return 5   // RETRO_DEVICE_ID_JOYPAD_DOWN
        case .left:   return 6   // RETRO_DEVICE_ID_JOYPAD_LEFT
        case .right:  return 7   // RETRO_DEVICE_ID_JOYPAD_RIGHT
        case .a:      return 8   // RETRO_DEVICE_ID_JOYPAD_A
        case .x:      return 9   // RETRO_DEVICE_ID_JOYPAD_X
        case .l:      return 10  // RETRO_DEVICE_ID_JOYPAD_L
        case .r:      return 11  // RETRO_DEVICE_ID_JOYPAD_R
        default:      return nil
        }
    }

    private func registerCallbacks() {
        guard let ctx = context else { return }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        snes9x_set_user_data(ctx, selfPtr)

        snes9x_set_video_callback(ctx) { userData, pixels in
            guard let userData, let pixels else { return }
            let emulator = Unmanaged<Snes9xEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.videoCallback?(pixels)
        }

        snes9x_set_audio_callback(ctx) { userData, left, right in
            guard let userData else { return }
            let emulator = Unmanaged<Snes9xEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.audioCallback?(left, right)
        }
    }
}
