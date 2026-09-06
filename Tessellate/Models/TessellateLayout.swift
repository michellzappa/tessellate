import AppKit
import Foundation
import Carbon.HIToolbox

enum PlacementCommand: String, CaseIterable, Codable, Identifiable {
    case left
    case right
    case center
    case maximize

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .left: return "Left"
        case .right: return "Right"
        case .center: return "Center"
        case .maximize: return "Maximize"
        }
    }

    /// Target expressed as a fraction of the usable screen, so it survives any grid size.
    var defaultFraction: (x: Double, y: Double, w: Double, h: Double) {
        switch self {
        case .left: return (0, 0, 0.5, 1)
        case .right: return (0.5, 0, 0.5, 1)
        case .center: return (0.125, 0, 0.75, 1)
        case .maximize: return (0, 0, 1, 1)
        }
    }

    var defaultFractionRect: FractionRect {
        let f = defaultFraction
        return FractionRect(x: f.x, y: f.y, w: f.w, h: f.h)
    }

    func defaultRect(in grid: GridDimensions) -> GridRect {
        let f = defaultFraction
        // Round both edges, not position and size separately, so margins stay symmetric.
        let x = Int((f.x * Double(grid.columns)).rounded())
        let y = Int((f.y * Double(grid.rows)).rounded())
        let x2 = Int(((f.x + f.w) * Double(grid.columns)).rounded())
        let y2 = Int(((f.y + f.h) * Double(grid.rows)).rounded())
        return GridRect(x: x, y: y, w: max(1, x2 - x), h: max(1, y2 - y)).clamped(to: grid)
    }

    var defaultRect: GridRect { defaultRect(in: .default) }

    var index: Int {
        switch self {
        case .left: return 0
        case .right: return 1
        case .center: return 2
        case .maximize: return 3
        }
    }

    static func fromIndex(_ index: Int) -> PlacementCommand? {
        guard index >= 0, index < allCases.count else { return nil }
        return allCases[index]
    }
}

/// A placement target as a fraction of the usable screen. This is the stored
/// form: the grid is only a snapping aid for editing, so changing grid size can
/// never move a target. Storing grid cells and rescaling them on every grid
/// change accumulated rounding error until "center" was visibly off-centre.
struct FractionRect: Codable, Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    init(x: Double, y: Double, w: Double, h: Double) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    /// Round-trips through grid cells, for editing on the grid.
    init(gridRect r: GridRect, grid: GridDimensions) {
        let cols = Double(max(1, grid.columns))
        let rows = Double(max(1, grid.rows))
        self.init(
            x: Double(r.x) / cols,
            y: Double(r.y) / rows,
            w: Double(r.w) / cols,
            h: Double(r.h) / rows
        )
        self = clamped()
    }

    func clamped() -> FractionRect {
        let cw = min(max(w, 0.01), 1)
        let ch = min(max(h, 0.01), 1)
        return FractionRect(
            x: min(max(x, 0), 1 - cw),
            y: min(max(y, 0), 1 - ch),
            w: cw,
            h: ch
        )
    }

    func snapped(to grid: GridDimensions) -> GridRect {
        let c = clamped()
        let cols = Double(grid.columns)
        let rows = Double(grid.rows)
        return GridRect(
            x: Int((c.x * cols).rounded()),
            y: Int((c.y * rows).rounded()),
            w: max(1, Int((c.w * cols).rounded())),
            h: max(1, Int((c.h * rows).rounded()))
        ).clamped(to: grid)
    }
}

struct GridRect: Codable, Equatable {
    var x: Int
    var y: Int
    var w: Int
    var h: Int

    init(x: Int, y: Int, w: Int, h: Int) {
        self.x = x
        self.y = y
        self.w = w
        self.h = h
    }

    static let defaultLeft = GridRect(x: 0, y: 0, w: 8, h: 10)
    static let defaultRight = GridRect(x: 8, y: 0, w: 8, h: 10)
    static let defaultCenter = GridRect(x: 2, y: 0, w: 12, h: 10)
    static let defaultMaximize = GridRect(x: 0, y: 0, w: 16, h: 10)

