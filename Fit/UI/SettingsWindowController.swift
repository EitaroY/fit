import AppKit
import SwiftUI

/// Hosts the SwiftUI settings in a reusable window. Fit is an accessory app
/// (no Dock icon), so showing settings explicitly activates the app.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(store: SettingsStore) {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(store: store))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Fit Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
