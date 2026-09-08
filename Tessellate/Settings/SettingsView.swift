import SwiftUI

/// One scrolling page instead of three tabs.
///
/// The old layout split things that are really one decision: a command's target
/// region lived on the Commands tab, its key on the same tab but in a separate
/// card, and a read-only picture of all four regions on General. Here the
/// regions share a single canvas, the keys share a single list, and everything
/// else is one short General section.
struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var store = LayoutStore.shared
    @State private var selection: PlacementCommand = .left

    var body: some View {
        Form {
            if !coordinator.isAccessibilityGranted {
                Section {
                    AccessibilityBanner()
                }
            }

            ZonesSection(selection: $selection)
            KeysSection(selection: $selection)
            GeneralSection()
            AboutSection()
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 680)
    }
}

// MARK: - Zones

private struct ZonesSection: View {
    @Binding var selection: PlacementCommand
    @ObservedObject private var store = LayoutStore.shared

    var body: some View {
        Section {
            Picker("Zone", selection: $selection) {
                ForEach(PlacementCommand.allCases) { command in
                    Text(command.displayName).tag(command)
                }
            }
            .pickerStyle(.inline)
            .labelsHidden()

            ZoneCanvas(
                grid: store.layout.grid,
                rects: Dictionary(
                    uniqueKeysWithValues: PlacementCommand.allCases.map {
                        ($0, store.layout.rect(for: $0))
                    }
                ),
                selection: selection,
                onEdit: { newRect in
                    store.update { $0.setRect(newRect, for: selection) }
                }
            )
            .frame(maxHeight: 260)

            HStack {
                Text(sizeSummary)
                    .font(.callout)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Reset \(selection.displayName)") {
                    store.update { $0.setFraction(selection.defaultFractionRect, for: selection) }
                }
                .disabled(isDefault)
            }
        } header: {
            Text("Zones")
        } footer: {
            Text("Drag on the map to set where **\(selection.displayName)** puts a window. The other zones are outlined for reference.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var isDefault: Bool {
        store.layout.fraction(for: selection) == selection.defaultFractionRect.clamped()
    }

    private var sizeSummary: String {
        let f = store.layout.fraction(for: selection)
        let percent = "\(Int((f.w * 100).rounded()))% × \(Int((f.h * 100).rounded()))% of screen"
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return percent }
        let usable = ScreenGeometry.usableFrame(for: screen)
        let w = Int((f.w * usable.width).rounded())
        let h = Int((f.h * usable.height).rounded())
        return "\(percent)  ·  \(w) × \(h) pt"
    }
}


// MARK: - Keys

private struct KeysSection: View {
    @Binding var selection: PlacementCommand
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var store = LayoutStore.shared

