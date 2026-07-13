import AppKit
import ApplicationServices

/// The menu bar presence: every snap action, settings, and quit. Key
/// equivalents shown in the menu mirror the current bindings (display only —
/// the global hotkeys come from HotkeyCenter).
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let executor: SnapExecutor
    private let settings: SettingsStore
    private let openSettings: () -> Void
    private let openOnboarding: () -> Void

    init(
        executor: SnapExecutor,
        settings: SettingsStore,
        openSettings: @escaping () -> Void,
        openOnboarding: @escaping () -> Void
    ) {
        self.executor = executor
        self.settings = settings
        self.openSettings = openSettings
        self.openOnboarding = openOnboarding
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(named: "MenuBarIcon")
            image?.isTemplate = true
            image?.accessibilityDescription = "Fit"
            button.image = image
            button.toolTip = "Fit — window snapping"
        }
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
    }

    // Rebuilt on every open: cheap, and keeps permission state and shortcut
    // hints current without bookkeeping.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if !AXIsProcessTrusted() {
            let warning = NSMenuItem(
                title: "Grant Accessibility Access…",
                action: #selector(showOnboarding),
                keyEquivalent: "")
            warning.target = self
            warning.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: nil)
            menu.addItem(warning)
            menu.addItem(.separator())
        }

        for group in SnapAction.menuGroups {
            for action in group.actions {
                menu.addItem(item(for: action))
            }
            menu.addItem(.separator())
        }

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: "About Fit", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit Fit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func item(for action: SnapAction) -> NSMenuItem {
        let item = NSMenuItem(title: action.title, action: #selector(performSnap(_:)), keyEquivalent: "")
        item.target = self
        item.representedObject = action.rawValue
        if let shortcut = settings.shortcut(for: action),
           let equivalent = Self.keyEquivalent(for: shortcut.keyCode, label: shortcut.keyLabel) {
            item.keyEquivalent = equivalent
            item.keyEquivalentModifierMask = Self.modifierMask(fromCarbon: shortcut.carbonModifiers)
        }
        return item
    }

    @objc private func performSnap(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String,
              let action = SnapAction(rawValue: raw) else { return }
        executor.perform(action)
    }

    @objc private func showSettings() { openSettings() }
    @objc private func showOnboarding() { openOnboarding() }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationIcon: NSApp.applicationIconImage as Any
        ])
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: - Key equivalent display

    private static func keyEquivalent(for keyCode: UInt32, label: String) -> String? {
        switch keyCode {
        case KeyCode.leftArrow: return String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case KeyCode.rightArrow: return String(UnicodeScalar(NSRightArrowFunctionKey)!)
        case KeyCode.upArrow: return String(UnicodeScalar(NSUpArrowFunctionKey)!)
        case KeyCode.downArrow: return String(UnicodeScalar(NSDownArrowFunctionKey)!)
        case KeyCode.returnKey: return "\r"
        case KeyCode.delete: return "\u{8}"
        default:
            let lowered = label.lowercased()
            return lowered.count == 1 ? lowered : nil
        }
    }

    private static func modifierMask(fromCarbon carbon: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbon & CarbonModifier.command != 0 { flags.insert(.command) }
        if carbon & CarbonModifier.shift != 0 { flags.insert(.shift) }
        if carbon & CarbonModifier.option != 0 { flags.insert(.option) }
        if carbon & CarbonModifier.control != 0 { flags.insert(.control) }
        return flags
    }
}
