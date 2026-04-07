import Carbon.HIToolbox

enum ActionCategory: String, CaseIterable {
    case gameButtons = "Game Buttons"
    case saveLoad = "Save & Load"
    case speed = "Speed"
    case volume = "Volume"
    case emulator = "Emulator"
}

enum EmulatorAction: String, CaseIterable, Codable {
    // Game buttons — shared
    case up, down, left, right, a, b, start, select
    // Game buttons — GBA/SNES
    case buttonL, buttonR
    // Game buttons — SNES
    case buttonX, buttonY
    // Game buttons — Genesis
    case genesisC, genesisX, genesisY, genesisZ
    // Save/Load
    case saveState, loadState, prevSlot, nextSlot
    // Speed
    case rewind, fastForward, speedUp, speedDown, speedReset
    // Volume
    case volumeUp, volumeDown, mute
    // Emulator
    case pause, toggleCheats, showHelp, backToLibrary

    var category: ActionCategory {
        switch self {
        case .up, .down, .left, .right, .a, .b, .start, .select,
             .buttonL, .buttonR, .buttonX, .buttonY,
             .genesisC, .genesisX, .genesisY, .genesisZ:
            return .gameButtons
        case .saveState, .loadState, .prevSlot, .nextSlot:
            return .saveLoad
        case .rewind, .fastForward, .speedUp, .speedDown, .speedReset:
            return .speed
        case .volumeUp, .volumeDown, .mute:
            return .volume
        case .pause, .toggleCheats, .showHelp, .backToLibrary:
            return .emulator
        }
    }

