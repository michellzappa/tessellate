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

    func defaultRect(in grid: GridDimensions) -> GridRect {
        let f = defaultFraction
        let x = Int((f.x * Double(grid.columns)).rounded())
        let y = Int((f.y * Double(grid.rows)).rounded())
        let w = max(1, Int((f.w * Double(grid.columns)).rounded()))
        let h = max(1, Int((f.h * Double(grid.rows)).rounded()))
        return GridRect(x: x, y: y, w: w, h: h).clamped(to: grid)
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
        let lower = max(2, ideal - 6)
        let upper = min(bounds.upperBound, ideal + 6)

        var best = GridDimensions.default
        var bestScore = Double.greatestFiniteMagnitude
        // Counts stay even so halves and quarters split exactly.
        for columns in stride(from: lower.rounded2(), through: upper, by: 2) {
            let cellW = width / CGFloat(columns)
            let rows = min(bounds.upperBound, max(2, Int((height / cellW / 2).rounded()) * 2))
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
    var rects: [String: GridRect]
    var bindings: [String: CommandBinding]
    var activationKeyCode: UInt16
    var activationModifiers: UInt
    var showMenuBarIcon: Bool
    var launchAtLogin: Bool

    init() {
        self.grid = GridDimensions()
        self.gridDensity = .balanced
        self.rects = [
            PlacementCommand.left.rawValue: .defaultLeft,
            PlacementCommand.right.rawValue: .defaultRight,
            PlacementCommand.center.rawValue: .defaultCenter,
            PlacementCommand.maximize.rawValue: .defaultMaximize
        ]
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

    // Layouts written before the density setting existed decode with defaults filled in.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = TessellateLayout()
        grid = try c.decodeIfPresent(GridDimensions.self, forKey: .grid) ?? fallback.grid
        gridDensity = try c.decodeIfPresent(GridDensity.self, forKey: .gridDensity) ?? fallback.gridDensity
        rects = try c.decodeIfPresent([String: GridRect].self, forKey: .rects) ?? fallback.rects
        bindings = try c.decodeIfPresent([String: CommandBinding].self, forKey: .bindings) ?? fallback.bindings
        activationKeyCode = try c.decodeIfPresent(UInt16.self, forKey: .activationKeyCode) ?? fallback.activationKeyCode
        activationModifiers = try c.decodeIfPresent(UInt.self, forKey: .activationModifiers) ?? fallback.activationModifiers
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? fallback.showMenuBarIcon
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? fallback.launchAtLogin
    }

    func rect(for command: PlacementCommand) -> GridRect {
        (rects[command.rawValue] ?? command.defaultRect(in: grid)).clamped(to: grid)
    }

    /// Move to a new grid size, remapping every stored rect proportionally so the
    /// commands keep pointing at the same region of the screen.
    mutating func resizeGrid(to newGrid: GridDimensions) {
        let old = grid
        guard old != newGrid else { return }
        guard old.columns > 0, old.rows > 0 else {
            grid = newGrid
            return
        }
        let sx = Double(newGrid.columns) / Double(old.columns)
        let sy = Double(newGrid.rows) / Double(old.rows)
        for command in PlacementCommand.allCases {
            let r = rect(for: command)
            let x = min(max(0, Int((Double(r.x) * sx).rounded())), newGrid.columns - 1)
            let y = min(max(0, Int((Double(r.y) * sy).rounded())), newGrid.rows - 1)
            let w = max(1, Int((Double(r.w) * sx).rounded()))
            let h = max(1, Int((Double(r.h) * sy).rounded()))
            rects[command.rawValue] = GridRect(x: x, y: y, w: w, h: h).clamped(to: newGrid)
        }
        grid = newGrid
    }

    mutating func setRect(_ rect: GridRect, for command: PlacementCommand) {
        rects[command.rawValue] = rect
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
