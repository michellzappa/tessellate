import AppKit
import Foundation
import Combine

@MainActor
final class LayoutStore: ObservableObject {
    static let shared = LayoutStore()

    private let defaultsKey = "tessellate.layout.v1"
    private var cancellables = Set<AnyCancellable>()

    @Published var layout: TessellateLayout

    private init() {
        let storedLayout: TessellateLayout? = {
            guard let data = UserDefaults.standard.data(forKey: "tessellate.layout.v1") else { return nil }
            return try? JSONDecoder().decode(TessellateLayout.self, from: data)
        }()
        self.layout = storedLayout ?? TessellateLayout()

        $layout
            .dropFirst()
            .debounce(for: .milliseconds(50), scheduler: DispatchQueue.main)
            .sink { [weak self] new in
                self?.persist(new)
            }
            .store(in: &cancellables)

        // Decode-time migrations, including repaired shortcut bindings, should
        // become the user's new on-disk format immediately.
        if storedLayout != nil {
            persist(layout)
        }
    }

    private func persist(_ layout: TessellateLayout) {
        guard let data = try? JSONEncoder().encode(layout) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
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
