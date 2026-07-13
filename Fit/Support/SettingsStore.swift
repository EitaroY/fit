import Foundation
import Combine

extension Notification.Name {
    /// Posted after any setting changes; AppDelegate re-registers hotkeys
    /// and starts/stops the drag monitor in response.
    static let fitSettingsDidChange = Notification.Name("fitSettingsDidChange")
    /// Posted by the shortcut recorder so HotkeyCenter releases hotkeys
    /// while a combo is being captured.
    static let fitShortcutRecordingBegan = Notification.Name("fitShortcutRecordingBegan")
    static let fitShortcutRecordingEnded = Notification.Name("fitShortcutRecordingEnded")
}

/// All user-facing settings, persisted to UserDefaults. Absence of an action
/// in `shortcuts` means that shortcut is disabled.
@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    private enum Key {
        static let gap = "fit.gap"
        static let edgeSnapEnabled = "fit.edgeSnapEnabled"
        static let cycleSizesEnabled = "fit.cycleSizesEnabled"
        static let combineHalvesToQuarters = "fit.combineHalvesToQuarters"
        static let dragSuppressModifier = "fit.dragSuppressModifier"
        static let shortcuts = "fit.shortcuts.v1"
    }

    private let defaults: UserDefaults

    @Published var gap: Double {
        didSet {
            defaults.set(gap, forKey: Key.gap)
            notifyChange()
        }
    }

    @Published var edgeSnapEnabled: Bool {
        didSet {
            defaults.set(edgeSnapEnabled, forKey: Key.edgeSnapEnabled)
            notifyChange()
        }
    }

    @Published var cycleSizesEnabled: Bool {
        didSet {
            defaults.set(cycleSizesEnabled, forKey: Key.cycleSizesEnabled)
            notifyChange()
        }
    }

    @Published var combineHalvesToQuarters: Bool {
        didSet {
            defaults.set(combineHalvesToQuarters, forKey: Key.combineHalvesToQuarters)
            notifyChange()
        }
    }

    @Published var dragSuppressModifier: DragSuppressModifier {
        didSet {
            defaults.set(dragSuppressModifier.rawValue, forKey: Key.dragSuppressModifier)
            notifyChange()
        }
    }

    @Published private(set) var shortcuts: [SnapAction: Shortcut] {
        didSet {
            persistShortcuts()
            notifyChange()
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.gap: 0.0,
            Key.edgeSnapEnabled: true,
            Key.cycleSizesEnabled: true,
            Key.combineHalvesToQuarters: true,
            Key.dragSuppressModifier: DragSuppressModifier.shift.rawValue,
        ])
        gap = defaults.double(forKey: Key.gap)
        edgeSnapEnabled = defaults.bool(forKey: Key.edgeSnapEnabled)
        cycleSizesEnabled = defaults.bool(forKey: Key.cycleSizesEnabled)
        combineHalvesToQuarters = defaults.bool(forKey: Key.combineHalvesToQuarters)
        dragSuppressModifier = DragSuppressModifier(
            rawValue: defaults.string(forKey: Key.dragSuppressModifier) ?? "") ?? .shift
        shortcuts = Self.loadShortcuts(from: defaults) ?? Shortcut.defaultBindings
    }

    func shortcut(for action: SnapAction) -> Shortcut? {
        shortcuts[action]
    }

    /// Assigns (or clears, with nil) a shortcut. A combo already bound to
    /// another action is silently unbound from it — last assignment wins.
    func setShortcut(_ shortcut: Shortcut?, for action: SnapAction) {
        var updated = shortcuts
        if let shortcut {
            for (other, existing) in updated where other != action && existing.matches(shortcut) {
                updated[other] = nil
            }
            updated[action] = shortcut
        } else {
            updated[action] = nil
        }
        shortcuts = updated
    }

    func resetShortcutsToDefaults() {
        shortcuts = Shortcut.defaultBindings
    }

    // MARK: - Persistence

    private func persistShortcuts() {
        let keyed = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        if let data = try? JSONEncoder().encode(keyed) {
            defaults.set(data, forKey: Key.shortcuts)
        }
    }

    private static func loadShortcuts(from defaults: UserDefaults) -> [SnapAction: Shortcut]? {
        guard let data = defaults.data(forKey: Key.shortcuts),
              let keyed = try? JSONDecoder().decode([String: Shortcut].self, from: data) else {
            return nil
        }
        var result: [SnapAction: Shortcut] = [:]
        for (raw, shortcut) in keyed {
            if let action = SnapAction(rawValue: raw) {
                result[action] = shortcut
            }
        }
        return result
    }

    private func notifyChange() {
        NotificationCenter.default.post(name: .fitSettingsDidChange, object: self)
    }
}
