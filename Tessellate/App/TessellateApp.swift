import SwiftUI
import AppKit

@main
struct TessellateApp: App {
    /// The three panes on the shared house plate (see MenuBarPlate).
    private static let menuBarIcon: NSImage = MenuBarPlate.image { _ in
        let field = MenuBarPlate.field
        let gap: CGFloat = 0.5
        let leftWidth = ((field.width - gap) / 2 * 2).rounded() / 2
        let rightX = field.minX + leftWidth + gap
        let rightWidth = field.maxX - rightX
        let rightHeight = (field.height - gap) / 2
        MenuBarPlate.mark(NSRect(x: field.minX, y: field.minY, width: leftWidth, height: field.height), alpha: 0.97)
        MenuBarPlate.mark(NSRect(x: rightX, y: field.minY + rightHeight + gap, width: rightWidth, height: rightHeight), alpha: 0.72)
        MenuBarPlate.mark(NSRect(x: rightX, y: field.minY, width: rightWidth, height: rightHeight), alpha: 0.52)
    }

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = AppCoordinator.shared
    @ObservedObject private var store = LayoutStore.shared

    var body: some Scene {
        MenuBarExtra(isInserted: Binding(
            get: { store.layout.showMenuBarIcon },
            set: { newValue in
                // MenuBarExtra may write this binding while SwiftUI is updating
                // the scene. Defer the observable-object mutation until that
                // update has completed.
                Task { @MainActor in
                    guard store.layout.showMenuBarIcon != newValue else { return }
                    store.update { $0.showMenuBarIcon = newValue }
                }
            }
        )) {
            MenuBarMenu()
                .environmentObject(coordinator)
        } label: {
            Image(nsImage: Self.menuBarIcon)
        }
        .menuBarExtraStyle(.menu)
    }
}
