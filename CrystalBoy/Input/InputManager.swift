import GameController
import Cocoa

final class InputManager {
    let keyBindings = KeyBindings()
    private let emulator: EmulatorCore
    private var emuThread: EmulationThread?

    // Callbacks for emulator-level actions
    var onSaveState: (() -> Void)?
    var onLoadState: (() -> Void)?
    var onPrevSlot: (() -> Void)?
    var onNextSlot: (() -> Void)?
    var onToggleCheats: (() -> Void)?
    var onPause: (() -> Void)?
    var onBackToLibrary: (() -> Void)?
    var onSpeedChange: ((Float) -> Void)?
    var onShowHelp: ((Bool) -> Void)?

    // Speed: 5% increments, range 25%-400%
    private var currentSpeed: Float = 1.0

    // Hold-state tracking for rewind/fast forward
    private(set) var isRewindActive = false
    private var isFastForwarding = false

    var audioEngine: AudioEngine?

    private var controllerObserver: NSObjectProtocol?

    init(emulator: EmulatorCore, emuThread: EmulationThread?) {
        self.emulator = emulator
        self.emuThread = emuThread
        setupGamepad()
    }

    deinit {
        if let obs = controllerObserver {
            NotificationCenter.default.removeObserver(obs)
        }
    }

    func setEmuThread(_ thread: EmulationThread) {
        self.emuThread = thread
    }

    func handleKeyDown(event: NSEvent) -> Bool {
        guard !event.isARepeat else { return true }
        guard let action = keyBindings.action(for: event.keyCode) else { return false }
        performAction(action, pressed: true)
        return true
    }

    func handleKeyUp(event: NSEvent) -> Bool {
        guard let action = keyBindings.action(for: event.keyCode) else { return false }
        performAction(action, pressed: false)
        return true
    }

    private func performAction(_ action: EmulatorAction, pressed: Bool) {
        // Game buttons
        if let button = action.gameButton {
            emulator.setInput(button: button, pressed: pressed)
            return
        }

        // Emulator actions (trigger on press only, except hold actions)
        switch action {
        case .rewind:
            isRewindActive = pressed
        case .fastForward:
            isFastForwarding = pressed
            if pressed {
                emuThread?.setSpeed(4.0)
                audioEngine?.setMuted(true)
            } else {
                emuThread?.setSpeed(currentSpeed)
                audioEngine?.setMuted(currentSpeed != 1.0)
            }
        case .saveState:
            if pressed { onSaveState?() }
        case .loadState:
            if pressed { onLoadState?() }
        case .prevSlot:
            if pressed { onPrevSlot?() }
        case .nextSlot:
            if pressed { onNextSlot?() }
        case .toggleCheats:
            if pressed { onToggleCheats?() }
        case .speedUp:
            if pressed { changeSpeed(delta: 1) }
        case .speedDown:
            if pressed { changeSpeed(delta: -1) }
        case .speedReset:
            if pressed { applySpeed(1.0) }
        case .showHelp:
            onShowHelp?(pressed)
        case .pause:
            if pressed { onPause?() }
        case .backToLibrary:
            if pressed { onBackToLibrary?() }
        default:
            break
        }
    }

    private func changeSpeed(delta: Int) {
        let step: Float = 0.05 // 5%
        let newSpeed = currentSpeed + Float(delta) * step
        applySpeed(max(0.25, min(4.0, newSpeed)))
    }

    private func applySpeed(_ speed: Float) {
        // Round to nearest 5%
        currentSpeed = (speed * 20).rounded() / 20
        emuThread?.setSpeed(currentSpeed)
        audioEngine?.setMuted(currentSpeed != 1.0)
        onSpeedChange?(currentSpeed)
    }

    /// Called when the toolbar slider changes speed directly
    func setSpeedFromSlider(_ speed: Float) {
        currentSpeed = (speed * 20).rounded() / 20
    }

    // MARK: - Gamepad

    private func setupGamepad() {
        controllerObserver = NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] notification in
            if let controller = notification.object as? GCController {
                self?.configureGamepad(controller)
            }
        }

        // Configure already-connected controllers
        for controller in GCController.controllers() {
            configureGamepad(controller)
        }
    }

    private func configureGamepad(_ controller: GCController) {
        guard let gamepad = controller.extendedGamepad else { return }

        gamepad.dpad.up.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .up, pressed: pressed)
        }
        gamepad.dpad.down.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .down, pressed: pressed)
        }
        gamepad.dpad.left.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .left, pressed: pressed)
        }
        gamepad.dpad.right.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .right, pressed: pressed)
        }
        gamepad.buttonA.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .a, pressed: pressed)
        }
        gamepad.buttonB.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .b, pressed: pressed)
        }
        gamepad.buttonMenu.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .start, pressed: pressed)
        }
        gamepad.buttonOptions?.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.emulator.setInput(button: .select, pressed: pressed)
        }
        gamepad.leftShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.performAction(.rewind, pressed: pressed)
        }
        gamepad.rightShoulder.pressedChangedHandler = { [weak self] _, _, pressed in
            self?.performAction(.fastForward, pressed: pressed)
        }
        gamepad.leftTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.onSaveState?() }
        }
        gamepad.rightTrigger.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.onLoadState?() }
        }
        gamepad.buttonY.pressedChangedHandler = { [weak self] _, _, pressed in
            if pressed { self?.onToggleCheats?() }
        }
    }
}
