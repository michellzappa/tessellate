import Carbon.HIToolbox
import SwiftUI

/// The single human-readable representation of a saved shortcut.
///
/// Command bindings are stored as hardware key codes because the global event
/// tap matches hardware events. Keeping the display conversion beside that
/// model lets Settings and the menu bar show the exact same binding.
enum ShortcutDisplay {
    static func string(for binding: CommandBinding) -> String {
        var parts: [String] = []
        if binding.modifiers & UInt(controlKey) != 0 { parts.append("⌃") }
        if binding.modifiers & UInt(optionKey) != 0 { parts.append("⌥") }
        if binding.modifiers & UInt(shiftKey) != 0 { parts.append("⇧") }
        if binding.modifiers & UInt(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyName(binding.keyCode))
        return parts.joined()
    }

    /// Converts the stored hardware binding to SwiftUI's native menu shortcut
    /// representation. Returning nil for an unsupported key leaves the menu
    /// item without a misleading native shortcut.
    static func keyboardShortcut(for binding: CommandBinding?) -> KeyboardShortcut? {
        guard let binding, let key = keyEquivalent(for: binding.keyCode) else { return nil }
        return KeyboardShortcut(key, modifiers: eventModifiers(for: binding.modifiers))
    }

    private static func keyEquivalent(for keyCode: UInt16) -> KeyEquivalent? {
        switch Int(keyCode) {
        case kVK_Space: return .space
        case kVK_Return: return .return
        case kVK_Tab: return .tab
        case kVK_Delete: return .delete
        case kVK_ForwardDelete: return .deleteForward
        case kVK_Escape: return .escape
        case kVK_LeftArrow: return .leftArrow
        case kVK_RightArrow: return .rightArrow
        case kVK_UpArrow: return .upArrow
        case kVK_DownArrow: return .downArrow
        case kVK_Home: return .home
        case kVK_End: return .end
        case kVK_PageUp: return .pageUp
        case kVK_PageDown: return .pageDown
        case 122: return functionKeyEquivalent(1)
        case 120: return functionKeyEquivalent(2)
        case 99: return functionKeyEquivalent(3)
        case 118: return functionKeyEquivalent(4)
        case 96: return functionKeyEquivalent(5)
        case 97: return functionKeyEquivalent(6)
        case 98: return functionKeyEquivalent(7)
        case 100: return functionKeyEquivalent(8)
        case 101: return functionKeyEquivalent(9)
        case 109: return functionKeyEquivalent(10)
        case 103: return functionKeyEquivalent(11)
        case 111: return functionKeyEquivalent(12)
        default:
            guard let character = characterKey(for: keyCode) else { return nil }
            return KeyEquivalent(Character(character))
        }
    }

    private static func functionKeyEquivalent(_ number: UInt32) -> KeyEquivalent {
        // AppKit's function-key characters are in the private-use range.
        KeyEquivalent(Character(UnicodeScalar(0xF703 + number)!))
    }

    private static func eventModifiers(for modifiers: UInt) -> SwiftUI.EventModifiers {
        var result: SwiftUI.EventModifiers = []
        if modifiers & UInt(cmdKey) != 0 { result.insert(.command) }
        if modifiers & UInt(optionKey) != 0 { result.insert(.option) }
        if modifiers & UInt(controlKey) != 0 { result.insert(.control) }
        if modifiers & UInt(shiftKey) != 0 { result.insert(.shift) }
        return result
    }

    private static func characterKey(for keyCode: UInt16) -> String? {
        let map: [UInt16: String] = [
            0: "a", 1: "s", 2: "d", 3: "f", 4: "h", 5: "g", 6: "z", 7: "x", 8: "c", 9: "v",
            11: "b", 12: "q", 13: "w", 14: "e", 15: "r", 16: "y", 17: "t",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "o", 32: "u", 33: "i", 34: "p", 35: "[", 37: "l", 38: "j", 39: "'", 40: "k",
            41: ";", 42: "\\", 43: ",", 44: "n", 45: "m", 46: ".", 47: "/", 50: "`"
        ]
        return map[keyCode]
    }

    private static func keyName(_ keyCode: UInt16) -> String {
        switch Int(keyCode) {
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape: return "⎋"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_Home: return "Home"
        case kVK_End: return "End"
        case kVK_PageUp: return "Page Up"
        case kVK_PageDown: return "Page Down"
        case 122: return "F1"
        case 120: return "F2"
        case 99: return "F3"
        case 118: return "F4"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 100: return "F8"
        case 101: return "F9"
        case 109: return "F10"
        case 103: return "F11"
        case 111: return "F12"
        default:
            let map: [UInt16: String] = [
                0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
                11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
                18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
                30: "]", 31: "O", 32: "U", 33: "I", 34: "P", 35: "[", 37: "L", 38: "J", 39: "'", 40: "K",
                41: ";", 42: "\\", 43: ",", 44: "N", 45: "M", 46: ".", 47: "/", 50: "`"
            ]
            return map[keyCode] ?? "Key \(keyCode)"
        }
    }
}
