import AppKit
import Carbon
import CoreGraphics
import Combine

@MainActor
final class HotkeyManager: ObservableObject {
    private let store = LayoutStore.shared
    private var cancellables = Set<AnyCancellable>()

    private var activationRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var inPlacementMode = false
    private var activationGraceUntil: Date?
    private var timeoutItem: DispatchWorkItem?

    let placementTimeout: TimeInterval = 2.0
    var onActivation: () -> Void
    var onCommand: (PlacementCommand) -> Void
    var onExit: () -> Void = {}

    @Published var isInPlacementMode: Bool = false

    init(
        onActivation: @escaping () -> Void,
        onCommand: @escaping (PlacementCommand) -> Void
    ) {
        self.onActivation = onActivation
        self.onCommand = onCommand
    }

    func start() {
        store.$layout
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.reregister()
            }
            .store(in: &cancellables)
        installEventHandler()
        registerActivation()
        // Create the tap up front and leave it disabled. Creating a tap costs
        // milliseconds and only starts delivering after the run loop turns —
        // long enough for a fast command key to slip through to the app below.
        installTap()
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
    }

    deinit {
        if let ref = activationRef {
            UnregisterEventHotKey(ref)
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
    }

    private func installEventHandler() {
        guard eventHandler == nil else { return }
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in
                    NSLog("Tessellate: activation hotkey fired")
                    manager.onActivation()
                }
                return noErr
            },
            1,
            &spec,
            selfPtr,
            &eventHandler
        )
    }

    private func registerActivation() {
        if let ref = activationRef {
            UnregisterEventHotKey(ref)
            activationRef = nil
        }
        let layout = store.layout
        let hotKeyID = EventHotKeyID(signature: HotkeySignature.activation, id: 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(layout.activationKeyCode),
            UInt32(layout.activationModifiers),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            activationRef = ref
            NSLog("Tessellate: activation hotkey registered (keyCode=\(layout.activationKeyCode) mods=\(layout.activationModifiers))")
        } else {
            activationRef = nil
            NSLog("Tessellate: activation hotkey FAILED to register status=\(status)")
        }
    }

    private func reregister() {
        registerActivation()
        if inPlacementMode {
            exitPlacementMode()
        }
    }

    func enterPlacementMode() {
        guard !inPlacementMode else { return }
        inPlacementMode = true
        isInPlacementMode = true
        activationGraceUntil = Date().addingTimeInterval(0.25)
        NSLog("Tessellate: enter placement mode")
        installTap()
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }

        timeoutItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.exitPlacementMode()
            }
        }
        timeoutItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + placementTimeout, execute: item)
    }

    func exitPlacementMode() {
        guard inPlacementMode else { return }
        inPlacementMode = false
        isInPlacementMode = false
        timeoutItem?.cancel()
        timeoutItem = nil
        activationGraceUntil = nil
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        NSLog("Tessellate: exit placement mode")
        onExit()
    }

    private func installTap() {
        guard eventTap == nil else { return }
        let mask = 1 << CGEventType.keyDown.rawValue
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let callback: CGEventTapCallBack = { _, type, event, userData in
            guard let userData else { return Unmanaged.passUnretained(event) }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                Task { @MainActor in manager.reenableTap() }
                return Unmanaged.passUnretained(event)
            }
            let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let flags = event.flags
            let carbonMods = HotkeyManager.carbonModifiers(from: flags)

            Task { @MainActor in
                manager.handleCapturedKey(keyCode: keyCode, carbonMods: carbonMods)
            }
            return nil
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(mask),
            callback: callback,
            userInfo: selfPtr
        ) else {
            NSLog("Tessellate: failed to create event tap (Accessibility may not be granted)")
            return
        }
        NSLog("Tessellate: event tap created")
        eventTap = tap
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = src
        CFRunLoopAddSource(CFRunLoopGetMain(), src, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// The eager tap install fails when Accessibility hasn't been granted yet.
    /// Retry once the grant lands so the first activation is still fast.
    func armTapIfNeeded() {
        guard eventTap == nil else { return }
        installTap()
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: inPlacementMode) }
    }

    func reenableTap() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: inPlacementMode)
    }

    private func removeTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let src = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), src, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handleCapturedKey(keyCode: UInt16, carbonMods: UInt) {
        NSLog("Tessellate: captured key=\(keyCode) mods=\(carbonMods) inPlacement=\(inPlacementMode)")
        guard inPlacementMode else { return }

        // Only swallow a repeat of the *whole* activation combo (key held down).
        // Comparing the key code alone breaks any command bound to the same key
        // as the activation hotkey — e.g. ⌘Space to activate, Space to centre.
        if let until = activationGraceUntil, Date() < until,
           keyCode == store.layout.activationKeyCode,
           carbonMods == store.layout.activationModifiers {
            NSLog("Tessellate: ignored activation combo repeat during grace")
            return
        }

        if keyCode == CarbonKeys.escape {
            exitPlacementMode()
            return
        }

        var matched = false
        defer { if !matched { NSLog("Tessellate: no command bound to key=\(keyCode) mods=\(carbonMods)") } }
        for command in PlacementCommand.allCases {
            guard let binding = store.layout.binding(for: command), binding.keyCode != 0 else { continue }
            if binding.keyCode == keyCode && binding.modifiers == carbonMods {
                matched = true
                NSLog("Tessellate: matched \(command.rawValue)")
                // onCommand first: exitPlacementMode fires onExit, which clears
                // the window captured at activation.
                onCommand(command)
                exitPlacementMode()
                return
            }
        }

    }

    nonisolated static func carbonModifiers(from flags: CGEventFlags) -> UInt {
        var mods: UInt = 0
        if flags.contains(.maskCommand) { mods |= UInt(cmdKey) }
        if flags.contains(.maskAlternate) { mods |= UInt(optionKey) }
        if flags.contains(.maskControl) { mods |= UInt(controlKey) }
        if flags.contains(.maskShift) { mods |= UInt(shiftKey) }
        return mods
    }
}

enum HotkeySignature {
    static let activation: OSType = 0x7473656c
}
