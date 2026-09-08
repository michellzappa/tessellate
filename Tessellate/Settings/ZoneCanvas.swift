import SwiftUI

/// The single interactive map of the screen used everywhere in Settings.
///
/// One canvas keeps every zone visible at once, with the selected command as the
/// one you drag. Editing and previewing are the same surface, so there is
/// nothing to keep in sync.
struct ZoneCanvas: View {
    let grid: GridDimensions
    let commands: [PlacementCommand]
    let selection: PlacementCommand?
    /// Nil while the canvas is read-only (no drag handling).
    var onEdit: ((GridRect) -> Void)?

    @State private var dragOrigin: (col: Int, row: Int)?
    @State private var preview: GridRect?

    private var isEditable: Bool { onEdit != nil }

    var body: some View {
        GeometryReader { geo in
            let cellW = geo.size.width / CGFloat(grid.columns)
            let cellH = geo.size.height / CGFloat(grid.rows)

            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    let shading = GraphicsContext.Shading.color(.primary.opacity(0.08))
                    for col in 1..<max(grid.columns, 1) {
                        let x = (CGFloat(col) * cellW).rounded()
                        var path = Path()
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: size.height))
                        ctx.stroke(path, with: shading, lineWidth: 1)
                    }
                    for row in 1..<max(grid.rows, 1) {
                        let y = (CGFloat(row) * cellH).rounded()
                        var path = Path()
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: size.width, y: y))
                        ctx.stroke(path, with: shading, lineWidth: 1)
                    }
                }

                // Unselected zones stay as quiet outlines: context without noise.
                ForEach(commands.filter { $0.id != selection?.id }) { command in
                    zoneFrame(rect(for: command), cellW: cellW, cellH: cellH) {
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(
                                .primary.opacity(0.22),
                                style: StrokeStyle(lineWidth: 1, dash: [3, 3])
                            )
                    }
                }

                if let selection {
                    let active = preview ?? rect(for: selection)
                    zoneFrame(active, cellW: cellW, cellH: cellH) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color.accentColor.opacity(preview == nil ? 0.22 : 0.3))
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .strokeBorder(Color.accentColor, lineWidth: 2)
                            )
                            .overlay(
                                Text(selection.displayName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(Color.accentColor)
                                    .padding(4)
                                    .lineLimit(1)
                            )
                    }
                    .animation(.snappy(duration: 0.15), value: active)
                }

                if isEditable, selection != nil {
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(dragGesture(cellW: cellW, cellH: cellH))
                }
            }
        }
        .aspectRatio(CGFloat(grid.columns) / CGFloat(grid.rows), contentMode: .fit)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(.separator, lineWidth: 1)
        )
    }

    private func rect(for command: PlacementCommand) -> GridRect {
        command.fraction.snapped(to: grid)
    }

    private func zoneFrame<Content: View>(
        _ r: GridRect,
        cellW: CGFloat,
        cellH: CGFloat,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(width: CGFloat(r.w) * cellW, height: CGFloat(r.h) * cellH)
            .offset(x: CGFloat(r.x) * cellW, y: CGFloat(r.y) * cellH)
            .allowsHitTesting(false)
    }

    private func dragGesture(cellW: CGFloat, cellH: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let col = clamp(Int(value.location.x / cellW), 0, grid.columns - 1)
                let row = clamp(Int(value.location.y / cellH), 0, grid.rows - 1)
                if dragOrigin == nil { dragOrigin = (col, row) }
                guard let origin = dragOrigin else { return }
                let x = min(origin.col, col)
                let y = min(origin.row, row)
                preview = GridRect(
                    x: x,
                    y: y,
                    w: max(origin.col, col) - x + 1,
                    h: max(origin.row, row) - y + 1
                ).clamped(to: grid)
            }
            .onEnded { _ in
                if let preview { onEdit?(preview) }
                preview = nil
                dragOrigin = nil
            }
    }

    private func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        min(max(value, lower), max(lower, upper))
    }
}
