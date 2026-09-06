import SwiftUI
import AppKit

@main
struct TessellateApp: App {
    private static let iconName: String = {
        let candidates = [
            "window.horizontal.closed",
            "window.horizontal",
            "macwindow",
            "rectangle.split.2x1"
        ]
        for name in candidates {
            if NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil {
                return name
            }
        }
        return candidates.last ?? "rectangle.split.2x1"
    }()

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var coordinator = AppCoordinator.shared

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu()
                .environmentObject(coordinator)
        } label: {
            Image(systemName: Self.iconName)
        }
        .menuBarExtraStyle(.menu)
    }
}