    var gameButton: GameButton? {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .a: return .a
        case .b: return .b
        case .start: return .start
        case .select: return .select
        case .buttonL: return .l
        case .buttonR: return .r
        case .buttonX: return .x
        case .buttonY: return .y
        case .genesisC: return .genesisC
        case .genesisX: return .genesisX
        case .genesisY: return .genesisY
        case .genesisZ: return .genesisZ
        default: return nil
        }
    }

    var defaultKeyCode: UInt16 {
        switch self {
        case .up: return UInt16(kVK_UpArrow)
        case .down: return UInt16(kVK_DownArrow)
        case .left: return UInt16(kVK_LeftArrow)
        case .right: return UInt16(kVK_RightArrow)
        case .a: return UInt16(kVK_ANSI_Z)
        case .b: return UInt16(kVK_ANSI_X)
        case .start: return UInt16(kVK_Return)
        case .select: return UInt16(kVK_Delete)
        case .rewind: return UInt16(kVK_ANSI_R)
        case .fastForward: return UInt16(kVK_Tab)
        case .speedUp: return UInt16(kVK_ANSI_Equal)       // +/=
        case .speedDown: return UInt16(kVK_ANSI_Minus)      // -
        case .speedReset: return UInt16(kVK_ANSI_0)         // 0
        case .saveState: return UInt16(kVK_F5)
        case .loadState: return UInt16(kVK_F7)
        case .prevSlot: return UInt16(kVK_F2)
        case .nextSlot: return UInt16(kVK_F3)
        case .toggleCheats: return UInt16(kVK_F9)
        case .pause: return UInt16(kVK_Space)
        case .showHelp: return UInt16(kVK_ANSI_H)
        case .buttonL: return UInt16(kVK_ANSI_A)
        case .buttonR: return UInt16(kVK_ANSI_S)
        case .buttonX: return UInt16(kVK_ANSI_D)
        case .buttonY: return UInt16(kVK_ANSI_C)
        case .genesisC: return UInt16(kVK_ANSI_F)
        case .genesisX: return UInt16(kVK_ANSI_G)
        case .genesisY: return UInt16(kVK_ANSI_V)
        case .genesisZ: return UInt16(kVK_ANSI_B)
        case .volumeUp: return UInt16(kVK_ANSI_RightBracket)
        case .volumeDown: return UInt16(kVK_ANSI_LeftBracket)
        case .mute: return UInt16(kVK_ANSI_M)
        case .backToLibrary: return UInt16(kVK_Escape)
        }
    }

    var displayName: String {
        switch self {
        case .up: return "D-Pad Up"
        case .down: return "D-Pad Down"
        case .left: return "D-Pad Left"
        case .right: return "D-Pad Right"
        case .a: return "Button A"
        case .b: return "Button B"
        case .start: return "Start"
        case .select: return "Select"
        case .saveState: return "Save State"
        case .loadState: return "Load State"
        case .prevSlot: return "Previous Slot"
        case .nextSlot: return "Next Slot"
        case .rewind: return "Rewind (hold)"
        case .fastForward: return "Fast Forward (hold)"
        case .speedUp: return "Speed Up"
        case .speedDown: return "Speed Down"
        case .speedReset: return "Reset Speed (1x)"
        case .pause: return "Pause"
        case .toggleCheats: return "Toggle Cheats"
        case .showHelp: return "Show Controls (hold)"
        case .buttonL: return "Button L"
        case .buttonR: return "Button R"
        case .buttonX: return "Button X"
        case .buttonY: return "Button Y"
        case .genesisC: return "Button C"
        case .genesisX: return "Button X"
        case .genesisY: return "Button Y"
        case .genesisZ: return "Button Z"
        case .volumeUp: return "Volume Up"
        case .volumeDown: return "Volume Down"
        case .mute: return "Mute"
        case .backToLibrary: return "Back to Library"
        }
    }

    static func actions(for category: ActionCategory) -> [EmulatorAction] {
        allCases.filter { $0.category == category }
    }

    static func actions(for console: ConsoleType, category: ActionCategory) -> [EmulatorAction] {
        let all = actions(for: category)
        guard category == .gameButtons else { return all }
        let consoleButtons = GameButton.buttons(for: console)
        return all.filter { action in
            guard let button = action.gameButton else { return false }
            return consoleButtons.contains(button)
        }
    }

    var defaultKeyName: String {
        switch self {
        case .up: return "Up"
        case .down: return "Down"
        case .left: return "Left"
        case .right: return "Right"
        case .a: return "Z"
        case .b: return "X"
        case .start: return "Enter"
        case .select: return "Bksp"
        case .saveState: return "F5"
        case .loadState: return "F7"
        case .prevSlot: return "F2"
        case .nextSlot: return "F3"
        case .rewind: return "R"
        case .fastForward: return "Tab"
        case .speedUp: return "+"
        case .speedDown: return "-"
        case .speedReset: return "0"
        case .pause: return "Space"
        case .toggleCheats: return "F9"
        case .showHelp: return "H"
        case .buttonL: return "A"
        case .buttonR: return "S"
        case .buttonX: return "D"
        case .buttonY: return "C"
        case .genesisC: return "F"
        case .genesisX: return "G"
        case .genesisY: return "V"
        case .genesisZ: return "B"
        case .volumeUp: return "]"
        case .volumeDown: return "["
        case .mute: return "M"
        case .backToLibrary: return "Esc"
        }
    }
}

final class KeyBindings {
    private let defaultsKey = "CrystalBoy.KeyBindings"
    private var bindings: [UInt16: EmulatorAction]

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let saved = try? JSONDecoder().decode([String: String].self, from: data) {
            var map: [UInt16: EmulatorAction] = [:]
            for (keyStr, actionStr) in saved {
                if let key = UInt16(keyStr), let action = EmulatorAction(rawValue: actionStr) {
                    map[key] = action
                }
            }
            bindings = map
        } else {
            bindings = Self.defaultBindings()
        }
    }

    func action(for keyCode: UInt16) -> EmulatorAction? {
        bindings[keyCode]
    }

    func setBinding(keyCode: UInt16, action: EmulatorAction) {
        bindings = bindings.filter { $0.value != action }
        bindings[keyCode] = action
        save()
    }

    func keyCode(for action: EmulatorAction) -> UInt16? {
        bindings.first(where: { $0.value == action })?.key
    }

    func resetToDefaults() {
        bindings = Self.defaultBindings()
        save()
    }

    private func save() {
        var dict: [String: String] = [:]
        for (key, action) in bindings {
            dict[String(key)] = action.rawValue
        }
        if let data = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    private static func defaultBindings() -> [UInt16: EmulatorAction] {
        var map: [UInt16: EmulatorAction] = [:]
        for action in EmulatorAction.allCases {
            map[action.defaultKeyCode] = action
        }
        return map
    }
}
