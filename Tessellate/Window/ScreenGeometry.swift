import AppKit

enum ScreenGeometry {
    static func usableFrame(for screen: NSScreen) -> CGRect {
        screen.visibleFrame
    }

    /// Grid coordinates are top-down (row 0 is the top of the usable area), so
    /// this returns a rect in Accessibility space: global, origin top-left.
    static func gridRect(
        _ gridRect: GridRect,
        grid: GridDimensions,
        on screen: NSScreen
    ) -> CGRect {
        let usable = usableFrame(for: screen)
        let cellW = usable.width / CGFloat(grid.columns)
        let cellH = usable.height / CGFloat(grid.rows)
        let ns = CGRect(
            x: usable.origin.x + CGFloat(gridRect.x) * cellW,
            y: usable.maxY - CGFloat(gridRect.y + gridRect.h) * cellH,
            width: CGFloat(gridRect.w) * cellW,
            height: CGFloat(gridRect.h) * cellH
        )
        return axRect(fromCocoa: ns)
    }

    static func gridDims(for screen: NSScreen, grid: GridDimensions) -> (cellW: CGFloat, cellH: CGFloat) {
        let usable = usableFrame(for: screen)
        return (usable.width / CGFloat(grid.columns), usable.height / CGFloat(grid.rows))
    }

    /// Height of the global coordinate space: the primary screen's frame is the
    /// origin for both Cocoa (bottom-left) and Accessibility (top-left) coords.
    private static var globalHeight: CGFloat {
        (NSScreen.screens.first { $0.frame.origin == .zero } ?? NSScreen.screens.first)?.frame.maxY ?? 0
    }

    static func axRect(fromCocoa rect: CGRect) -> CGRect {
        CGRect(x: rect.origin.x, y: globalHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func cocoaRect(fromAX rect: CGRect) -> CGRect {
        CGRect(x: rect.origin.x, y: globalHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
