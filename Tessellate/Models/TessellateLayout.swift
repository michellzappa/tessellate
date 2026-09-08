import AppKit
import Foundation
import Carbon.HIToolbox

/// A user-editable placement command. The ID is stable so renaming or reordering
/// a command never changes its saved zone or shortcut.
struct PlacementCommand: Codable, Equatable, Hashable, Identifiable {
    let id: String
    var name: String
    var fraction: FractionRect
    var binding: CommandBinding?

    var displayName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Untitled Command"
            : name
    }

    /// The starting zone used by the Reset action. Built-in IDs retain their
    /// familiar defaults after migration; new commands reset to full screen.
    var defaultFractionRect: FractionRect {
        switch id {
        case "left": return FractionRect(x: 0, y: 0, w: 0.5, h: 1)
        case "right": return FractionRect(x: 0.5, y: 0, w: 0.5, h: 1)
        case "center": return FractionRect(x: 0.125, y: 0, w: 0.75, h: 1)
        case "upperHalf": return FractionRect(x: 0, y: 0, w: 1, h: 0.5)
        case "lowerHalf": return FractionRect(x: 0, y: 0.5, w: 1, h: 0.5)
        case "maximize": return FractionRect(x: 0, y: 0, w: 1, h: 1)
        default: return FractionRect(x: 0, y: 0, w: 1, h: 1)
        }
    }

    static let defaults: [PlacementCommand] = [
        PlacementCommand(
            id: "left",
            name: "Left",
            fraction: FractionRect(x: 0, y: 0, w: 0.5, h: 1),
            binding: CommandBinding(keyCode: 123, modifiers: 0)
        ),
        PlacementCommand(
            id: "right",
            name: "Right",
            fraction: FractionRect(x: 0.5, y: 0, w: 0.5, h: 1),
            binding: CommandBinding(keyCode: 124, modifiers: 0)
        ),
        PlacementCommand(
            id: "center",
            name: "Center",
            fraction: FractionRect(x: 0.125, y: 0, w: 0.75, h: 1),
            binding: CommandBinding(keyCode: 49, modifiers: 0)
        ),
        PlacementCommand(
            id: "upperHalf",
            name: "Upper Half",
            fraction: FractionRect(x: 0, y: 0, w: 1, h: 0.5),
            binding: CommandBinding(keyCode: 126, modifiers: 0)
        ),
        PlacementCommand(
            id: "lowerHalf",
            name: "Lower Half",
            fraction: FractionRect(x: 0, y: 0.5, w: 1, h: 0.5),
            binding: CommandBinding(keyCode: 125, modifiers: 0)
        ),
        PlacementCommand(
            id: "maximize",
            name: "Maximize",
            fraction: FractionRect(x: 0, y: 0, w: 1, h: 1),
            binding: CommandBinding(keyCode: 48, modifiers: 0)
        )
    ]
}

/// A placement target as a fraction of the usable screen. This is the stored
/// form: the grid is only a snapping aid for editing, so changing grid size can
/// never move a target. Storing grid cells and rescaling them on every grid
/// change accumulated rounding error until "center" was visibly off-centre.
struct FractionRect: Codable, Equatable, Hashable {
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

struct CommandBinding: Codable, Equatable, Hashable {
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
    var commands: [PlacementCommand]
    var activationKeyCode: UInt16?
    var activationModifiers: UInt
    var showMenuBarIcon: Bool
    var launchAtLogin: Bool

    init() {
        self.grid = GridDimensions()
        self.gridDensity = .balanced
        self.commands = PlacementCommand.defaults
        self.activationKeyCode = 49
        self.activationModifiers = UInt(optionKey)
        self.showMenuBarIcon = true
        self.launchAtLogin = false
    }

    private enum CodingKeys: String, CodingKey {
        case grid, gridDensity, commands, fractions, bindings
        case activationKeyCode, activationModifiers, showMenuBarIcon, launchAtLogin
        case rects  // legacy: grid cells, migrated to fractions on read
    }

