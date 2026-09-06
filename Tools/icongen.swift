import AppKit

// 1024pt canvas; artwork inset to the standard macOS rounded-square footprint.
func drawIcon(size: CGFloat) -> NSImage {
    let img = NSImage(size: NSSize(width: size, height: size))
    img.lockFocus()
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size / 1024.0
    ctx.scaleBy(x: s, y: s)

    let plate = CGRect(x: 100, y: 100, width: 824, height: 824)
    let platePath = NSBezierPath(roundedRect: plate, xRadius: 185, yRadius: 185)

    ctx.saveGState()
    platePath.addClip()
    let colors = [
        NSColor(calibratedWhite: 0.28, alpha: 1).cgColor,
        NSColor(calibratedWhite: 0.13, alpha: 1).cgColor
    ] as CFArray
    let grad = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: plate.minX, y: plate.maxY),
                           end: CGPoint(x: plate.maxX, y: plate.minY), options: [])
    ctx.restoreGState()

    // Hairline rim so the plate reads on both light and dark backdrops.
    NSColor(calibratedWhite: 1, alpha: 0.16).setStroke()
    platePath.lineWidth = 4
    platePath.stroke()

    // Three panes: one tall left, two stacked right — the shape the app makes.
    let field = CGRect(x: 250, y: 250, width: 524, height: 524)
    let gap: CGFloat = 34
    let radius: CGFloat = 26
    let leftW = (field.width - gap) * 0.5
    let rightX = field.minX + leftW + gap
    let rightW = field.width - leftW - gap
    let rightH = (field.height - gap) * 0.5

    func pane(_ r: CGRect, alpha: CGFloat) {
        NSColor(calibratedWhite: 1, alpha: alpha).setFill()
        NSBezierPath(roundedRect: r, xRadius: radius, yRadius: radius).fill()
    }
    pane(CGRect(x: field.minX, y: field.minY, width: leftW, height: field.height), alpha: 0.97)
    pane(CGRect(x: rightX, y: field.minY + rightH + gap, width: rightW, height: rightH), alpha: 0.72)
    pane(CGRect(x: rightX, y: field.minY, width: rightW, height: rightH), alpha: 0.52)

    img.unlockFocus()
    return img
}

let outDir = CommandLine.arguments[1]
for size in [16, 32, 64, 128, 256, 512, 1024] {
    let img = drawIcon(size: CGFloat(size))
    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:]) else { continue }
    try! png.write(to: URL(fileURLWithPath: "\(outDir)/icon_\(size).png"))
}
print("rendered")
