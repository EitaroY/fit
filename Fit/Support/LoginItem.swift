import Foundation
import ServiceManagement

/// Launch-at-login via SMAppService (macOS 13+). Most reliable when the app
/// runs from /Applications rather than a DerivedData build folder.
enum LoginItem {
    /// Set once the first-launch registration has been attempted, so a user who
    /// turns the toggle off is never re-enrolled on the next launch.
    private static let didApplyDefaultKey = "fit.loginItem.didApplyDefault"

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Opts the app in to launch-at-login on first run. Registration failures
    /// are ignored: the Settings toggle stays the escape hatch.
    static func applyDefaultIfNeeded(defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: didApplyDefaultKey) else { return }
        // Register unless we're already enabled. Don't gate on `.notRegistered`:
        // a freshly installed copy reports `.notFound` until it registers once,
        // and skipping that case leaves the app out of Login Items entirely.
        guard !isEnabled else {
            defaults.set(true, forKey: didApplyDefaultKey)
            return
        }
        do {
            try setEnabled(true)
            defaults.set(true, forKey: didApplyDefaultKey)
        } catch {
            // Leave the flag unset so the next launch tries again.
            NSLog("Fit: launch-at-login registration failed: \(error)")
        }
    }
}
