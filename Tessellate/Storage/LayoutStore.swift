import AppKit
import Foundation
import Combine

enum ICloudSyncStatus: Equatable {
    case disabled
    case syncing
    case synced
    case error(String)

    var label: String {
        switch self {
        case .disabled: return "Off"
        case .syncing: return "Syncing…"
        case .synced: return "Synced"
        case .error(let message): return message
        }
    }

    var systemImage: String {
        switch self {
        case .disabled: return "icloud.slash"
        case .syncing: return "arrow.triangle.2.circlepath.icloud"
        case .synced: return "checkmark.icloud"
        case .error: return "exclamationmark.icloud"
        }
    }
}

@MainActor
final class LayoutStore: ObservableObject {
    static let shared = LayoutStore()

    private let defaultsKey = "tessellate.layout.v1"
    private let iCloudEnabledKey = "tessellate.iCloudSyncEnabled"
    private let iCloudLayoutKey = "tessellate.layout.v1"
    private let ubiquitousStore = NSUbiquitousKeyValueStore.default
    private var cancellables = Set<AnyCancellable>()
    private var lastCloudData: Data?

    @Published var layout: TessellateLayout
    @Published private(set) var iCloudSyncEnabled: Bool
    @Published private(set) var iCloudSyncStatus: ICloudSyncStatus

    private init() {
        let defaults = UserDefaults.standard
        let localData = defaults.data(forKey: defaultsKey)
        let localLayout = localData.flatMap(Self.decode)
        let syncEnabled = defaults.object(forKey: iCloudEnabledKey) as? Bool ?? false

        // KVS is deliberately a small settings channel, not the source of
        // truth when sync is off. If sync is already enabled, a cloud copy
        // wins on launch so a second Mac can adopt the existing configuration.
        var initialLayout = localLayout ?? TessellateLayout()
        if syncEnabled {
            ubiquitousStore.synchronize()
            if let cloudData = ubiquitousStore.data(forKey: iCloudLayoutKey),
               let cloudLayout = Self.decode(cloudData) {
                initialLayout = cloudLayout
                lastCloudData = cloudData
            }
        }

        self.layout = initialLayout
        self.iCloudSyncEnabled = syncEnabled
        self.iCloudSyncStatus = syncEnabled ? .syncing : .disabled

        $layout
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] new in
                self?.persist(new)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(
            for: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: ubiquitousStore
        )
        .receive(on: DispatchQueue.main)
        .sink { [weak self] notification in
            self?.applyExternalCloudChange(notification)
        }
        .store(in: &cancellables)

        // Decode-time migrations, including repaired shortcut bindings, should
        // become the user's new on-disk format immediately.
        if localData != nil || syncEnabled {
            persistLocal(layout)
        }
        if syncEnabled {
            if lastCloudData == nil {
                persist(layout)
            } else {
                iCloudSyncStatus = .synced
            }
        }
    }

    private func persist(_ layout: TessellateLayout) {
        persistLocal(layout)
        guard iCloudSyncEnabled,
              let data = try? JSONEncoder().encode(layout),
              data != lastCloudData else { return }

        ubiquitousStore.set(data, forKey: iCloudLayoutKey)
        lastCloudData = data
        iCloudSyncStatus = .synced
        ubiquitousStore.synchronize()
    }

    private func persistLocal(_ layout: TessellateLayout) {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private func applyExternalCloudChange(_ notification: Notification) {
        guard iCloudSyncEnabled else { return }

        let reason = notification.userInfo?[
            NSUbiquitousKeyValueStoreChangeReasonKey
        ] as? Int
        if reason == NSUbiquitousKeyValueStoreQuotaViolationChange {
            iCloudSyncStatus = .error("iCloud storage limit reached")
            return
        }

        guard let changedKeys = notification.userInfo?[
            NSUbiquitousKeyValueStoreChangedKeysKey
        ] as? [String], changedKeys.contains(iCloudLayoutKey) else {
            return
        }
        guard let data = ubiquitousStore.data(forKey: iCloudLayoutKey) else { return }
        guard let cloudLayout = Self.decode(data) else {
            iCloudSyncStatus = .error("The iCloud settings could not be read")
            return
        }

        lastCloudData = data
        if cloudLayout != layout {
            layout = cloudLayout
            persistLocal(cloudLayout)
        }
        iCloudSyncStatus = .synced
    }

    private static func decode(_ data: Data) -> TessellateLayout? {
        try? JSONDecoder().decode(TessellateLayout.self, from: data)
    }

    func setICloudSyncEnabled(_ enabled: Bool) {
        guard enabled != iCloudSyncEnabled else { return }
        iCloudSyncEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: iCloudEnabledKey)

        guard enabled else {
            iCloudSyncStatus = .disabled
            return
        }

        iCloudSyncStatus = .syncing
        ubiquitousStore.synchronize()
        if let cloudData = ubiquitousStore.data(forKey: iCloudLayoutKey),
           let cloudLayout = Self.decode(cloudData) {
            lastCloudData = cloudData
            if cloudLayout != layout {
                layout = cloudLayout
                persistLocal(cloudLayout)
            }
            iCloudSyncStatus = .synced
        } else {
            lastCloudData = nil
            persist(layout)
            iCloudSyncStatus = .synced
        }
    }

    func update(_ block: (inout TessellateLayout) -> Void) {
        var copy = layout
        block(&copy)
        guard copy != layout else { return }
        layout = copy
    }

    func resetRect(_ commandID: String) {
        update {
            guard let command = $0.command(withID: commandID) else { return }
            $0.setFraction(command.defaultFractionRect, for: commandID)
        }
    }

    func resetAll() {
        let defaultLayout = TessellateLayout()
        guard layout != defaultLayout else { return }
        layout = defaultLayout
    }

    func resetGrid() {
        update { layout in
            layout.gridDensity = .balanced
            if let screen = NSScreen.main ?? NSScreen.screens.first {
                layout.resizeGrid(to: GridDimensions.proposed(for: screen, density: .balanced))
            }
        }
    }
}
