import AppKit
import Carbon.HIToolbox

/// Global hotkeys via Carbon's RegisterEventHotKey — the only public API
/// that both observes and *consumes* the key event system-wide. It needs no
/// Accessibility permission and has been stable for decades.
final class HotkeyCenter {
    var onAction: ((SnapAction) -> Void)?

    private var handlerRef: EventHandlerRef?
    private var hotkeyRefs: [EventHotKeyRef] = []
    private var actionsById: [UInt32: SnapAction] = [:]
    private var activeBindings: [SnapAction: Shortcut] = [:]
    private var isPaused = false

    /// 'FITK'
    private static let signature: OSType = 0x4649_544B

    init() {
        installHandler()
    }

    /// Replaces all registrations. Called at startup and whenever bindings
    /// change; with at most ~18 hotkeys a full re-register keeps this simple.
    func register(bindings: [SnapAction: Shortcut]) {
        activeBindings = bindings
        guard !isPaused else { return }
        applyRegistrations()
    }

    /// Temporarily releases every hotkey so the shortcut recorder can
    /// capture combos that are currently bound.
    func pause() {
        isPaused = true
        unregisterAll()
    }

    func resume() {
        isPaused = false
        applyRegistrations()
    }

    private func applyRegistrations() {
        unregisterAll()
        for (index, (action, shortcut)) in activeBindings.enumerated() {
            let id = UInt32(index)
            var ref: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.carbonModifiers,
                hotKeyID,
                GetEventDispatcherTarget(),
                0,
                &ref)
            if status == noErr, let ref {
                hotkeyRefs.append(ref)
                actionsById[id] = action
            }
        }
    }

    private func unregisterAll() {
        hotkeyRefs.forEach { UnregisterEventHotKey($0) }
        hotkeyRefs.removeAll()
        actionsById.removeAll()
    }

    private func installHandler() {
        guard handlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed))
        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID)
            guard status == noErr else { return status }
            let center = Unmanaged<HotkeyCenter>.fromOpaque(userData).takeUnretainedValue()
            guard hotKeyID.signature == HotkeyCenter.signature else {
                return OSStatus(eventNotHandledErr)
            }
            center.fire(id: hotKeyID.id)
            return noErr
        }
        InstallEventHandler(
            GetEventDispatcherTarget(),
            callback,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef)
    }

    private func fire(id: UInt32) {
        guard let action = actionsById[id] else { return }
        onAction?(action)
    }

    deinit {
        unregisterAll()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
    }
}
