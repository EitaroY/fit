import AppKit

/// Watches global mouse events and, when the user drags a window to a screen
/// edge, shows a snap preview and applies it on release.
///
/// Detection is deliberately lazy and cheap:
/// - Plain clicks never touch the AX API (the hit test waits for the first
///   drag event).
/// - "Is a window being dragged?" is answered by observing whether the
///   window under the pointer actually moves, so in-window drags (text
///   selection, sliders) are ignored.
/// - AX reads are throttled to ~30 Hz.
@MainActor
final class DragSnapMonitor {
    private let executor: SnapExecutor
    private let settings: SettingsStore
    private let overlay = SnapOverlayController()
    private var monitors: [Any] = []

    private enum State {
        case idle
        /// Mouse is down; no hit test performed yet.
        case armed
        /// Not a window drag (no window under pointer); ignore until mouse up.
        case rejected
        case tracking(Tracking)
    }

    private struct Tracking {
        let window: AXWindow
        let initialOrigin: CGPoint
        var confirmedWindowDrag = false
        var lastSampleTime: TimeInterval = 0
        var currentAction: SnapAction?
        var currentScreen: NSScreen?
    }

    private var state: State = .idle

    private static let sampleInterval: TimeInterval = 1.0 / 30.0
    private static let dragConfirmDistance: CGFloat = 4

    init(executor: SnapExecutor, settings: SettingsStore) {
        self.executor = executor
        self.settings = settings
    }

    var isRunning: Bool { !monitors.isEmpty }

    func start() {
        guard monitors.isEmpty else { return }
        monitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
                self?.state = .armed
            },
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
                self?.handleDrag(event)
            },
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseUp) { [weak self] event in
                self?.handleUp(event)
            },
        ].compactMap { $0 }
    }

    func stop() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
        overlay.hide()
        state = .idle
    }

    private func handleDrag(_ event: NSEvent) {
        switch state {
        case .idle, .rejected:
            return
        case .armed:
            let pointer = ScreenGeometry.cgMouseLocation()
            guard let window = WindowFinder.window(atCG: pointer),
                  window.isStandard,
                  window.isMovable,
                  let frame = window.frame else {
                state = .rejected
                return
            }
            state = .tracking(Tracking(window: window, initialOrigin: frame.origin))
        case .tracking(var tracking):
            guard event.timestamp - tracking.lastSampleTime >= Self.sampleInterval else { return }
            tracking.lastSampleTime = event.timestamp

            if !tracking.confirmedWindowDrag {
                guard let origin = tracking.window.frame?.origin else {
                    state = .rejected
                    overlay.hide()
                    return
                }
                let moved = abs(origin.x - tracking.initialOrigin.x) + abs(origin.y - tracking.initialOrigin.y)
                if moved > Self.dragConfirmDistance {
                    tracking.confirmedWindowDrag = true
                }
            }

            if tracking.confirmedWindowDrag {
                if isSuppressionHeld(event) {
                    tracking.currentAction = nil
                    overlay.hide()
                } else {
                    updateZone(&tracking)
                }
            }
            state = .tracking(tracking)
        }
    }

    /// True while the user holds the configured "don't snap" modifier.
    private func isSuppressionHeld(_ event: NSEvent) -> Bool {
        guard let flag = settings.dragSuppressModifier.eventFlag else { return false }
        return event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(flag)
    }

    private func updateZone(_ tracking: inout Tracking) {
        let pointer = ScreenGeometry.cgMouseLocation()
        guard let screen = ScreenGeometry.screen(containingCG: pointer) ?? NSScreen.main else { return }
        let visibleFrame = ScreenGeometry.cgVisibleFrame(of: screen)
        let action = EdgeZone.action(for: pointer, inVisibleFrame: visibleFrame)

        tracking.currentScreen = screen
        guard action != tracking.currentAction else { return }
        tracking.currentAction = action

        if let action,
           let target = LayoutCalculator(gap: CGFloat(settings.gap)).frame(for: action, in: visibleFrame) {
            overlay.show(cgRect: target)
        } else {
            overlay.hide()
        }
    }

    private func handleUp(_ event: NSEvent) {
        defer {
            overlay.hide()
            state = .idle
        }
        guard case .tracking(let tracking) = state,
              tracking.confirmedWindowDrag,
              let action = tracking.currentAction,
              !isSuppressionHeld(event) else { return }
        executor.perform(action, on: tracking.window, preferredScreen: tracking.currentScreen, usesMemory: false)
    }
}

private extension DragSuppressModifier {
    var eventFlag: NSEvent.ModifierFlags? {
        switch self {
        case .off: return nil
        case .shift: return .shift
        case .option: return .option
        case .control: return .control
        case .command: return .command
        }
    }
}
