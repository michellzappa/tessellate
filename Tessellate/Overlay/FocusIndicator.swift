import AppKit

/// A borderless, click-through outline drawn around the window that the next
/// command key will move. Created once and reused: the activation path must not
/// pay for window/view construction.
@MainActor
final class FocusIndicatorController {
    static let shared = FocusIndicatorController()

    private var panel: NSPanel?
    private let view = FocusIndicatorView()

    private func panelIfNeeded() -> NSPanel {
        if let panel { return panel }
        let p = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = .screenSaver
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.ignoresMouseEvents = true
        p.isReleasedWhenClosed = false
        p.hidesOnDeactivate = false
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.contentView = view
        panel = p
        return p
    }

    /// Pre-build the panel so the first activation is as fast as the rest.
    func warmUp() {
        _ = panelIfNeeded()
    }

    func show(target: WindowEngine.FocusedWindow) {
        let screen = target.screen
        let panel = panelIfNeeded()
        view.target = ScreenGeometry.cocoaRect(fromAX: target.frame)
            .offsetBy(dx: -screen.frame.origin.x, dy: -screen.frame.origin.y)
        view.appName = target.appName
        view.appIcon = target.appIcon
        view.message = nil
        panel.setFrame(screen.frame, display: false)
        view.needsDisplay = true
        panel.orderFrontRegardless()
    }

    /// Nothing to move — say so instead of failing silently.
    func showMessage(_ text: String, on screen: NSScreen?) {
        guard let screen = screen ?? NSScreen.main else { return }
        let panel = panelIfNeeded()
        view.target = nil
        view.message = text
        panel.setFrame(screen.frame, display: false)
        view.needsDisplay = true
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
    }
}

private final class FocusIndicatorView: NSView {
    var target: CGRect?
    var appName: String = ""
    var appIcon: NSImage?
    var message: String?

    override var isFlipped: Bool { false }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.setFill()
        dirtyRect.fill()

        if let message {
            drawBadge(text: message, icon: nil, centeredIn: bounds, tint: NSColor.white.withAlphaComponent(0.28))
            return
        }
        guard let target else { return }

        // Neutral, not the system accent: the outline marks which window is
        // about to move, it is not a selection or a control.
        let outlineColor = NSColor.white.withAlphaComponent(0.92)

        // Dim everything except the target window.
        NSColor.black.withAlphaComponent(0.22).setFill()
        let mask = NSBezierPath(rect: bounds)
        mask.append(NSBezierPath(roundedRect: target, xRadius: 10, yRadius: 10).reversed)
        mask.windingRule = .evenOdd
        mask.fill()

        let outline = NSBezierPath(roundedRect: target.insetBy(dx: 1.5, dy: 1.5), xRadius: 10, yRadius: 10)

        NSColor.white.withAlphaComponent(0.06).setFill()
        outline.fill()

        outline.lineWidth = 3
        outlineColor.setStroke()
        outline.stroke()

        drawBadge(text: appName, icon: appIcon, centeredIn: target, tint: NSColor.white.withAlphaComponent(0.28))
    }

    private func drawBadge(text: String, icon: NSImage?, centeredIn rect: CGRect, tint: NSColor) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let title = NSAttributedString(string: text, attributes: attrs)
        let titleSize = title.size()
        let iconSize: CGFloat = icon == nil ? 0 : 22
        let gap: CGFloat = icon == nil ? 0 : 8
        let padding: CGFloat = 12
        let w = padding * 2 + iconSize + gap + titleSize.width
        let h = max(iconSize, titleSize.height) + padding

        var badge = CGRect(
            x: rect.midX - w / 2,
            y: rect.midY - h / 2,
            width: w,
            height: h
        )
        badge = badge.intersection(bounds).isEmpty ? badge : badge

        let bg = NSBezierPath(roundedRect: badge, xRadius: h / 2, yRadius: h / 2)
        NSColor.black.withAlphaComponent(0.72).setFill()
        bg.fill()
        tint.setStroke()
        bg.lineWidth = 1
        bg.stroke()

        var x = badge.minX + padding
        if let icon {
            icon.draw(in: CGRect(x: x, y: badge.midY - iconSize / 2, width: iconSize, height: iconSize))
            x += iconSize + gap
        }
        title.draw(at: CGPoint(x: x, y: badge.midY - titleSize.height / 2))
    }
}