    func clamped(to grid: GridDimensions) -> GridRect {
        let cx = max(0, min(x, grid.columns - 1))
        let cy = max(0, min(y, grid.rows - 1))
        let cw = max(1, min(w, grid.columns - cx))
        let ch = max(1, min(h, grid.rows - cy))
        return GridRect(x: cx, y: cy, w: cw, h: ch)
    }
}

/// How fine the grid should be. The actual column/row counts are derived from the
/// screen so that cells come out square.
enum GridDensity: String, Codable, CaseIterable, Identifiable {
    case light
    case balanced
    case dense
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .light: return "Light"
        case .balanced: return "Balanced"
        case .dense: return "Dense"
        case .custom: return "Custom"
        }
    }

    /// Preferred cell edge length, in points.
    var targetCellSize: CGFloat {
        switch self {
        case .light: return 200
        case .balanced: return 130
        case .dense: return 85
        case .custom: return 130
        }
    }

    var isAutomatic: Bool { self != .custom }
}

private extension Int {
    /// Round up to the next even number.
    func rounded2() -> Int { self % 2 == 0 ? self : self + 1 }
}

struct GridDimensions: Codable, Equatable {
    var columns: Int
    var rows: Int

    init(columns: Int = 16, rows: Int = 10) {
        self.columns = columns
        self.rows = rows
    }

    static let `default` = GridDimensions()

    static let bounds = 1...64

    /// Column/row counts for `screen` at `density`, chosen so cells are as close to
    /// square as integer counts allow.
    static func proposed(for screen: NSScreen, density: GridDensity) -> GridDimensions {
        let usable = ScreenGeometry.usableFrame(for: screen)
        return proposed(width: usable.width, height: usable.height, density: density)
    }

    static func proposed(width: CGFloat, height: CGFloat, density: GridDensity) -> GridDimensions {
        guard width > 0, height > 0 else { return .default }
        let target = density.targetCellSize
        let ideal = max(2, Int((width / target).rounded()))
        let lower = max(2, ideal - 2)
        let upper = min(bounds.upperBound, ideal + 2)

        var best = GridDimensions.default
        var bestScore = Double.greatestFiniteMagnitude
        // Columns stay even so left/right halves split exactly; the narrow range
        // around `ideal` keeps the three densities distinct on any display.
        for columns in stride(from: lower.rounded2(), through: upper, by: 2) {
            let cellW = width / CGFloat(columns)
            let rows = min(bounds.upperBound, max(1, Int((height / cellW).rounded())))
            let cellH = height / CGFloat(rows)
            // Squareness dominates; cell size is the tie-breaker.
            let squareError = abs(Double(cellW / cellH) - 1)
            let sizeError = abs(Double(cellW - target)) / Double(target)
            let score = squareError * 4 + sizeError
            if score < bestScore {
                bestScore = score
                best = GridDimensions(columns: columns, rows: rows)
            }
        }
        return best
    }

    func cellSize(on screen: NSScreen) -> CGSize {
        let dims = ScreenGeometry.gridDims(for: screen, grid: self)
        return CGSize(width: dims.cellW, height: dims.cellH)
    }
}

struct CommandBinding: Codable, Equatable {
    var keyCode: UInt16
    var modifiers: UInt

    init(keyCode: UInt16, modifiers: UInt) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}

struct TessellateLayout: Codable, Equatable {
    var grid: GridDimensions
    var gridDensity: GridDensity
    var fractions: [String: FractionRect]
    var bindings: [String: CommandBinding]
    var activationKeyCode: UInt16
    var activationModifiers: UInt
    var showMenuBarIcon: Bool
    var launchAtLogin: Bool

