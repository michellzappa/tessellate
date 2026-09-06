import SwiftUI

struct MenuBarMenu: View {
    @EnvironmentObject var coordinator: AppCoordinator

    var body: some View {
        if coordinator.hotkeyManager.isInPlacementMode {
            Text("Placement mode — press a command key")
        }
        ForEach(PlacementCommand.allCases) { command in
            Button(command.displayName) {
                coordinator.applyPlacement(command)
            }
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
