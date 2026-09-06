import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectedTab: Tab = .general

    enum Tab: String, CaseIterable, Identifiable {
        case general, activation, commands
        var id: String { rawValue }
        var title: String {
            switch self {
            case .general: return "General"
            case .activation: return "Activation"
            case .commands: return "Commands"
            }
        }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettings()
                .tabItem { Text("General") }
                .tag(Tab.general)
            ActivationSettings()
                .tabItem { Text("Activation") }
                .tag(Tab.activation)
            CommandsSettings()
                .tabItem { Text("Commands") }
                .tag(Tab.commands)
        }
        .frame(width: 560, height: 640)
    }
}

private struct GeneralSettings: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        let store = coordinator.store

        Form {
            Section {
                Toggle("Launch at Login", isOn: Binding(
                    get: { store.layout.launchAtLogin },
                    set: { newValue in store.update { $0.launchAtLogin = newValue } }
                ))
                Toggle("Show menu bar icon", isOn: Binding(
                    get: { store.layout.showMenuBarIcon },
                    set: { newValue in store.update { $0.showMenuBarIcon = newValue } }
                ))
            } header: {
                Text("System")
            }

            Section {
                Picker("Density", selection: Binding(
                    get: { store.layout.gridDensity },
                    set: { newValue in
                        store.update { layout in
                            layout.gridDensity = newValue
                            if newValue.isAutomatic, let screen = NSScreen.main ?? NSScreen.screens.first {
                                layout.resizeGrid(to: GridDimensions.proposed(for: screen, density: newValue))
                            }
                        }
                    }
                )) {
                    ForEach(GridDensity.allCases) { density in
                        Text(density.displayName).tag(density)
                    }
                }
                .pickerStyle(.segmented)

                Text(gridSummary(store.layout))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.layout.gridDensity == .custom {
                    Stepper(value: Binding(
                        get: { store.layout.grid.columns },
                        set: { newValue in
                            store.update {
                                var g = $0.grid
                                g.columns = max(1, min(64, newValue))
                                $0.resizeGrid(to: g)
                            }
                        }
                    ), in: 1...64) {
                        Text("Columns: \(store.layout.grid.columns)")
                    }
                    Stepper(value: Binding(
                        get: { store.layout.grid.rows },
                        set: { newValue in
                            store.update {
                                var g = $0.grid
                                g.rows = max(1, min(64, newValue))
                                $0.resizeGrid(to: g)
                            }
                        }
                    ), in: 1...64) {
                        Text("Rows: \(store.layout.grid.rows)")
                    }
                    Button("Fit to Screen") {
                        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
                        store.update { $0.resizeGrid(to: GridDimensions.proposed(for: screen, density: .balanced)) }
                    }
                }
                GridPreview(
                    grid: store.layout.grid,
                    rects: Dictionary(
                        uniqueKeysWithValues: PlacementCommand.allCases.map { ($0, store.layout.rect(for: $0)) }
                    )
                )
                .padding(.top, 4)
            } header: {
                Text("Grid")
            } footer: {
                Text(store.layout.gridDensity.isAutomatic
                     ? "Sized from your display so every cell is square. Recomputed when the screen changes."
                     : "Custom counts are used as-is; cells may not be square.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                if !coordinator.isAccessibilityGranted {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading) {
                            Text("Accessibility permission required")
                                .font(.headline)
                            Text("Tessellate needs Accessibility access to move and resize windows.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open Settings") {
                            coordinator.openAccessibilitySettings()
                        }
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Accessibility granted")
                        Spacer()
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }

                RunningBinaryRow()
            } header: {
                Text("Permissions")
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func gridSummary(_ layout: TessellateLayout) -> String {
        let grid = layout.grid
        guard let screen = NSScreen.main ?? NSScreen.screens.first else {
            return "\(grid.columns) × \(grid.rows) cells"
        }
        let cell = grid.cellSize(on: screen)
        return "\(grid.columns) × \(grid.rows) cells  ·  \(Int(cell.width.rounded())) × \(Int(cell.height.rounded())) pt each"
    }
}

private struct ActivationSettings: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        let store = coordinator.store

        Form {
            Section {
                HStack {
                    Text("Activation shortcut")
                    Spacer()
                    ShortcutRecorder(
                        keyCode: Binding(
                            get: { store.layout.activationKeyCode },
                            set: { newCode in
                                store.update { $0.activationKeyCode = newCode }
                            }
                        ),
                        modifiers: Binding(
                            get: { store.layout.activationModifiers },
                            set: { newMods in
                                store.update { $0.activationModifiers = newMods }
                            }
                        ),
                        placeholder: "Click to record"
                    )
                    .frame(width: 140, height: 22)
                }
                Text("Default: ⌥ Space. May conflict with Spotlight — change Spotlight's shortcut in System Settings → Keyboard → Keyboard Shortcuts → Spotlight if needed.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Activation")
            }

            Section {
                Text("After activation, press a configured command key to move the focused window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Press Esc to cancel. Placement mode expires automatically after \(Int(coordinator.hotkeyManager.placementTimeout)) seconds.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Behavior")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct CommandsSettings: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(PlacementCommand.allCases) { command in
                    CommandSection(command: command)
                }
            }
            .padding()
        }
    }
}

