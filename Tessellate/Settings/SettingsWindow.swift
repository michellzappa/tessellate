import AppKit
import HouseKit
import SwiftUI

extension SettingsWindowController {
    /// Commands · General · About. The Commands page is the SwiftUI zone
    /// editor, hosted; the other two are the shared HouseKit pages.
    static func tessellate(coordinator: AppCoordinator) -> SettingsWindowController {
        let store = LayoutStore.shared
        let commands = NSHostingController(rootView: CommandEditorPage().environmentObject(coordinator))
        return SettingsWindowController(appName: "Tessellate", pages: [
            SettingsPage("Commands", symbol: "rectangle.3.group", controller: commands),
            SettingsPage("General", symbol: "gearshape", controller: GeneralPage(
                launchAtLogin: (get: { store.layout.launchAtLogin }, set: { value in store.update { $0.launchAtLogin = value } }),
                showMenuBarIcon: (get: { store.layout.showMenuBarIcon }, set: { value in store.update { $0.showMenuBarIcon = value } }),
                permissions: [.accessibility],
                extras: { form in
                    form.section("iCloud")
                    form.toggle("Sync settings with iCloud", isOn: store.iCloudSyncEnabled) { store.setICloudSyncEnabled($0) }
                    let status = SettingsForm.caption(store.iCloudSyncStatus.label)
                    form.row("Status", status)
                    form.note("Syncs commands, shortcuts, zones, grid, and general preferences through iCloud Key-Value Store. Turn it on on each Mac running Tessellate.")
                    _ = store.$iCloudSyncStatus.receive(on: DispatchQueue.main).sink { status.stringValue = $0.label }
                }
            )),
            SettingsPage("About", symbol: "info.circle", controller: AboutPage(
                appName: "Tessellate",
                tagline: "Hotkey → command → window moved.",
                links: [("GitHub", URL(string: "https://github.com/michellzappa/tessellate")!)]
            ))
        ], size: NSSize(width: 900, height: 640))
    }
}
