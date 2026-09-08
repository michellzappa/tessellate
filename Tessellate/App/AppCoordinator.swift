import AppKit
import Combine
import ServiceManagement
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    static let shared = AppCoordinator()

    let store: LayoutStore
    let hotkeyManager: HotkeyManager

    @Published var isAccessibilityGranted: Bool
    @Published var settingsOpen: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var trustPollTimer: Timer?

    /// The window captured when the activation hotkey fired. Placement acts on
    /// this, not on whatever happens to be focused when the command key lands.
    private var pendingTarget: WindowEngine.FocusedWindow?

    private init() {
        self.store = LayoutStore.shared
        self.isAccessibilityGranted = WindowEngine.isTrusted()

        self.hotkeyManager = HotkeyManager(
            onActivation: {},
            onCommand: { _ in }
        )
    }

    func start() {
        NSLog("Tessellate: starting pid=\(ProcessInfo.processInfo.processIdentifier) exe=\(Bundle.main.executablePath ?? "?")")
        hotkeyManager.onActivation = { [weak self] in
            self?.handleActivation()
        }
        hotkeyManager.onCommand = { [weak self] cmd in
            self?.applyPlacement(cmd)
        }
        hotkeyManager.onExit = { [weak self] in
            self?.pendingTarget = nil
            FocusIndicatorController.shared.hide()
        }
        hotkeyManager.start()
        FocusIndicatorController.shared.warmUp()
        observeLayout()
        observeScreens()
        refreshAutomaticGrid()
        pollAccessibility()
        if !isAccessibilityGranted {
            WindowEngine.requestTrust()
        }
    }

    /// Re-derive an automatic grid when displays change (resolution, arrangement,
    /// docking a laptop).
    private func observeScreens() {
        NotificationCenter.default.publisher(
            for: NSApplication.didChangeScreenParametersNotification
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] _ in
            self?.refreshAutomaticGrid()
        }
        .store(in: &cancellables)
    }

    /// Keeps the grid square-celled for the current screen unless the user has
    /// chosen a custom grid.
    private func refreshAutomaticGrid() {
        let density = store.layout.gridDensity
        guard density.isAutomatic, let screen = NSScreen.main else { return }
        let proposed = GridDimensions.proposed(for: screen, density: density)
        guard proposed != store.layout.grid else { return }
        store.update { $0.resizeGrid(to: proposed) }
    }

    private func observeLayout() {
        store.$layout
            .receive(on: DispatchQueue.main)
            .sink { [weak self] layout in
                self?.syncLaunchAtLogin(layout.launchAtLogin)
            }
            .store(in: &cancellables)
        syncLaunchAtLogin(store.layout.launchAtLogin)
    }

    private func syncLaunchAtLogin(_ desired: Bool) {
        let current = SMAppService.mainApp.status
        let enabled = current == .enabled
        if desired == enabled { return }
        do {
            if desired {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Tessellate: launch at login toggle failed: \(error)")
        }
    }

    private func pollAccessibility() {
        trustPollTimer?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                let trusted = WindowEngine.isTrusted()
                if let self, self.isAccessibilityGranted != trusted {
                    self.isAccessibilityGranted = trusted
                    if trusted { self.hotkeyManager.armTapIfNeeded() }
                }
            }
        }
        trustPollTimer = timer
    }

    private func handleActivation() {
        if !isAccessibilityGranted {
            WindowEngine.requestTrust()
            return
        }
        if hotkeyManager.isInPlacementMode {
            // Second press of the activation hotkey cancels.
            hotkeyManager.exitPlacementMode()
            return
        }
        // Arm the key tap first: the user may already be pressing the command key.
        hotkeyManager.enterPlacementMode()

        let target = WindowEngine.captureFocusedWindow()
        NSLog("Tessellate: captured target=\(target?.appName ?? "none")")
        pendingTarget = target
        if let target {
            FocusIndicatorController.shared.show(target: target)
        } else {
            FocusIndicatorController.shared.showMessage("No window to move", on: NSScreen.main)
        }
    }

    func applyPlacement(_ command: PlacementCommand) {
        guard isAccessibilityGranted else {
            NSLog("Tessellate: applyPlacement — AX not granted")
            return
        }
        // Prefer the window captured at activation; fall back for menu-driven use.
        let target = pendingTarget ?? WindowEngine.captureFocusedWindow()
        pendingTarget = nil
        guard let target else {
            NSLog("Tessellate: applyPlacement — no focused window")
            return
        }
        let cgRect = ScreenGeometry.rect(command.fraction, on: target.screen)
        let ok = WindowEngine.apply(cgRect, to: target.element)
        NSLog("Tessellate: apply \(command.id) (\(command.displayName)) -> \(cgRect) on \(target.appName) ok=\(ok)")
    }

    func openSettings() {
        if let existing = NSApp.windows.first(where: { $0.identifier?.rawValue.contains("settings") == true }) {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        settingsOpen = true
        openSettingsWindowProgrammatically()
    }

    private func openSettingsWindowProgrammatically() {
        let host = NSHostingController(rootView:
            SettingsView()
                .environmentObject(self)
        )
        let window = NSWindow(contentViewController: host)
        window.title = "Tessellate Settings"
        window.setContentSize(NSSize(width: 720, height: 640))
        window.contentMinSize = NSSize(width: 640, height: 560)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.identifier = NSUserInterfaceItemIdentifier("tessellate.settings")
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func toggleLaunchAtLogin() {
        store.layout.launchAtLogin.toggle()
    }

    var isLaunchAtLoginEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func quit() {
        NSApp.terminate(nil)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
