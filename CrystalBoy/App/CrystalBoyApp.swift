import SwiftUI

@main
struct CrystalBoyApp: App {
    @State private var gameNSView = GameNSView(frame: .zero)
    @State private var emulator: SameBoyEmulator?
    @State private var emuThread: EmulationThread?

    var body: some Scene {
        Window("CrystalBoy", id: "main") {
            GameView(gameNSView: gameNSView)
                .frame(minWidth: 320, minHeight: 288)
                .background(Color.black)
                .onAppear { bootTestROM() }
        }
        .defaultSize(width: 480, height: 432)
    }

    private func bootTestROM() {
        let emu = SameBoyEmulator(isColorGB: true)

        emu.setVideoCallback { [gameNSView] pixels in
            gameNSView.updateFrame(pixels: pixels)
        }

        // Hardcode ROM path for testing
        let romPath = "/Users/efmenem/Library/Containers/org.agiapplications.Game-Emulator/Data/Documents/ROMs/Pokemon - Crystal Version (USA, Europe) (Rev 1).gbc"

        do {
            try emu.loadROM(url: URL(fileURLWithPath: romPath))
        } catch {
            print("Failed to load ROM: \(error)")
            return
        }

        let thread = EmulationThread(emulator: emu)
        thread.start()

        self.emulator = emu
        self.emuThread = thread
    }
}
