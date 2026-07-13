import AppKit
import ApplicationServices
import SwiftUI

/// Explains the Accessibility requirement and waits for the user to grant
/// it, polling once a second and closing itself when access appears.
@MainActor
final class PermissionOnboardingController {
    var onGranted: (() -> Void)?

    private var window: NSWindow?
    private var pollTimer: Timer?

    func showIfNeeded() {
        if AXIsProcessTrusted() {
            onGranted?()
            return
        }
        show()
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: PermissionOnboardingView(
                requestAccess: { Self.requestAccessibilityAccess() }))
            let window = NSWindow(contentViewController: hosting)
            window.title = "Welcome to Fit"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        startPolling()
    }

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard AXIsProcessTrusted() else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.pollTimer?.invalidate()
                self.pollTimer = nil
                self.window?.orderOut(nil)
                self.onGranted?()
            }
        }
    }

    /// Registers Fit with the Accessibility subsystem and opens the
    /// Accessibility pane. macOS suppresses the consent alert for sandboxed
    /// apps, so relying on AXIsProcessTrustedWithOptions alone shows nothing —
    /// the user flips the switch in System Settings themselves; the
    /// trusted-check call is kept because it adds Fit to that list.
    private static func requestAccessibilityAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

private struct PermissionOnboardingView: View {
    let requestAccess: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            FitAppIconView(size: 84)
            Text("Fit needs Accessibility access")
                .font(.title2.bold())
            Text("Fit moves and resizes other apps' windows, which macOS only allows for apps you've approved under Privacy & Security → Accessibility. Fit requests no other permission, and never accesses the network.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open System Settings…", action: requestAccess)
                .keyboardShortcut(.defaultAction)
            Text("Turn on Fit in the Accessibility list — if it isn't listed, add it with + and select Fit from /Applications.\nThis window closes by itself once access is granted.")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(28)
        .frame(width: 440)
    }
}
