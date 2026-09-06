import SwiftUI

struct GridEditor: View {
    @Binding var rect: GridRect
    let grid: GridDimensions
    var onReset: () -> Void

    @State private var dragStartCol: Int?
    @State private var dragStartRow: Int?
    @State private var previewRect: GridRect?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Drag on the grid to define the target rectangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(dimensionsLabel)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                Button("Reset") { onReset() }
                    .buttonStyle(.borderless)
            }

            GeometryReader { geo in
                let cellW = geo.size.width / CGFloat(grid.columns)
                let cellH = geo.size.height / CGFloat(grid.rows)

                ZStack(alignment: .topLeading) {
                    gridLayer(cellW: cellW, cellH: cellH)

                    if let preview = previewRect {
                        Rectangle()
                            .fill(Color.accentColor.opacity(0.18))
                            .frame(
                                width: CGFloat(preview.w) * cellW,
                                height: CGFloat(preview.h) * cellH
                            )
                            .offset(
                                x: CGFloat(preview.x) * cellW,
                                y: CGFloat(preview.y) * cellH
                            )
                            .allowsHitTesting(false)
                    }

                    Rectangle()
                        .stroke(Color.accentColor, lineWidth: 2)
                        .frame(
                            width: CGFloat(rect.w) * cellW,
                            height: CGFloat(rect.h) * cellH
                        )
                        .offset(
                            x: CGFloat(rect.x) * cellW,
                            y: CGFloat(rect.y) * cellH
                        )
                        .allowsHitTesting(false)

                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let col = clamp(Int(value.location.x / cellW), 0, grid.columns)
                                    let row = clamp(Int(value.location.y / cellH), 0, grid.rows)
                                    if dragStartCol == nil {
                                        dragStartCol = col
                                        dragStartRow = row
                                    }
                                    guard let sc = dragStartCol, let sr = dragStartRow else { return }
                                    let x1 = min(sc, col)
                                    let x2 = max(sc, col) + 1
                                    let y1 = min(sr, row)
                                    let y2 = max(sr, row) + 1
                                    let p = GridRect(
                                        x: x1,
                                        y: y1,
                                        w: min(x2 - x1, grid.columns - x1),
                                        h: min(y2 - y1, grid.rows - y1)
                                    )
                                    previewRect = p
                                }
                                .onEnded { _ in
                                    if let p = previewRect {
                                        rect = p
                                    }
                                    previewRect = nil
                                    dragStartCol = nil
                                    dragStartRow = nil
                                }
                        )
                }
                .background(Color(NSColor.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            .aspectRatio(CGFloat(grid.columns) / CGFloat(grid.rows), contentMode: .fit)
        }
    }

    private var dimensionsLabel: String {
        let dims = ScreenGeometry.gridDims(for: NSScreen.main ?? NSScreen.screens[0], grid: grid)
        let w = Int(Double(rect.w) * Double(dims.cellW))
        let h = Int(Double(rect.h) * Double(dims.cellH))
        return "\(rect.w)×\(rect.h) cols  →  ~\(w)×\(h) px"
    }

    private func gridLayer(cellW: CGFloat, cellH: CGFloat) -> some View {
        Canvas { ctx, size in
            let lineColor = GraphicsContext.Shading.color(Color.secondary.opacity(0.2))
            for col in 0...grid.columns {
                let x = CGFloat(col) * cellW
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: lineColor, lineWidth: 0.5)
            }
            for row in 0...grid.rows {
                let y = CGFloat(row) * cellH
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: lineColor, lineWidth: 0.5)
            }
        }
    }

    private func clamp<T: Comparable>(_ value: T, _ min: T, _ max: T) -> T {
        Swift.min(Swift.max(value, min), max)
    }
}
