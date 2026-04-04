import Foundation
import QuartzCore
import os

final class EmulationThread: @unchecked Sendable {
    private var thread: Thread?
    private let emulator: EmulatorCore
    var inputManager: InputManager?

    // Thread-safe flags using os_unfair_lock
    private var _isRunning = false
    private var _isPaused = false
    private var _speedMultiplier: Float = 1.0
    private let lock = OSAllocatedUnfairLock()

    // Semaphore for synchronous pause/stop — signaled when the emu
    // thread acknowledges the flag and is no longer touching the emulator.
    private let ackSemaphore = DispatchSemaphore(value: 0)
    private var _waitingForAck = false

    private var isRunning: Bool {
        get { lock.withLock { _isRunning } }
        set { lock.withLock { _isRunning = newValue } }
    }

    private var isPaused: Bool {
        get { lock.withLock { _isPaused } }
        set { lock.withLock { _isPaused = newValue } }
    }

    private var speedMultiplier: Float {
        get { lock.withLock { _speedMultiplier } }
        set { lock.withLock { _speedMultiplier = newValue } }
    }

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

    /// Stop the emulation thread and wait for it to exit.
    func stop() {
        lock.lock()
        _isRunning = false
        _waitingForAck = true
        lock.unlock()

        // Wait for the run loop to exit (max 2s to avoid deadlock)
        _ = ackSemaphore.wait(timeout: .now() + 2.0)
        thread = nil
    }

    /// Pause emulation and block until the current frame completes.
    /// Safe to access the emulator after this returns.
    func pause() {
        lock.lock()
        guard _isRunning, !_isPaused else {
            lock.unlock()
            return
        }
        _isPaused = true
        _waitingForAck = true
        lock.unlock()

        // Wait for the emu thread to reach the pause check
        _ = ackSemaphore.wait(timeout: .now() + 2.0)
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
                signalAckIfNeeded()
                Thread.sleep(forTimeInterval: 0.01)
                continue
            }

            let frameStart = CACurrentMediaTime()
            let speed = speedMultiplier

            if inputManager?.isRewindActive == true {
                _ = emulator.rewindPop()
            } else {
                let framesToRun = max(1, Int(speed))
                for _ in 0..<framesToRun {
                    emulator.runFrame()
                }
            }

            // Throttle to real-time (skip if fast forwarding)
            if speed <= 1.0 {
                let elapsed = CACurrentMediaTime() - frameStart
                let sleepTime = targetFrameTime - elapsed
                if sleepTime > 0 {
                    Thread.sleep(forTimeInterval: sleepTime)
                }
            }
        }

        // Thread is exiting — signal stop() if it's waiting
        signalAckIfNeeded()
    }

    private func signalAckIfNeeded() {
        lock.lock()
        if _waitingForAck {
            _waitingForAck = false
            lock.unlock()
            ackSemaphore.signal()
        } else {
            lock.unlock()
        }
    }
}
