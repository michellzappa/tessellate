import SwiftUI
import AppKit
import Carbon.HIToolbox

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var keyCode: UInt16
    @Binding var modifiers: UInt
    var placeholder: String = "Click to record"

    func makeNSView(context: Context) -> ShortcutRecorderView {
        let v = ShortcutRecorderView()
        v.onCapture = { code, mods in
            DispatchQueue.main.async {
                self.keyCode = code
                self.modifiers = mods
            }
        }
        v.placeholder = placeholder
        return v
    }

    func updateNSView(_ nsView: ShortcutRecorderView, context: Context) {
        nsView.displayText = displayString(keyCode: keyCode, modifiers: modifiers)
        nsView.placeholder = placeholder
        nsView.needsDisplay = true
    }
}

final class ShortcutRecorderView: NSView {
    var onCapture: ((UInt16, UInt) -> Void)?
    var placeholder: String = "Click to record"
    var displayText: String = ""
    private var isRecording = false

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { true }

    private var isHovered = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self
        ))
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        NSCursor.pointingHand.set()
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        NSCursor.arrow.set()
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Recording reads as an active field; hover just hints it is clickable.
        layer?.backgroundColor = isRecording
            ? NSColor.controlAccentColor.withAlphaComponent(0.16).cgColor
            : NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = isRecording
            ? NSColor.controlAccentColor.cgColor
            : (isHovered ? NSColor.tertiaryLabelColor : NSColor.separatorColor).cgColor
        layer?.borderWidth = isRecording ? 2 : 1

        let text = isRecording ? "Press a key…" : (displayText.isEmpty ? placeholder : displayText)
        let color: NSColor = isRecording
            ? .controlAccentColor
            : (displayText.isEmpty ? .tertiaryLabelColor : .labelColor)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12, weight: .medium),
            .foregroundColor: color
        ]
        let str = NSAttributedString(string: text, attributes: attrs)
        let size = str.size()
        let rect = NSRect(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
        str.draw(in: rect)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        isRecording = true
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        if !isRecording { super.keyDown(with: event); return }
        let code = UInt16(event.keyCode)
        if code == CarbonKeys.escape {
            isRecording = false
            window?.makeFirstResponder(nil)
            needsDisplay = true
            return
        }
        if code == UInt16(kVK_Delete) || code == UInt16(kVK_ForwardDelete) {
            isRecording = false
            window?.makeFirstResponder(nil)
            onCapture?(0, 0)
            needsDisplay = true
            return
        }
        let mods = carbonModifiers(event.modifierFlags)
        let stripped = mods & ~(UInt(cmdKey | shiftKey | controlKey | optionKey))
        if stripped != 0 || code != 0 {
            isRecording = false
            window?.makeFirstResponder(nil)
            onCapture?(code, mods)
            needsDisplay = true
        }
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        needsDisplay = true
        return true
    }
}

func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt {
    var mods: UInt = 0
    if flags.contains(.command) { mods |= UInt(cmdKey) }
    if flags.contains(.option) { mods |= UInt(optionKey) }
    if flags.contains(.control) { mods |= UInt(controlKey) }
    if flags.contains(.shift) { mods |= UInt(shiftKey) }
    return mods
}

func displayString(keyCode: UInt16, modifiers: UInt) -> String {
    if keyCode == 0 { return "" }
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
        if let name = keyCodeToChar(keyCode) {
            return name
        }
        return "Key \(keyCode)"
    }
}

private func keyCodeToChar(_ keyCode: UInt16) -> String? {
    let map: [UInt16: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        18: "1", 19: "2", 20: "3", 21: "4", 22: "6", 23: "5",
        24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
        30: "]", 31: "O", 32: "U", 33: "I", 34: "P", 35: "[",
        37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
        43: ",", 44: "N", 45: "M", 46: ".", 47: "/", 50: "`"
    ]
    if let name = map[keyCode] {
        return name
    }
    return nil
}
