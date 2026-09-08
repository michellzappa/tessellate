import SwiftUI
import Carbon.HIToolbox

/// A native menu-based shortcut editor. Tab and arrow keys are reserved by
/// AppKit for focus navigation, so selecting from a menu is deterministic.
struct ShortcutPicker: View {
    @Binding var binding: CommandBinding?
    var placeholder: String = "Unbound"

    private var keyCodeSelection: Binding<UInt16?> {
        Binding(
            get: { binding?.keyCode },
            set: { newKeyCode in
                guard let newKeyCode else {
                    binding = nil
                    return
                }
                binding = CommandBinding(
                    keyCode: newKeyCode,
                    modifiers: binding?.modifiers ?? 0
                )
            }
        )
    }

    private var modifiersSelection: Binding<UInt> {
        Binding(
            get: { binding?.modifiers ?? 0 },
            set: { newModifiers in
                guard let keyCode = binding?.keyCode else { return }
                binding = CommandBinding(keyCode: keyCode, modifiers: newModifiers)
            }
        )
    }

    var body: some View {
        HStack(spacing: 6) {
            Picker("Key", selection: keyCodeSelection) {
                Text(placeholder).tag(nil as UInt16?)
                ForEach(ShortcutKeyOption.all) { option in
                    Text(option.menuName).tag(Optional(option.keyCode))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)

            if binding != nil {
                Picker("Modifiers", selection: modifiersSelection) {
                    ForEach(ShortcutModifierOption.all) { option in
                        Text(option.name).tag(option.value)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .help(binding.map { displayString(keyCode: $0.keyCode, modifiers: $0.modifiers) } ?? placeholder)
    }
}

private struct ShortcutKeyOption: Identifiable, Hashable {
    let keyCode: UInt16
    let menuName: String

    var id: UInt16 { keyCode }

    static let all: [ShortcutKeyOption] = [
        ShortcutKeyOption(keyCode: UInt16(kVK_Space), menuName: "Space"),
        ShortcutKeyOption(keyCode: UInt16(kVK_Tab), menuName: "⇥  Tab"),
        ShortcutKeyOption(keyCode: UInt16(kVK_Return), menuName: "↩  Return"),
        ShortcutKeyOption(keyCode: UInt16(kVK_Escape), menuName: "⎋  Escape"),
        ShortcutKeyOption(keyCode: UInt16(kVK_Delete), menuName: "⌫  Delete"),
        ShortcutKeyOption(keyCode: UInt16(kVK_ForwardDelete), menuName: "⌦  Forward Delete"),
        ShortcutKeyOption(keyCode: UInt16(kVK_LeftArrow), menuName: "←  Left Arrow"),
        ShortcutKeyOption(keyCode: UInt16(kVK_RightArrow), menuName: "→  Right Arrow"),
        ShortcutKeyOption(keyCode: UInt16(kVK_UpArrow), menuName: "↑  Up Arrow"),
        ShortcutKeyOption(keyCode: UInt16(kVK_DownArrow), menuName: "↓  Down Arrow"),
        ShortcutKeyOption(keyCode: UInt16(kVK_Home), menuName: "Home"),
        ShortcutKeyOption(keyCode: UInt16(kVK_End), menuName: "End"),
        ShortcutKeyOption(keyCode: UInt16(kVK_PageUp), menuName: "Page Up"),
        ShortcutKeyOption(keyCode: UInt16(kVK_PageDown), menuName: "Page Down"),
        ShortcutKeyOption(keyCode: 122, menuName: "F1"),
        ShortcutKeyOption(keyCode: 120, menuName: "F2"),
        ShortcutKeyOption(keyCode: 99, menuName: "F3"),
        ShortcutKeyOption(keyCode: 118, menuName: "F4"),
        ShortcutKeyOption(keyCode: 96, menuName: "F5"),
        ShortcutKeyOption(keyCode: 97, menuName: "F6"),
        ShortcutKeyOption(keyCode: 98, menuName: "F7"),
        ShortcutKeyOption(keyCode: 100, menuName: "F8"),
        ShortcutKeyOption(keyCode: 101, menuName: "F9"),
        ShortcutKeyOption(keyCode: 109, menuName: "F10"),
        ShortcutKeyOption(keyCode: 103, menuName: "F11"),
        ShortcutKeyOption(keyCode: 111, menuName: "F12"),
        ShortcutKeyOption(keyCode: 0, menuName: "A"),
        ShortcutKeyOption(keyCode: 11, menuName: "B"),
        ShortcutKeyOption(keyCode: 8, menuName: "C"),
        ShortcutKeyOption(keyCode: 2, menuName: "D"),
        ShortcutKeyOption(keyCode: 14, menuName: "E"),
        ShortcutKeyOption(keyCode: 3, menuName: "F"),
        ShortcutKeyOption(keyCode: 5, menuName: "G"),
        ShortcutKeyOption(keyCode: 4, menuName: "H"),
        ShortcutKeyOption(keyCode: 34, menuName: "I"),
        ShortcutKeyOption(keyCode: 38, menuName: "J"),
        ShortcutKeyOption(keyCode: 40, menuName: "K"),
        ShortcutKeyOption(keyCode: 37, menuName: "L"),
        ShortcutKeyOption(keyCode: 46, menuName: "M"),
        ShortcutKeyOption(keyCode: 45, menuName: "N"),
        ShortcutKeyOption(keyCode: 31, menuName: "O"),
        ShortcutKeyOption(keyCode: 35, menuName: "P"),
        ShortcutKeyOption(keyCode: 12, menuName: "Q"),
        ShortcutKeyOption(keyCode: 15, menuName: "R"),
        ShortcutKeyOption(keyCode: 1, menuName: "S"),
        ShortcutKeyOption(keyCode: 17, menuName: "T"),
        ShortcutKeyOption(keyCode: 32, menuName: "U"),
        ShortcutKeyOption(keyCode: 9, menuName: "V"),
        ShortcutKeyOption(keyCode: 13, menuName: "W"),
        ShortcutKeyOption(keyCode: 7, menuName: "X"),
        ShortcutKeyOption(keyCode: 16, menuName: "Y"),
        ShortcutKeyOption(keyCode: 6, menuName: "Z"),
        ShortcutKeyOption(keyCode: 29, menuName: "0"),
        ShortcutKeyOption(keyCode: 18, menuName: "1"),
        ShortcutKeyOption(keyCode: 19, menuName: "2"),
        ShortcutKeyOption(keyCode: 20, menuName: "3"),
        ShortcutKeyOption(keyCode: 21, menuName: "4"),
        ShortcutKeyOption(keyCode: 23, menuName: "5"),
        ShortcutKeyOption(keyCode: 22, menuName: "6"),
        ShortcutKeyOption(keyCode: 26, menuName: "7"),
        ShortcutKeyOption(keyCode: 28, menuName: "8"),
        ShortcutKeyOption(keyCode: 25, menuName: "9")
    ]
}

private struct ShortcutModifierOption: Identifiable, Hashable {
    let value: UInt
    let name: String

    var id: UInt { value }

    static let all: [ShortcutModifierOption] = {
        let bits: [(UInt, String)] = [
            (UInt(cmdKey), "⌘"),
            (UInt(optionKey), "⌥"),
            (UInt(controlKey), "⌃"),
            (UInt(shiftKey), "⇧")
        ]
        return (0..<16).map { mask in
            let value = bits.enumerated().reduce(UInt(0)) { result, item in
                result | ((mask & (1 << item.offset)) != 0 ? item.element.0 : 0)
            }
            let name = bits.enumerated()
                .filter { mask & (1 << $0.offset) != 0 }
                .map { $0.element.1 }
                .joined()
            return ShortcutModifierOption(value: value, name: name.isEmpty ? "No modifiers" : name)
        }
    }()
}

func displayString(keyCode: UInt16?, modifiers: UInt) -> String {
    guard let keyCode else { return "" }
    var parts: [String] = []
    if modifiers & UInt(controlKey) != 0 { parts.append("⌃") }
    if modifiers & UInt(optionKey) != 0 { parts.append("⌥") }
    if modifiers & UInt(shiftKey) != 0 { parts.append("⇧") }
    if modifiers & UInt(cmdKey) != 0 { parts.append("⌘") }
    parts.append(keyName(keyCode))
    return parts.joined()
}

func keyName(_ keyCode: UInt16) -> String {
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
    default:
        let map: [UInt16: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
            18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5", 25: "9", 26: "7", 28: "8", 29: "0",
            24: "=", 27: "-", 30: "]", 31: "O", 32: "U", 33: "I", 34: "P", 35: "[",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "N", 45: "M", 46: ".", 47: "/", 50: "`"
        ]
        return map[keyCode] ?? "Key \(keyCode)"
    }
}
