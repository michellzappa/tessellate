import SwiftUI

/// One scrolling page instead of three tabs.
///
/// Each command is edited as one decision: choose it in the left column, then
/// adjust its shortcut and target region together in the detail column.
struct SettingsView: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @State private var selectionID: String? = "left"

    var body: some View {
        Form {
            if !coordinator.isAccessibilityGranted {
                Section {
                    AccessibilityBanner()
                }
            }

            CommandsSection(selectionID: $selectionID)
            GeneralSection()
            AboutSection()
        }
        .formStyle(.grouped)
        .frame(
            minWidth: 640,
            idealWidth: 720,
            maxWidth: .infinity,
            minHeight: 560,
            idealHeight: 640,
            maxHeight: .infinity
        )
    }
}

// MARK: - Commands

private struct CommandsSection: View {
    @Binding var selectionID: String?
    @ObservedObject private var store = LayoutStore.shared
    @State private var editingCommandID: String?
    @FocusState private var focusedCommandID: String?

    private var commands: [PlacementCommand] { store.layout.commands }

    private var selectedCommand: PlacementCommand? {
        guard let selectedID else { return commands.first }
        return commands.first { $0.id == selectedID } ?? commands.first
    }

    private var selectedID: String? {
        guard let selectionID, commands.contains(where: { $0.id == selectionID }) else {
            return commands.first?.id
        }
        return selectionID
    }

