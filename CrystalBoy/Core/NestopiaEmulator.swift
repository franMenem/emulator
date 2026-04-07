import Foundation

final class NestopiaEmulator: EmulatorCore {
    private var context: OpaquePointer?
    private var videoCallback: ((UnsafePointer<UInt32>) -> Void)?
    private var audioCallback: ((Int16, Int16) -> Void)?
    private var keyState: UInt32 = 0

    var screenWidth: Int {
        guard let ctx = context else { return 256 }
        return Int(nestopia_get_screen_width(ctx))
    }

    var screenHeight: Int {
        guard let ctx = context else { return 240 }
        return Int(nestopia_get_screen_height(ctx))
    }

    init() {
        context = nestopia_create()
        registerCallbacks()
    }

    deinit {
        if let context {
            nestopia_destroy(context)
        }
    }

    func loadROM(url: URL) throws {
        guard let ctx = context else { return }
        let loaded = nestopia_load_rom(ctx, url.path)
        if !loaded {
            throw NSError(domain: "CrystalBoy", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load ROM: \(url.lastPathComponent)"])
        }
    }

    func unloadROM() {
        guard let context else { return }
        nestopia_destroy(context)
        self.context = nestopia_create()
        keyState = 0
        registerCallbacks()
    }

    func runFrame() {
        guard let ctx = context else { return }
        nestopia_run_frame(ctx)
    }

    func setInput(button: GameButton, pressed: Bool) {
        guard let ctx = context else { return }
        guard let bit = nesBit(for: button) else { return }
        if pressed {
            keyState |= (1 << bit)
        } else {
            keyState &= ~(1 << bit)
        }
        nestopia_set_keys(ctx, keyState)
    }

    func setVideoCallback(_ callback: @escaping (UnsafePointer<UInt32>) -> Void) {
        videoCallback = callback
    }

    func setAudioCallback(_ callback: @escaping (Int16, Int16) -> Void) {
        audioCallback = callback
    }

    func setSampleRate(_ rate: UInt32) {
        guard let ctx = context else { return }
        nestopia_set_sample_rate(ctx, rate)
    }

    func saveBattery(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return nestopia_save_battery(ctx, url.path)
    }

    func loadBattery(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return nestopia_load_battery(ctx, url.path)
    }

    func saveState(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return nestopia_save_state(ctx, url.path)
    }

    func loadState(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return nestopia_load_state(ctx, url.path)
    }

    func setRewindLength(seconds: Double) {
        // Nestopia libretro core does not support rewind; no-op
    }

    func rewindPop() -> Bool {
        // Nestopia libretro core does not support rewind; no-op
        return false
    }

    func addCheat(code: String, description: String) {
        guard let ctx = context else { return }
        nestopia_add_cheat(ctx, code, description)
    }

    func removeAllCheats() {
        guard let ctx = context else { return }
        nestopia_remove_all_cheats(ctx)
    }

    // MARK: - Private

    /// Maps a GameButton to the libretro JOYPAD button ID for NES.
    /// B=0, SELECT=2, START=3, UP=4, DOWN=5, LEFT=6, RIGHT=7, A=8
    private func nesBit(for button: GameButton) -> UInt32? {
        switch button {
        case .b:      return 0   // RETRO_DEVICE_ID_JOYPAD_B
        case .select: return 2   // RETRO_DEVICE_ID_JOYPAD_SELECT
        case .start:  return 3   // RETRO_DEVICE_ID_JOYPAD_START
        case .up:     return 4   // RETRO_DEVICE_ID_JOYPAD_UP
        case .down:   return 5   // RETRO_DEVICE_ID_JOYPAD_DOWN
        case .left:   return 6   // RETRO_DEVICE_ID_JOYPAD_LEFT
        case .right:  return 7   // RETRO_DEVICE_ID_JOYPAD_RIGHT
        case .a:      return 8   // RETRO_DEVICE_ID_JOYPAD_A
        default:      return nil
        }
    }

    private func registerCallbacks() {
        guard let ctx = context else { return }
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        nestopia_set_user_data(ctx, selfPtr)

        nestopia_set_video_callback(ctx) { userData, pixels in
            guard let userData, let pixels else { return }
            let emulator = Unmanaged<NestopiaEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.videoCallback?(pixels)
        }

        nestopia_set_audio_callback(ctx) { userData, left, right in
            guard let userData else { return }
            let emulator = Unmanaged<NestopiaEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.audioCallback?(left, right)
        }
    }
}
