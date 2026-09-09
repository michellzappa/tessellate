import SwiftUI

struct MenuBarMenu: View {
    @EnvironmentObject var coordinator: AppCoordinator
    @ObservedObject private var store = LayoutStore.shared

    var body: some View {
        if coordinator.hotkeyManager.isInPlacementMode {
            Text("Placement mode — press a command key")
        }
        ForEach(store.layout.commands) { command in
            Button(command.displayName) {
                coordinator.applyPlacement(command)
            }
            .keyboardShortcut(ShortcutDisplay.keyboardShortcut(for: command.binding))
        }
        Divider()
        Button("Settings…") {
            coordinator.openSettings()
        }
        .keyboardShortcut(",")
        Toggle("Launch at Login", isOn: Binding(
            get: { coordinator.store.layout.launchAtLogin },
            set: { newValue in
                coordinator.store.update { $0.launchAtLogin = newValue }
            }
        ))
        Divider()
        Button("Quit Tessellate") {
            coordinator.quit()
        }
        .keyboardShortcut("q")
    }
}
