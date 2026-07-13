import AppKit

/// Tracks the last active application other than Fit itself, so snap actions
/// triggered from the status menu or settings window (which make Fit the
/// frontmost app) still target the user's window.
final class FrontmostAppTracker {
    private(set) var lastExternalPid: pid_t?
    private var observer: NSObjectProtocol?

    init() {
        if let frontmost = NSWorkspace.shared.frontmostApplication,
           frontmost.processIdentifier != ProcessInfo.processInfo.processIdentifier {
            lastExternalPid = frontmost.processIdentifier
        }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            self?.lastExternalPid = app.processIdentifier
        }
    }

    /// The pid snap actions should target right now: the frontmost app,
    /// unless that is Fit, in which case the previously active app.
    var targetPid: pid_t? {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return lastExternalPid }
        if frontmost.processIdentifier == ProcessInfo.processInfo.processIdentifier {
            return lastExternalPid
        }
        return frontmost.processIdentifier
    }

    deinit {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }
}
