import AppKit
import SwiftUI

@MainActor
final class PlacementOverlayController {
    static let shared = PlacementOverlayController()

    private var window: NSWindow?
    private var host: NSHostingView<OverlayContent>?
    private var dismissTask: DispatchWorkItem?

    func show(
        on screen: NSScreen,
        grid: GridDimensions,
        rects: [PlacementCommand: GridRect],
        focusedFrame: CGRect?,
        accessibilityGranted: Bool,
        showNoWindowMessage: Bool = false,
        autoDismissAfter: TimeInterval? = nil
    ) {
        hide()

        let frame = screen.visibleFrame
        let win = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        win.level = .screenSaver
        win.isOpaque = false
        win.backgroundColor = .clear
        win.ignoresMouseEvents = true
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        win.hidesOnDeactivate = false
        win.hasShadow = false

        let content = OverlayContent(
            screenFrame: frame,
            grid: grid,
            rects: rects,
            focusedFrame: focusedFrame,
            accessibilityGranted: accessibilityGranted,
            showNoWindowMessage: showNoWindowMessage
        )
        let hostView = NSHostingView(rootView: content)
        hostView.frame = NSRect(origin: .zero, size: frame.size)
        hostView.autoresizingMask = [.width, .height]
        hostView.layer?.backgroundColor = .clear
        win.contentView?.addSubview(hostView)
        host = hostView

        win.setFrame(frame, display: false)
        win.orderFrontRegardless()
        window = win

        if let autoDismissAfter {
            let task = DispatchWorkItem { [weak self] in
                self?.hide()
            }
            dismissTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + autoDismissAfter, execute: task)
        }
    }

    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        window?.orderOut(nil)
        window = nil
        host = nil
    }
}

struct OverlayContent: View {
    let screenFrame: CGRect
    let grid: GridDimensions
    let rects: [PlacementCommand: GridRect]
    let focusedFrame: CGRect?
    let accessibilityGranted: Bool
    let showNoWindowMessage: Bool

    private var cellW: CGFloat { screenFrame.width / CGFloat(grid.columns) }
    private var cellH: CGFloat { screenFrame.height / CGFloat(grid.rows) }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.18)

            gridView

            if let f = focusedFrame {
                focusedWindowOutline(frame: f)
            }

            ForEach(PlacementCommand.allCases) { command in
                zone(command)
            }

            if !accessibilityGranted {
                permissionBanner
            } else if showNoWindowMessage {
                noWindowBanner
            }
        }
        .frame(width: screenFrame.width, height: screenFrame.height)
    }

    private var gridView: some View {
        Canvas { ctx, size in
            let shading = GraphicsContext.Shading.color(Color.white.opacity(0.16))
            for col in 0...grid.columns {
                let x = CGFloat(col) * cellW
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: shading, lineWidth: 0.5)
            }
            for row in 0...grid.rows {
                let y = CGFloat(row) * cellH
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: shading, lineWidth: 0.5)
            }
        }
        .allowsHitTesting(false)
    }

    private func focusedWindowOutline(frame f: CGRect) -> some View {
        let localX = f.origin.x - screenFrame.origin.x
        let localY = screenFrame.maxY - f.origin.y - f.height
        return Rectangle()
            .strokeBorder(Color.yellow, lineWidth: 3)
            .background(
                Rectangle().fill(Color.yellow.opacity(0.08))
            )
            .frame(width: f.width, height: f.height)
            .offset(x: localX, y: localY)
            .allowsHitTesting(false)
    }

    private func zone(_ command: PlacementCommand) -> some View {
        let r = rects[command] ?? command.defaultRect(in: grid)
        let x = CGFloat(r.x) * cellW
        let y = CGFloat(r.y) * cellH
        let w = CGFloat(r.w) * cellW
        let h = CGFloat(r.h) * cellH
        let color = zoneColor(command)
        let fontSize = max(28.0, min(64.0, h / 4.5))

        return ZStack {
            Rectangle()
                .fill(color.opacity(0.22))
            Rectangle()
                .strokeBorder(color, lineWidth: 2)
            VStack(spacing: 6) {
                Text(zoneLabel(command))
                    .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(command.displayName.uppercased())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.85))
            }
            .shadow(color: .black.opacity(0.5), radius: 4, y: 1)
            .padding(8)
        }
        .frame(width: w, height: h)
        .offset(x: x, y: y)
        .allowsHitTesting(false)
    }

    private var permissionBanner: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text("Tessellate needs Accessibility permission")
                .font(.title3.weight(.semibold))
                .foregroundStyle(.white)
            Text("System Settings → Privacy & Security → Accessibility")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.85))
            Text("Press Esc to dismiss")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(24)
        .background(.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noWindowBanner: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(.white.opacity(0.85))
            Text("No window focused")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Click on a window, then try again")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(20)
        .background(.black.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func zoneColor(_ command: PlacementCommand) -> Color {
        switch command {
        case .left: return .blue
        case .right: return .green
        case .center: return .purple
        case .maximize: return .orange
        }
    }

    private func zoneLabel(_ command: PlacementCommand) -> String {
        switch command {
        case .left: return "←"
        case .right: return "→"
        case .center: return "Space"
        case .maximize: return "↑"
        }
    }
}
