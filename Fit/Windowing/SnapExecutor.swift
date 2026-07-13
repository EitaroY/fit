import AppKit
import ApplicationServices
import os

/// Orchestrates a snap: find the target window, compute the destination
/// frame, remember the original for restore, and apply it via AX.
///
/// Repeated presses use `SnapMemory` to enable two chained behaviors:
///
/// - **Cycling** (½ → ⅔ → ⅓): pressing the same half shortcut walks that
///   action's `cycleChain`.
/// - **Combining** (half + perpendicular half → quarter): pressing a
///   perpendicular half after landing on a half snaps to the corresponding
///   corner (e.g. leftHalf then topHalf → topLeftQuarter).
///
/// Both fire only when the window is still exactly where the previous snap
/// put it. Moving it by hand, snapping something else, or switching windows
/// resets the memory, so a fresh press always produces the plain action.
@MainActor
final class SnapExecutor {
    private let settings: SettingsStore
    private let tracker: FrontmostAppTracker
    private var history = FrameHistory()
    private let log = Logger(subsystem: Bundle.main.bundleIdentifier ?? "fit", category: "snap")

    /// One-slot record of the last successful snap. What we remember is the
    /// resolved action (which may differ from the pressed one after cycling
    /// or combining) so the next press can chain off the actual result.
    private struct SnapMemory {
        let windowKey: AXWindowKey
        let resolvedAction: SnapAction
        let appliedFrame: CGRect
    }

    private var memory: SnapMemory?

    /// Called when an action is attempted without Accessibility permission.
    var onPermissionMissing: (() -> Void)?

    init(settings: SettingsStore, tracker: FrontmostAppTracker) {
        self.settings = settings
        self.tracker = tracker
    }

    /// Hotkey / menu entry point: acts on the focused window.
    func perform(_ action: SnapAction) {
        guard let window = WindowFinder.focusedWindow(preferringPid: tracker.targetPid) else {
            NSSound.beep()
            return
        }
        perform(action, on: window, preferredScreen: nil, usesMemory: true)
    }

    /// Full entry point. Drag-to-snap passes `usesMemory: false` — every
    /// drag is a discrete gesture and must never advance a cycle or trigger
    /// combining.
    func perform(_ action: SnapAction, on window: AXWindow, preferredScreen: NSScreen?, usesMemory: Bool) {
        guard AXIsProcessTrusted() else {
            NSSound.beep()
            onPermissionMissing?()
            return
        }
        guard !window.isFullscreen, window.isMovable, let currentFrame = window.frame else {
            NSSound.beep()
            return
        }
        guard let screen = preferredScreen
            ?? ScreenGeometry.screen(for: currentFrame)
            ?? NSScreen.main else {
            NSSound.beep()
            return
        }

        let visibleFrame = ScreenGeometry.cgVisibleFrame(of: screen)
        let calculator = LayoutCalculator(gap: CGFloat(settings.gap))

        let resolvedAction = usesMemory
            ? resolve(pressed: action, on: window, currentFrame: currentFrame)
            : action

        let target: CGRect?
        switch resolvedAction {
        case .restore:
            target = history.recallOriginal(for: window)
        case .center:
            target = calculator.centered(size: currentFrame.size, in: visibleFrame)
        case .previousDisplay, .nextDisplay:
            guard let destination = ScreenGeometry.adjacentScreen(of: screen, next: resolvedAction == .nextDisplay) else {
                NSSound.beep()
                return
            }
            target = LayoutCalculator.proportionallyMapped(
                currentFrame,
                from: visibleFrame,
                to: ScreenGeometry.cgVisibleFrame(of: destination))
        default:
            target = calculator.frame(for: resolvedAction, in: visibleFrame)
        }

        guard let target else {
            NSSound.beep()
            memory = nil
            return
        }

        if resolvedAction != .restore {
            history.rememberOriginal(currentFrame, for: window)
        }

        log.debug("snap \(resolvedAction.rawValue, privacy: .public) -> \(String(describing: target), privacy: .public)")
        applyWithEnhancedUIWorkaround(target, to: window)

        // Record the frame the app actually accepted, not the requested one.
        // If the app applies moves asynchronously the read-back is stale,
        // which then safely falls the next press into "fresh snap" mode.
        memory = SnapMemory(
            windowKey: AXWindowKey(window),
            resolvedAction: resolvedAction,
            appliedFrame: window.frame ?? target)
    }

    /// Decides what a press really means given the last snap's memory:
    /// combining wins over cycling wins over the plain action.
    private func resolve(pressed: SnapAction, on window: AXWindow, currentFrame: CGRect) -> SnapAction {
        guard let mem = memory,
              mem.windowKey == AXWindowKey(window),
              currentFrame.isApproximately(mem.appliedFrame) else {
            return pressed
        }
        if settings.combineHalvesToQuarters,
           let quarter = SnapAction.combinedQuarter(base: mem.resolvedAction, add: pressed) {
            return quarter
        }
        if settings.cycleSizesEnabled,
           let chain = pressed.cycleChain,
           let index = chain.firstIndex(of: mem.resolvedAction) {
            return chain[(index + 1) % chain.count]
        }
        return pressed
    }

    /// Chromium/Electron apps mishandle AX moves while the app element's
    /// AXEnhancedUserInterface is set (a VoiceOver-era flag). Clear it for
    /// the duration of the operation and put the original value back.
    private func applyWithEnhancedUIWorkaround(_ frame: CGRect, to window: AXWindow) {
        let enhancedKey = "AXEnhancedUserInterface" as CFString
        var original: CFTypeRef?
        var wasEnhanced = false
        if let app = window.appElement {
            AXUIElementCopyAttributeValue(app, enhancedKey, &original)
            wasEnhanced = (original as? Bool) == true
            if wasEnhanced {
                AXUIElementSetAttributeValue(app, enhancedKey, kCFBooleanFalse)
            }
        }
        window.set(frame: frame)
        if wasEnhanced, let app = window.appElement {
            AXUIElementSetAttributeValue(app, enhancedKey, kCFBooleanTrue)
        }
    }
}

private extension CGRect {
    /// Loose equality absorbing app-side clamping (terminal grids, minimum
    /// sizes) when deciding whether a window is still where we put it.
    func isApproximately(_ other: CGRect, tolerance: CGFloat = 10) -> Bool {
        abs(minX - other.minX) <= tolerance
            && abs(minY - other.minY) <= tolerance
            && abs(width - other.width) <= tolerance
            && abs(height - other.height) <= tolerance
    }
}
