import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = SettingsStore.shared
    private let tracker = FrontmostAppTracker()
    private var executor: SnapExecutor!
    private var hotkeys: HotkeyCenter!
    private var dragMonitor: DragSnapMonitor!
    private var statusItem: StatusItemController!
    private let settingsWindow = SettingsWindowController()
    private let onboarding = PermissionOnboardingController()
    private var enginesRunning = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        LoginItem.applyDefaultIfNeeded()

        executor = SnapExecutor(settings: settings, tracker: tracker)
        hotkeys = HotkeyCenter()
        dragMonitor = DragSnapMonitor(executor: executor, settings: settings)

        hotkeys.onAction = { [weak self] action in
            // Carbon dispatches on the main run loop; hop explicitly to stay
            // correct if that ever changes.
            DispatchQueue.main.async { self?.executor.perform(action) }
        }
        executor.onPermissionMissing = { [weak self] in
            self?.onboarding.show()
        }
        onboarding.onGranted = { [weak self] in
            self?.startEngines()
        }

        statusItem = StatusItemController(
            executor: executor,
            settings: settings,
            openSettings: { [weak self] in
                guard let self else { return }
                self.settingsWindow.show(store: self.settings)
            },
            openOnboarding: { [weak self] in
                self?.onboarding.show()
            })

        observeNotifications()

        if AXIsProcessTrusted() {
            startEngines()
        } else if !UserDefaults.standard.bool(forKey: "FitSuppressOnboarding") {
            onboarding.show()
        }
    }

    private func startEngines() {
        enginesRunning = true
        applyConfiguration()
    }

    /// (Re)applies settings to the input engines. Safe to call repeatedly.
    private func applyConfiguration() {
        guard enginesRunning else { return }
        hotkeys.register(bindings: settings.shortcuts)
        if settings.edgeSnapEnabled {
            dragMonitor.start()
        } else {
            dragMonitor.stop()
        }
    }

    private func observeNotifications() {
        let center = NotificationCenter.default
        center.addObserver(forName: .fitSettingsDidChange, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.applyConfiguration() }
        }
        center.addObserver(forName: .fitShortcutRecordingBegan, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.hotkeys.pause() }
        }
        center.addObserver(forName: .fitShortcutRecordingEnded, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in self?.hotkeys.resume() }
        }
    }
}
