import AppKit
import HouseKit

/// AppKit entry point: status item + menu, same shape as Cargo and Strata.
@main
@MainActor
final class TessellateApp: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var statusMenu: NSMenu!
    private let coordinator = AppCoordinator.shared
    private let store = LayoutStore.shared
    private var cancellables: [Any] = []

    static func main() {
        let application = NSApplication.shared
        let delegate = TessellateApp()
        application.delegate = delegate
        application.run()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        NSApplication.shared.mainMenu = makeMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = MenuBarPlate.image(glyph: HouseGlyphs.tessellate)
            button.imagePosition = .imageOnly
            button.setAccessibilityLabel("Tessellate menu")
            button.toolTip = "Tessellate"
        }
        statusMenu = NSMenu()
        statusMenu.delegate = self
        statusItem.menu = statusMenu
        rebuildStatusMenu()

        cancellables.append(store.$layout.receive(on: DispatchQueue.main).sink { [weak self] layout in
            self?.statusItem.isVisible = layout.showMenuBarIcon
        })
        coordinator.start()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { coordinator.openSettings() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - Menus

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusMenu else { return }
        rebuildStatusMenu()
    }

    private func rebuildStatusMenu() {
        statusMenu.removeAllItems()
        let header = coordinator.hotkeyManager.isInPlacementMode
            ? "Placement mode — press a command key"
            : (coordinator.isAccessibilityGranted ? "Tessellate" : "Accessibility not granted")
        statusMenu.addItem(StatusMenu.sectionHeader(header))
        for command in store.layout.commands {
            let item = NSMenuItem(title: command.displayName, action: #selector(applyCommand(_:)), keyEquivalent: "")
            if let (key, modifiers) = command.binding?.menuKeyEquivalent {
                item.keyEquivalent = key
                item.keyEquivalentModifierMask = modifiers
            }
            item.representedObject = command.id
            item.target = self
            statusMenu.addItem(item)
        }
        StatusMenu.appendStandardTail(
            to: statusMenu,
            appName: "Tessellate",
            target: self,
            settings: #selector(showSettings(_:)),
            launchAtLogin: #selector(toggleLaunchAtLogin(_:)),
            launchAtLoginEnabled: store.layout.launchAtLogin,
            quit: #selector(quit(_:))
        )
    }

    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()
        let appMenu = NSMenu(title: "Tessellate")
        appMenu.addItem(withTitle: "About Tessellate", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",").target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit Tessellate", action: #selector(quit(_:)), keyEquivalent: "q").target = self
        mainMenu.addItem(withTitle: "Tessellate", action: nil, keyEquivalent: "").submenu = appMenu

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        mainMenu.addItem(withTitle: "Edit", action: nil, keyEquivalent: "").submenu = editMenu

        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        mainMenu.addItem(withTitle: "Window", action: nil, keyEquivalent: "").submenu = windowMenu
        NSApplication.shared.windowsMenu = windowMenu
        return mainMenu
    }

    // MARK: - Actions

    @objc private func applyCommand(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String,
              let command = store.layout.commands.first(where: { $0.id == id })
        else { return }
        coordinator.applyPlacement(command)
    }

    @objc private func showSettings(_ sender: Any?) {
        coordinator.openSettings()
    }

    @objc private func toggleLaunchAtLogin(_ sender: Any?) {
        coordinator.toggleLaunchAtLogin()
    }

    @objc private func quit(_ sender: Any?) {
        coordinator.quit()
    }
}
