import Foundation
import QuartzCore

final class EmulationThread {
    private var thread: Thread?
    private var isRunning = false
    private var isPaused = false
    private let emulator: EmulatorCore
    private var speedMultiplier: Float = 1.0
    var inputManager: InputManager?

    init(emulator: EmulatorCore) {
        self.emulator = emulator
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        isPaused = false
        thread = Thread { [weak self] in
            self?.runLoop()
        }
        thread?.name = "com.crystalboy.emulation"
        thread?.qualityOfService = .userInteractive
        thread?.start()
    }

    func stop() {
        isRunning = false
        thread = nil
    }

    func pause() {
        isPaused = true
    }

    func resume() {
        isPaused = false
    }

    func setSpeed(_ multiplier: Float) {
        speedMultiplier = multiplier
    }

    private func runLoop() {
        let targetFrameTime: TimeInterval = 1.0 / 59.7275 // GB frame rate

        while isRunning {
            if isPaused {
                Thread.sleep(forTimeInterval: 0.01)
                continue
            }

            let frameStart = CACurrentMediaTime()

            if inputManager?.isRewindActive == true {
                _ = emulator.rewindPop()
            } else {
                let framesToRun = max(1, Int(speedMultiplier))
                for _ in 0..<framesToRun {
                    emulator.runFrame()
                }
            }

            // Throttle to real-time (skip if fast forwarding)
            if speedMultiplier <= 1.0 {
                let elapsed = CACurrentMediaTime() - frameStart
                let sleepTime = targetFrameTime - elapsed
                if sleepTime > 0 {
                    Thread.sleep(forTimeInterval: sleepTime)
                }
            }
        }
    }
}