    var body: some View {
        Section {
            LabeledContent("Activate") {
                ShortcutRecorder(
                    keyCode: Binding(
                        get: { store.layout.activationKeyCode },
                        set: { newCode in store.update { $0.activationKeyCode = newCode } }
                    ),
                    modifiers: Binding(
                        get: { store.layout.activationModifiers },
                        set: { newMods in store.update { $0.activationModifiers = newMods } }
                    ),
                    placeholder: "Record"
                )
                .frame(width: 116, height: 24)
            }

            ForEach(PlacementCommand.allCases) { command in
                LabeledContent {
                    ShortcutRecorder(
                        keyCode: keyCodeBinding(command),
                        modifiers: modifiersBinding(command),
                        placeholder: "Unbound"
                    )
                    .frame(width: 116, height: 24)
                } label: {
                    Text(command.displayName)
                        .foregroundStyle(command == selection ? Color.accentColor : .primary)
                }
                .contentShape(Rectangle())
                .onTapGesture { selection = command }
            }
        } header: {
            Text("Keys")
        } footer: {
            Text("Press the activation key, then a zone key — ⌥Space then ← by default. Esc cancels, and placement mode ends by itself after \(Int(coordinator.hotkeyManager.placementTimeout)) seconds. Delete clears a binding.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func keyCodeBinding(_ command: PlacementCommand) -> Binding<UInt16> {
        Binding(
            get: { store.layout.binding(for: command)?.keyCode ?? 0 },
            set: { newCode in
                store.update {
                    if newCode == 0 {
                        $0.setBinding(nil, for: command)
                    } else {
                        let mods = $0.binding(for: command)?.modifiers ?? 0
                        $0.setBinding(CommandBinding(keyCode: newCode, modifiers: mods), for: command)
                    }
                }
            }
        )
    }

    private func modifiersBinding(_ command: PlacementCommand) -> Binding<UInt> {
        Binding(
            get: { store.layout.binding(for: command)?.modifiers ?? 0 },
            set: { newMods in
                store.update {
                    guard let keyCode = $0.binding(for: command)?.keyCode, keyCode != 0 else { return }
                    $0.setBinding(CommandBinding(keyCode: keyCode, modifiers: newMods), for: command)
                }
            }
        )
    }
}

// MARK: - General

private struct GeneralSection: View {
    @ObservedObject private var store = LayoutStore.shared

    var body: some View {
        Section {
            Toggle("Launch at login", isOn: Binding(
                get: { store.layout.launchAtLogin },
                set: { newValue in store.update { $0.launchAtLogin = newValue } }
            ))

            Toggle("Show menu bar icon", isOn: Binding(
                get: { store.layout.showMenuBarIcon },
                set: { newValue in store.update { $0.showMenuBarIcon = newValue } }
            ))
            if !store.layout.showMenuBarIcon {
                Text("With the icon hidden, reopen Tessellate from Spotlight to get back to Settings.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Picker("Grid", selection: Binding(
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

            if store.layout.gridDensity == .custom {
                Stepper(value: columnsBinding, in: GridDimensions.bounds) {
                    LabeledContent("Columns") { Text("\(store.layout.grid.columns)").monospacedDigit() }
                }
                Stepper(value: rowsBinding, in: GridDimensions.bounds) {
                    LabeledContent("Rows") { Text("\(store.layout.grid.rows)").monospacedDigit() }
                }
            }
        } header: {
            Text("General")
        } footer: {
            Text(gridFooter)
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var columnsBinding: Binding<Int> {
        Binding(
            get: { store.layout.grid.columns },
            set: { newValue in
                store.update {
                    var g = $0.grid
                    g.columns = min(max(newValue, GridDimensions.bounds.lowerBound), GridDimensions.bounds.upperBound)
                    $0.resizeGrid(to: g)
                }
            }
        )
    }

    private var rowsBinding: Binding<Int> {
        Binding(
            get: { store.layout.grid.rows },
            set: { newValue in
                store.update {
                    var g = $0.grid
                    g.rows = min(max(newValue, GridDimensions.bounds.lowerBound), GridDimensions.bounds.upperBound)
                    $0.resizeGrid(to: g)
                }
            }
        )
    }

    private var gridFooter: String {
        let grid = store.layout.grid
        let size = "\(grid.columns) × \(grid.rows)"
        return store.layout.gridDensity.isAutomatic
            ? "\(size), sized from your display so cells stay square. The grid only decides where dragging snaps — it never moves a zone you already set."
            : "\(size), used as-is. Cells may not be square."
    }
}

// MARK: - About

private struct AboutSection: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var copied = false

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        Section {
            LabeledContent("Accessibility") {
                if coordinator.isAccessibilityGranted {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .labelStyle(.titleAndIcon)
                        .foregroundStyle(.green)
                } else {
                    Button("Open System Settings") { coordinator.openAccessibilitySettings() }
                }
            }
            LabeledContent("Version", value: version)

            // The Accessibility grant binds to one exact binary, and during
            // development the Xcode build and the command-line build are
            // different files — so show which one is actually asking.
            DisclosureGroup("Running binary") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Bundle.main.executablePath ?? "unknown")
                        .font(.system(size: 11, design: .monospaced))
                        .textSelection(.enabled)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 12) {
                        Button(copied ? "Copied" : "Copy path") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(Bundle.main.bundlePath, forType: .string)
                            copied = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                        }
                        Button("Reveal in Finder") {
                            NSWorkspace.shared.activateFileViewerSelecting([
                                URL(fileURLWithPath: Bundle.main.bundlePath)
                            ])
                        }
                    }
                    .buttonStyle(.link)
                    .font(.callout)
                }
                .padding(.top, 4)
            }

            Button("Quit Tessellate") { coordinator.quit() }
        }
    }
}

private struct AccessibilityBanner: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility access required")
                    .font(.headline)
                Text("Tessellate can't move windows until macOS grants it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Open…") { coordinator.openAccessibilitySettings() }
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 4)
    }
}
