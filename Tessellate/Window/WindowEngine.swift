import AppKit
import ApplicationServices
import CoreGraphics

private let kAXResizableAttributeRaw = "AXResizable" as CFString
private let kAXMinSizeAttributeRaw = "AXMinSize" as CFString
private let kAXFocusedWindowAttributeRaw = "AXFocusedWindow" as CFString
private let kAXMainWindowAttributeRaw = "AXMainWindow" as CFString
private let kAXWindowsAttributeRaw = "AXWindows" as CFString
private let kAXFocusedApplicationAttributeRaw = "AXFocusedApplication" as CFString
private let kAXPositionAttributeRaw = "AXPosition" as CFString
private let kAXSizeAttributeRaw = "AXSize" as CFString

private extension CGRect {
    var area: CGFloat { isNull ? 0 : width * height }
}

enum WindowEngine {
    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestTrust() {
        let opts = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }

    static func focusedWindow() -> AXUIElement? {
        guard isTrusted() else {
            NSLog("Tessellate: focusedWindow — AX not trusted")
            return nil
        }

        let systemWide = AXUIElementCreateSystemWide()
        var appRef: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedApplicationAttributeRaw,
            &appRef
        )

        if appResult == .success,
           let appRef,
           CFGetTypeID(appRef) == AXUIElementGetTypeID() {
            let app = appRef as! AXUIElement

            if let win = axElement(in: app, attribute: kAXFocusedWindowAttributeRaw) {
                return win
            }
            if let win = axElement(in: app, attribute: kAXMainWindowAttributeRaw) {
                NSLog("Tessellate: focusedWindow — using main-window fallback")
                return win
            }
            if let win = largestVisibleWindow(in: app) {
                NSLog("Tessellate: focusedWindow — using largest-visible fallback (focused app)")
                return win
            }
        }

        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let app = AXUIElementCreateApplication(frontApp.processIdentifier)
            if let win = largestVisibleWindow(in: app) {
                NSLog("Tessellate: focusedWindow — using largest-visible fallback (frontmost app)")
                return win
            }
        }

        NSLog("Tessellate: focusedWindow — no window found")
        return nil
    }

    private static func axElement(in parent: AXUIElement, attribute: CFString) -> AXUIElement? {
        var ref: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(parent, attribute, &ref)
        guard result == .success, let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else {
            return nil
        }
        return ref as! AXUIElement
    }

    private static func largestVisibleWindow(in app: AXUIElement) -> AXUIElement? {
        var ref: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttributeRaw, &ref)
        guard result == .success, let ref, CFGetTypeID(ref) == CFArrayGetTypeID() else {
            return nil
        }
        let arr = ref as! CFArray
        let count = CFArrayGetCount(arr)

        var bestWin: AXUIElement?
        var bestArea: CGFloat = -1

        for i in 0..<count {
            let raw = CFArrayGetValueAtIndex(arr, i)
            let unmanaged = Unmanaged<CFTypeRef>.fromOpaque(raw!).takeUnretainedValue()
            guard CFGetTypeID(unmanaged) == AXUIElementGetTypeID() else { continue }
            let win = unmanaged as! AXUIElement

            guard let frame = frame(forAXWindow: win) else { continue }
            guard frame.width >= 100, frame.height >= 100 else { continue }

            let area = frame.width * frame.height
            if area > bestArea {
                bestArea = area
                bestWin = win
            }
        }

        return bestWin
    }

    static func isResizable(_ axWindow: AXUIElement) -> Bool {
        var ref: CFTypeRef?
        let r = AXUIElementCopyAttributeValue(
            axWindow,
            kAXResizableAttributeRaw,
            &ref
        )
        guard r == .success, let ref else { return true }
        return (ref as? Bool) ?? true
    }

    static func minSize(_ axWindow: AXUIElement) -> CGSize {
        var ref: CFTypeRef?
        let r = AXUIElementCopyAttributeValue(
            axWindow,
            kAXMinSizeAttributeRaw,
            &ref
        )
        guard r == .success, let ref,
              CFGetTypeID(ref) == AXValueGetTypeID() else {
            return .zero
        }
        var size = CGSize.zero
        AXValueGetValue(ref as! AXValue, .cgSize, &size)
        return size
    }

    static func screen(forAXWindow axWindow: AXUIElement) -> NSScreen? {
        guard let frame = frame(forAXWindow: axWindow) else { return NSScreen.main }
        return screen(forAXFrame: frame)
    }

    static func screen(forAXFrame frame: CGRect) -> NSScreen? {
        // AX frames are top-left origin; NSScreen.frame is bottom-left.
        let cocoa = ScreenGeometry.cocoaRect(fromAX: frame)
        let center = CGPoint(x: cocoa.midX, y: cocoa.midY)
        return NSScreen.screens.first { $0.frame.contains(center) }
            ?? NSScreen.screens.max { lhs, rhs in
                lhs.frame.intersection(cocoa).area < rhs.frame.intersection(cocoa).area
            }
            ?? NSScreen.main
    }

    /// Everything Tessellate needs about the window it is about to move,
    /// captured once at activation so the command path does no AX lookups.
    struct FocusedWindow {
        let element: AXUIElement
        let frame: CGRect          // Accessibility coords (top-left origin)
        let appName: String
        let appIcon: NSImage?
        let screen: NSScreen
    }

    static func captureFocusedWindow() -> FocusedWindow? {
        guard let element = focusedWindow(), let frame = frame(forAXWindow: element) else { return nil }
        var pid: pid_t = 0
        AXUIElementGetPid(element, &pid)
        let app = NSRunningApplication(processIdentifier: pid)
        return FocusedWindow(
            element: element,
            frame: frame,
            appName: app?.localizedName ?? "Focused window",
            appIcon: app?.icon,
            screen: screen(forAXFrame: frame) ?? NSScreen.main ?? NSScreen.screens[0]
        )
    }

    static func frame(forAXWindow axWindow: AXUIElement) -> CGRect? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(axWindow, kAXPositionAttributeRaw, &posRef)
        AXUIElementCopyAttributeValue(axWindow, kAXSizeAttributeRaw, &sizeRef)
        guard let posRef, let sizeRef else { return nil }
        var pos = CGPoint.zero
        var size = CGSize.zero
        if CFGetTypeID(posRef) == AXValueGetTypeID() {
            AXValueGetValue(posRef as! AXValue, .cgPoint, &pos)
        }
        if CFGetTypeID(sizeRef) == AXValueGetTypeID() {
            AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        }
        return CGRect(origin: pos, size: size)
    }

    @discardableResult
    static func apply(_ rect: CGRect, to axWindow: AXUIElement) -> Bool {
        var target = rect
        let min = minSize(axWindow)
        if min.width > 0, target.width < min.width {
            target.size.width = min.width
        }
        if min.height > 0, target.height < min.height {
            target.size.height = min.height
        }

        var pos = target.origin
        var size = target.size

        guard let posVal = AXValueCreate(.cgPoint, &pos),
              let sizeVal = AXValueCreate(.cgSize, &size) else {
            NSLog("Tessellate: apply — failed to create AXValue")
            return false
        }

        let posResult = AXUIElementSetAttributeValue(axWindow, kAXPositionAttributeRaw, posVal)
        let sizeResult = AXUIElementSetAttributeValue(axWindow, kAXSizeAttributeRaw, sizeVal)

        if posResult != .success || sizeResult != .success {
            NSLog("Tessellate: apply — AX rejected pos=\(posResult.rawValue) size=\(sizeResult.rawValue)")
            return false
        }
        return true
    }
}