private struct CommandSection: View {
    let command: PlacementCommand
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        let store = coordinator.store
        let currentBinding = store.layout.bindings[command.rawValue]

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(command.displayName)
                    .font(.headline)
                Spacer()
                Text("Default: \(defaultKeyLabel(command))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Key")
                Spacer()
                ShortcutRecorder(
                    keyCode: Binding(
                        get: { currentBinding?.keyCode ?? 0 },
                        set: { newCode in
                            if newCode == 0 {
                                store.update { $0.setBinding(nil, for: command) }
                            } else {
                                let mods = currentBinding?.modifiers ?? 0
                                store.update { $0.setBinding(CommandBinding(keyCode: newCode, modifiers: mods), for: command) }
                            }
                        }
                    ),
                    modifiers: Binding(
                        get: { currentBinding?.modifiers ?? 0 },
                        set: { newMods in
                            guard let keyCode = currentBinding?.keyCode, keyCode != 0 else { return }
                            store.update { $0.setBinding(CommandBinding(keyCode: keyCode, modifiers: newMods), for: command) }
                        }
                    ),
                    placeholder: "Unbound"
                )
                .frame(width: 110, height: 22)
            }

            GridEditor(
                rect: Binding(
                    get: { store.layout.rect(for: command) },
                    set: { newRect in
                        store.update { $0.setRect(newRect, for: command) }
                    }
                ),
                grid: store.layout.grid
            ) {
                store.update { $0.setRect(command.defaultRect(in: $0.grid), for: command) }
            }
            .frame(maxWidth: 320)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func defaultKeyLabel(_ command: PlacementCommand) -> String {
        switch command {
        case .left: return "←"
        case .right: return "→"
        case .center: return "Space"
        case .maximize: return "↑"
        }
    }
}

private struct GridPreview: View {
    let grid: GridDimensions
    let rects: [PlacementCommand: GridRect]

    var body: some View {
        GeometryReader { geo in
            let cellW = geo.size.width / CGFloat(grid.columns)
            let cellH = geo.size.height / CGFloat(grid.rows)

            ZStack(alignment: .topLeading) {
                Canvas { ctx, size in
                    let shading = GraphicsContext.Shading.color(Color.secondary.opacity(0.3))
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

                ForEach(PlacementCommand.allCases) { command in
                    let r = rects[command] ?? command.defaultRect(in: grid)
                    Rectangle()
                        .fill(zoneColor(command).opacity(0.25))
                        .overlay(
                            Rectangle().strokeBorder(zoneColor(command), lineWidth: 1.5)
                        )
                        .overlay(
                            Text(zoneLabel(command))
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                        )
                        .frame(
                            width: CGFloat(r.w) * cellW,
                            height: CGFloat(r.h) * cellH
                        )
                        .offset(
                            x: CGFloat(r.x) * cellW,
                            y: CGFloat(r.y) * cellH
                        )
                }
            }
        }
        .aspectRatio(CGFloat(grid.columns) / CGFloat(grid.rows), contentMode: .fit)
        .frame(maxHeight: 200)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 4))
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


/// The permission is bound to this exact binary. During development the path
/// changes between builds (and an ad-hoc signature invalidates the grant on
/// every rebuild), so show which executable is actually asking.
private struct RunningBinaryRow: View {
    @State private var copied = false

    private var bundlePath: String { Bundle.main.bundlePath }
    private var executablePath: String { Bundle.main.executablePath ?? "unknown" }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Granted to this executable")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(executablePath)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(3)
                .truncationMode(.middle)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 12) {
                Button(copied ? "Copied" : "Copy path") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(bundlePath, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }
                Button("Reveal in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: bundlePath)])
                }
            }
            .buttonStyle(.link)
            .font(.caption)
        }
        .padding(.top, 4)
    }
}