    init() {
        self.grid = GridDimensions()
        self.gridDensity = .balanced
        self.fractions = Dictionary(
            uniqueKeysWithValues: PlacementCommand.allCases.map { ($0.rawValue, $0.defaultFractionRect) }
        )
        self.bindings = [
            PlacementCommand.left.rawValue: CommandBinding(keyCode: 123, modifiers: 0),
            PlacementCommand.right.rawValue: CommandBinding(keyCode: 124, modifiers: 0),
            PlacementCommand.center.rawValue: CommandBinding(keyCode: 49, modifiers: 0),
            PlacementCommand.maximize.rawValue: CommandBinding(keyCode: 126, modifiers: 0)
        ]
        self.activationKeyCode = 49
        self.activationModifiers = UInt(optionKey)
        self.showMenuBarIcon = true
        self.launchAtLogin = false
    }

    private enum CodingKeys: String, CodingKey {
        case grid, gridDensity, fractions, bindings
        case activationKeyCode, activationModifiers, showMenuBarIcon, launchAtLogin
        case rects  // legacy: grid cells, migrated to fractions on read
    }

    // Layouts written before the density setting existed decode with defaults filled in.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = TessellateLayout()
        grid = try c.decodeIfPresent(GridDimensions.self, forKey: .grid) ?? fallback.grid
        gridDensity = try c.decodeIfPresent(GridDensity.self, forKey: .gridDensity) ?? fallback.gridDensity
        if let stored = try c.decodeIfPresent([String: FractionRect].self, forKey: .fractions) {
            fractions = stored
        } else if let legacy = try c.decodeIfPresent([String: GridRect].self, forKey: .rects) {
            let legacyGrid = grid
            fractions = legacy.mapValues { FractionRect(gridRect: $0, grid: legacyGrid) }
        } else {
            fractions = fallback.fractions
        }
        bindings = try c.decodeIfPresent([String: CommandBinding].self, forKey: .bindings) ?? fallback.bindings
        activationKeyCode = try c.decodeIfPresent(UInt16.self, forKey: .activationKeyCode) ?? fallback.activationKeyCode
        activationModifiers = try c.decodeIfPresent(UInt.self, forKey: .activationModifiers) ?? fallback.activationModifiers
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? fallback.showMenuBarIcon
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? fallback.launchAtLogin
    }

    // `rects` is decode-only, so encoding has to be written out explicitly.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(grid, forKey: .grid)
        try c.encode(gridDensity, forKey: .gridDensity)
        try c.encode(fractions, forKey: .fractions)
        try c.encode(bindings, forKey: .bindings)
        try c.encode(activationKeyCode, forKey: .activationKeyCode)
        try c.encode(activationModifiers, forKey: .activationModifiers)
        try c.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
    }

    func fraction(for command: PlacementCommand) -> FractionRect {
        (fractions[command.rawValue] ?? command.defaultFractionRect).clamped()
    }

    func rect(for command: PlacementCommand) -> GridRect {
        fraction(for: command).snapped(to: grid)
    }

    /// Targets are stored as screen fractions, so changing the grid only changes
    /// where they snap when edited — it never moves them.
    mutating func resizeGrid(to newGrid: GridDimensions) {
        grid = newGrid
    }

    mutating func setRect(_ rect: GridRect, for command: PlacementCommand) {
        fractions[command.rawValue] = FractionRect(gridRect: rect.clamped(to: grid), grid: grid)
    }

    mutating func setFraction(_ fraction: FractionRect, for command: PlacementCommand) {
        fractions[command.rawValue] = fraction.clamped()
    }

    func binding(for command: PlacementCommand) -> CommandBinding? {
        bindings[command.rawValue]
    }

    mutating func setBinding(_ binding: CommandBinding?, for command: PlacementCommand) {
        if let binding {
            bindings[command.rawValue] = binding
        } else {
            bindings.removeValue(forKey: command.rawValue)
        }
    }
}

enum CarbonKeys {
    static let escape: UInt16 = 53
    static let space: UInt16 = 49
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
}