    // Layouts written before commands became editable are migrated into the
    // default command list, preserving each saved zone and shortcut.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = TessellateLayout()
        grid = try c.decodeIfPresent(GridDimensions.self, forKey: .grid) ?? fallback.grid
        gridDensity = try c.decodeIfPresent(GridDensity.self, forKey: .gridDensity) ?? fallback.gridDensity
        if let stored = try c.decodeIfPresent([PlacementCommand].self, forKey: .commands) {
            commands = stored
        } else {
            let storedFractions: [String: FractionRect]
            if let fractions = try c.decodeIfPresent([String: FractionRect].self, forKey: .fractions) {
                storedFractions = fractions
            } else if let legacy = try c.decodeIfPresent([String: GridRect].self, forKey: .rects) {
                let legacyGrid = grid
                storedFractions = legacy.mapValues { FractionRect(gridRect: $0, grid: legacyGrid) }
            } else {
                storedFractions = [:]
            }
            let storedBindings = try c.decodeIfPresent([String: CommandBinding].self, forKey: .bindings)
            commands = fallback.commands.map { command in
                PlacementCommand(
                    id: command.id,
                    name: command.name,
                    fraction: storedFractions[command.id]?.clamped() ?? command.fraction,
                    binding: storedBindings.map { $0[command.id] } ?? command.binding
                )
            }
        }
        if let storedActivationKeyCode = try c.decodeIfPresent(UInt16.self, forKey: .activationKeyCode) {
            // Older builds used 0 as the unbound sentinel. Key code 0 is
            // actually the A key, so only migrate the old sentinel here.
            activationKeyCode = storedActivationKeyCode == 0 ? nil : storedActivationKeyCode
        } else {
            activationKeyCode = fallback.activationKeyCode
        }
        activationModifiers = try c.decodeIfPresent(UInt.self, forKey: .activationModifiers) ?? fallback.activationModifiers
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? fallback.showMenuBarIcon
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? fallback.launchAtLogin
    }

    func command(withID id: String) -> PlacementCommand? {
        commands.first { $0.id == id }
    }

    /// Targets are stored as screen fractions, so changing the grid only changes
    /// where they snap when edited — it never moves them.
    mutating func resizeGrid(to newGrid: GridDimensions) {
        grid = newGrid
    }

    mutating func setRect(_ rect: GridRect, for commandID: String) {
        guard let index = commands.firstIndex(where: { $0.id == commandID }) else { return }
        commands[index].fraction = FractionRect(gridRect: rect.clamped(to: grid), grid: grid)
    }

    mutating func setFraction(_ fraction: FractionRect, for commandID: String) {
        guard let index = commands.firstIndex(where: { $0.id == commandID }) else { return }
        commands[index].fraction = fraction.clamped()
    }

    mutating func setBinding(_ binding: CommandBinding?, for commandID: String) {
        guard let index = commands.firstIndex(where: { $0.id == commandID }) else { return }
        commands[index].binding = binding
    }

    mutating func renameCommand(_ commandID: String, to name: String) {
        guard let index = commands.firstIndex(where: { $0.id == commandID }) else { return }
        commands[index].name = name
    }

    mutating func addCommand(id: String, name: String = "New Command") {
        let baseName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "New Command"
            : name.trimmingCharacters(in: .whitespacesAndNewlines)
        var uniqueName = baseName
        var suffix = 2
        while commands.contains(where: { $0.displayName == uniqueName }) {
            uniqueName = "\(baseName) \(suffix)"
            suffix += 1
        }
        commands.append(
            PlacementCommand(
                id: id,
                name: uniqueName,
                fraction: FractionRect(x: 0, y: 0, w: 1, h: 1),
                binding: nil
            )
        )
    }

    mutating func removeCommand(withID id: String) {
        commands.removeAll { $0.id == id }
    }

    mutating func moveCommand(withID id: String, by offset: Int) {
        guard let index = commands.firstIndex(where: { $0.id == id }) else { return }
        let newIndex = index + offset
        guard commands.indices.contains(newIndex) else { return }
        commands.swapAt(index, newIndex)
    }

    // `rects` and the parallel `fractions`/`bindings` maps are decode-only
    // legacy formats. New writes use the editable command list.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(grid, forKey: .grid)
        try c.encode(gridDensity, forKey: .gridDensity)
        try c.encode(commands, forKey: .commands)
        try c.encode(activationKeyCode, forKey: .activationKeyCode)
        try c.encode(activationModifiers, forKey: .activationModifiers)
        try c.encode(showMenuBarIcon, forKey: .showMenuBarIcon)
        try c.encode(launchAtLogin, forKey: .launchAtLogin)
    }
}

enum CarbonKeys {
    static let escape: UInt16 = 53
    static let space: UInt16 = 49
    static let tab: UInt16 = 48
    static let leftArrow: UInt16 = 123
    static let rightArrow: UInt16 = 124
    static let downArrow: UInt16 = 125
    static let upArrow: UInt16 = 126
}