    var body: some View {
        Section {
            LabeledContent("Activate") {
                ShortcutPicker(
                    binding: activationBinding,
                    placeholder: "Record"
                )
                .frame(width: 190, height: 24, alignment: .leading)
            }

            Divider()

            if let command = selectedCommand {
                HStack(alignment: .top, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Command")
                            .font(.headline)

                        VStack(spacing: 2) {
                            ForEach(commands) { command in
                                HStack(spacing: 8) {
                                    Button {
                                        selectionID = command.id
                                    } label: {
                                        Image(systemName: command.id == selectedID
                                              ? "largecircle.fill.circle"
                                              : "circle")
                                    }
                                    .buttonStyle(.plain)

                                    if editingCommandID == command.id {
                                        TextField("", text: nameBinding(for: command.id))
                                            .textFieldStyle(.plain)
                                            .focused($focusedCommandID, equals: command.id)
                                            .onTapGesture { selectionID = command.id }
                                    } else {
                                        Text(command.displayName)
                                            .lineLimit(1)
                                            .onTapGesture { selectionID = command.id }
                                    }

                                    Spacer(minLength: 0)

                                    Button {
                                        if editingCommandID == command.id {
                                            finishEditingName()
                                        } else {
                                            beginEditingName(command.id)
                                        }
                                    } label: {
                                        Image(systemName: editingCommandID == command.id ? "checkmark" : "pencil")
                                    }
                                    .buttonStyle(.borderless)
                                    .help(editingCommandID == command.id ? "Finish editing name" : "Edit command name")
                                }
                                .contentShape(Rectangle())
                                .padding(.vertical, 5)
                                .foregroundStyle(command.id == selectedID ? Color.accentColor : .primary)
                                .accessibilityElement(children: .combine)
                                .accessibilityLabel(command.displayName)
                                .accessibilityAddTraits(command.id == selectedID ? .isSelected : [])
                                .contextMenu {
                                    Button("Move Up") { move(command.id, by: -1) }
                                        .disabled(!canMove(command.id, by: -1))
                                    Button("Move Down") { move(command.id, by: 1) }
                                        .disabled(!canMove(command.id, by: 1))
                                    Divider()
                                    Button("Delete Command", role: .destructive) {
                                        delete(command.id)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            Button {
                                addCommand()
                            } label: {
                                Label("Add", systemImage: "plus")
                            }
                            .buttonStyle(.borderless)

                            Button {
                                if let selectedID { move(selectedID, by: -1) }
                            } label: {
                                Image(systemName: "chevron.up")
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedID.map { !canMove($0, by: -1) } ?? true)
                            .help("Move up")

                            Button {
                                if let selectedID { move(selectedID, by: 1) }
                            } label: {
                                Image(systemName: "chevron.down")
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedID.map { !canMove($0, by: 1) } ?? true)
                            .help("Move down")

                            Button(role: .destructive) {
                                if let selectedID { delete(selectedID) }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                            .disabled(selectedID == nil)
                            .help("Delete command")
                        }
                        .padding(.top, 6)
                    }
                    .frame(width: 180, alignment: .leading)

                    Divider()

                    VStack(alignment: .leading, spacing: 10) {
                        LabeledContent("Shortcut") {
                            ShortcutPicker(
                                binding: commandBinding(command.id),
                                placeholder: "Unbound"
                            )
                            .frame(width: 190, height: 24, alignment: .leading)
                        }

                        ZoneCanvas(
                            grid: store.layout.grid,
                            commands: commands,
                            selection: command,
                            onEdit: { newRect in
                                store.update { $0.setRect(newRect, for: command.id) }
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: 260)

                        GridControls()

                        HStack {
                            Text(sizeSummary(for: command))
                                .font(.callout)
                                .monospacedDigit()
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Reset") {
                                store.update { $0.setFraction(command.defaultFractionRect, for: command.id) }
                            }
                            .disabled(isDefault(command))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack {
                    Text("No commands yet")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Add command") { addCommand() }
                }
            }
        } header: {
            Text("Commands")
        } footer: {
            Text("Choose a command to edit its name, shortcut, and zone. Drag on the map to set where **\(selectedCommand?.displayName ?? "the command")** puts a window. Reorder with the arrows or the context menu. Esc cancels placement mode, and Delete clears a shortcut.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func nameBinding(for commandID: String) -> Binding<String> {
        Binding(
            get: { store.layout.command(withID: commandID)?.name ?? "" },
            set: { newName in
                store.update { $0.renameCommand(commandID, to: newName) }
            }
        )
    }

    private var activationBinding: Binding<CommandBinding?> {
        Binding(
            get: {
                store.layout.activationKeyCode.map {
                    CommandBinding(keyCode: $0, modifiers: store.layout.activationModifiers)
                }
            },
            set: { newBinding in
                store.update {
                    $0.activationKeyCode = newBinding?.keyCode
                    $0.activationModifiers = newBinding?.modifiers ?? 0
                }
            }
        )
    }

    private func beginEditingName(_ commandID: String) {
        selectionID = commandID
        editingCommandID = commandID
        DispatchQueue.main.async {
            focusedCommandID = commandID
        }
    }

    private func finishEditingName() {
        focusedCommandID = nil
        editingCommandID = nil
    }

    private func addCommand() {
        let id = UUID().uuidString
        store.update { $0.addCommand(id: id) }
        beginEditingName(id)
    }

    private func delete(_ commandID: String) {
        guard let index = commands.firstIndex(where: { $0.id == commandID }) else { return }
        let fallbackIndex = index + 1 < commands.count ? index + 1 : index - 1
        let fallbackID = commands.indices.contains(fallbackIndex) ? commands[fallbackIndex].id : nil
        store.update { $0.removeCommand(withID: commandID) }
        if editingCommandID == commandID {
            finishEditingName()
        }
        selectionID = fallbackID
    }

    private func canMove(_ commandID: String, by offset: Int) -> Bool {
        guard let index = commands.firstIndex(where: { $0.id == commandID }) else { return false }
        return commands.indices.contains(index + offset)
    }

    private func move(_ commandID: String, by offset: Int) {
        guard canMove(commandID, by: offset) else { return }
        store.update { $0.moveCommand(withID: commandID, by: offset) }
    }

    private func isDefault(_ command: PlacementCommand) -> Bool {
        command.fraction == command.defaultFractionRect.clamped()
    }

    private func sizeSummary(for command: PlacementCommand) -> String {
        let f = command.fraction.clamped()
        let percent = "\(Int((f.w * 100).rounded()))% × \(Int((f.h * 100).rounded()))% of screen"
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return percent }
        let usable = ScreenGeometry.usableFrame(for: screen)
        let w = Int((f.w * usable.width).rounded())
        let h = Int((f.h * usable.height).rounded())
        return "\(percent)  ·  \(w) × \(h) pt"
    }

    private func commandBinding(_ commandID: String) -> Binding<CommandBinding?> {
        Binding(
            get: { store.layout.command(withID: commandID)?.binding },
            set: { newBinding in
                store.update { $0.setBinding(newBinding, for: commandID) }
            }
        )
    }
}

private struct GridControls: View {
    @ObservedObject private var store = LayoutStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Grid density", selection: densityBinding) {
                ForEach(GridDensity.allCases) { density in
                    Text(density.displayName).tag(density)
                }
            }
            .pickerStyle(.segmented)

            if store.layout.gridDensity == .custom {
                HStack(spacing: 16) {
                    Stepper(value: columnsBinding, in: GridDimensions.bounds) {
                        LabeledContent("Columns") {
                            Text("\(store.layout.grid.columns)").monospacedDigit()
                        }
                    }
                    Stepper(value: rowsBinding, in: GridDimensions.bounds) {
                        LabeledContent("Rows") {
                            Text("\(store.layout.grid.rows)").monospacedDigit()
                        }
                    }
                }
            }

            let grid = store.layout.grid
            let size = "\(grid.columns) × \(grid.rows)"
            Text(store.layout.gridDensity.isAutomatic
                 ? "\(size), sized from your display so cells stay square."
                 : "\(size), used as-is. Cells may not be square.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var densityBinding: Binding<GridDensity> {
        Binding(
            get: { store.layout.gridDensity },
            set: { newValue in
                store.update { layout in
                    layout.gridDensity = newValue
                    if newValue.isAutomatic, let screen = NSScreen.main ?? NSScreen.screens.first {
                        layout.resizeGrid(to: GridDimensions.proposed(for: screen, density: newValue))
                    }
                }
            }
        )
    }

    private var columnsBinding: Binding<Int> {
        Binding(
            get: { store.layout.grid.columns },
            set: { newValue in
                store.update {
                    var grid = $0.grid
                    grid.columns = min(max(newValue, GridDimensions.bounds.lowerBound), GridDimensions.bounds.upperBound)
                    $0.resizeGrid(to: grid)
                }
            }
        )
    }

    private var rowsBinding: Binding<Int> {
        Binding(
            get: { store.layout.grid.rows },
            set: { newValue in
                store.update {
                    var grid = $0.grid
                    grid.rows = min(max(newValue, GridDimensions.bounds.lowerBound), GridDimensions.bounds.upperBound)
                    $0.resizeGrid(to: grid)
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

        } header: {
            Text("General")
        }
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
