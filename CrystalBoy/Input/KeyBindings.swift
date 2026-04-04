import Carbon.HIToolbox

enum ActionCategory: String, CaseIterable {
    case gameButtons = "Game Buttons"
    case saveLoad = "Save & Load"
    case speed = "Speed"
    case emulator = "Emulator"
}

enum EmulatorAction: String, CaseIterable, Codable {
    // Game buttons
    case up, down, left, right, a, b, start, select
    // Save/Load
    case saveState, loadState, prevSlot, nextSlot
    // Speed
    case rewind, fastForward, speedUp, speedDown, speedReset
    // Emulator
    case pause, toggleCheats, backToLibrary

    var category: ActionCategory {
        switch self {
        case .up, .down, .left, .right, .a, .b, .start, .select:
            return .gameButtons
        case .saveState, .loadState, .prevSlot, .nextSlot:
            return .saveLoad
        case .rewind, .fastForward, .speedUp, .speedDown, .speedReset:
            return .speed
        case .pause, .toggleCheats, .backToLibrary:
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
        case .backToLibrary: return "Back to Library"
        }
    }

    static func actions(for category: ActionCategory) -> [EmulatorAction] {
        allCases.filter { $0.category == category }
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
