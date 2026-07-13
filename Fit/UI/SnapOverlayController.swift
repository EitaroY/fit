import AppKit

/// The translucent rounded rectangle previewing where a dragged window will
/// land. One borderless, click-through window, reused across drags.
@MainActor
final class SnapOverlayController {
    private lazy var window: NSWindow = {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: true)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.animationBehavior = .none
        window.isReleasedWhenClosed = false

        let view = NSView()
        view.wantsLayer = true
        if let layer = view.layer {
            layer.cornerRadius = 10
            layer.cornerCurve = .continuous
            layer.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.22).cgColor
            layer.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.9).cgColor
            layer.borderWidth = 2
        }
        window.contentView = view
        return window
    }()

    private var isVisible = false

    /// Shows (or moves) the preview. `cgRect` is in CG coordinates.
    func show(cgRect: CGRect) {
        let frame = ScreenGeometry.toCocoa(cgRect)
        if isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().setFrame(frame, display: true)
            }
        } else {
            window.setFrame(frame, display: true)
            window.orderFrontRegardless()
            isVisible = true
        }
    }

    func hide() {
        guard isVisible else { return }
        window.orderOut(nil)
        isVisible = false
    }
}
