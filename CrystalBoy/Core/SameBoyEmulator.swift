import Foundation

final class SameBoyEmulator: EmulatorCore {
    private var context: OpaquePointer?
    private var videoCallback: (@Sendable (UnsafePointer<UInt32>) -> Void)?
    private var audioCallback: (@Sendable (Int16, Int16) -> Void)?

    var screenWidth: Int {
        guard let ctx = context else { return 160 }
        return Int(sb_get_screen_width(ctx))
    }

    var screenHeight: Int {
        guard let ctx = context else { return 144 }
        return Int(sb_get_screen_height(ctx))
    }

    init(isColorGB: Bool = true) {
        context = sb_create(isColorGB)

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        sb_set_user_data(context, selfPtr)

        sb_set_video_callback(context) { userData, pixels in
            guard let userData, let pixels else { return }
            let emulator = Unmanaged<SameBoyEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.videoCallback?(pixels)
        }

        sb_set_audio_callback(context) { userData, left, right in
            guard let userData else { return }
            let emulator = Unmanaged<SameBoyEmulator>.fromOpaque(userData).takeUnretainedValue()
            emulator.audioCallback?(left, right)
        }
    }

    deinit {
        if let context {
            sb_destroy(context)
        }
    }

    func loadROM(url: URL) throws {
        guard let ctx = context else { return }
        let loaded = sb_load_rom(ctx, url.path)
        if !loaded {
            throw NSError(domain: "CrystalBoy", code: 1,
                         userInfo: [NSLocalizedDescriptionKey: "Failed to load ROM: \(url.lastPathComponent)"])
        }

        // Try loading boot ROM if available
        if let bootROMPath = Bundle.main.path(forResource: "cgb_boot", ofType: "bin") {
            sb_load_boot_rom(ctx, bootROMPath)
        }
    }

    func unloadROM() {
        guard let context else { return }
        sb_destroy(context)
        self.context = sb_create(true)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        sb_set_user_data(self.context, selfPtr)
    }

    func runFrame() {
        guard let ctx = context else { return }
        _ = sb_run_frame(ctx)
    }

    func setInput(button: GameButton, pressed: Bool) {
        guard let ctx = context else { return }
        sb_set_key(ctx, Int32(button.rawValue), pressed)
    }

    func setVideoCallback(_ callback: @escaping @Sendable (UnsafePointer<UInt32>) -> Void) {
        videoCallback = callback
    }

    func setAudioCallback(_ callback: @escaping @Sendable (Int16, Int16) -> Void) {
        audioCallback = callback
    }

    func setSampleRate(_ rate: UInt32) {
        guard let ctx = context else { return }
        sb_set_sample_rate(ctx, rate)
    }

    func saveBattery(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return sb_save_battery(ctx, url.path)
    }

    func loadBattery(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return sb_load_battery(ctx, url.path)
    }

    func saveState(to url: URL) -> Bool {
        guard let ctx = context else { return false }
        return sb_save_state(ctx, url.path)
    }

    func loadState(from url: URL) -> Bool {
        guard let ctx = context else { return false }
        return sb_load_state(ctx, url.path)
    }

    func setRewindLength(seconds: Double) {
        guard let ctx = context else { return }
        sb_set_rewind_length(ctx, seconds)
    }

    func rewindPop() -> Bool {
        guard let ctx = context else { return false }
        return sb_rewind_pop(ctx)
    }

    func addCheat(code: String, description: String) {
        guard let ctx = context else { return }
        sb_add_cheat(ctx, code, description)
    }

    func removeAllCheats() {
        guard let ctx = context else { return }
        sb_remove_all_cheats(ctx)
    }
}
