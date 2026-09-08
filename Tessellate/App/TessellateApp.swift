import SwiftUI
import AppKit

@main
struct TessellateApp: App {
    /// The real app icon, scaled down for the menu bar — a recognizable mark
    /// beats a generic SF Symbol standing in for "window".
    private static let menuBarIcon: NSImage = {
        let source = NSApp.applicationIconImage ?? NSImage(size: NSSize(width: 18, height: 18))
        let size = NSSize(width: 18, height: 18)
        let resized = NSImage(size: size)
        resized.lockFocus()
        source.draw(
            in: NSRect(origin: .zero, size: size),
            from: .zero,
            operation: .sourceOver,
            fraction: 1
        )
        resized.unlockFocus()
        // Keep it in full color rather than template-tinted monochrome — it's
        // meant to read as the app icon, not as a system-style glyph.
        resized.isTemplate = false
        return resized
    }()

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
