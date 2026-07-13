import AppKit
import ApplicationServices

/// Thin wrapper around a window's AXUIElement. All frames are CG coordinates
/// (top-left origin), which is the Accessibility API's native space.
struct AXWindow {
    let element: AXUIElement

    // MARK: - Frame

    var frame: CGRect? {
        guard let origin = pointValue(kAXPositionAttribute),
              let size = sizeValue(kAXSizeAttribute) else { return nil }
        return CGRect(origin: origin, size: size)
    }

    /// Sets size → position → size. Apps clamp requested sizes (minimum
    /// sizes, terminal grids), so setting the size first, then the position,
    /// then the size again converges even near screen edges.
    func set(frame: CGRect) {
        setSize(frame.size)
        setPosition(frame.origin)
        setSize(frame.size)
    }

    private func setPosition(_ point: CGPoint) {
        var value = point
        guard let axValue = AXValueCreate(.cgPoint, &value) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axValue)
    }

    private func setSize(_ size: CGSize) {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axValue)
    }

    // MARK: - Properties

    /// Regular window (not a panel, sheet, or floating helper).
    var isStandard: Bool {
        (copyValue(kAXSubroleAttribute) as? String) == kAXStandardWindowSubrole
    }

    /// Native full-screen windows must not be moved or resized.
    var isFullscreen: Bool {
        (copyValue("AXFullScreen") as? Bool) == true
    }

    var isMovable: Bool { isSettable(kAXPositionAttribute) }
    var isResizable: Bool { isSettable(kAXSizeAttribute) }

    var pid: pid_t? {
        var pid: pid_t = 0
        guard AXUIElementGetPid(element, &pid) == .success else { return nil }
        return pid
    }

    /// The owning application's AX element.
    var appElement: AXUIElement? {
        pid.map(AXUIElementCreateApplication)
    }

    // MARK: - AX plumbing

    private func copyValue(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    private func pointValue(_ attribute: String) -> CGPoint? {
        guard let raw = copyValue(attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(raw as! AXValue, .cgPoint, &point) else { return nil }
        return point
    }

    private func sizeValue(_ attribute: String) -> CGSize? {
        guard let raw = copyValue(attribute), CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(raw as! AXValue, .cgSize, &size) else { return nil }
        return size
    }

    private func isSettable(_ attribute: String) -> Bool {
        var settable = DarwinBoolean(false)
        guard AXUIElementIsAttributeSettable(element, attribute as CFString, &settable) == .success else {
            return false
        }
        return settable.boolValue
    }
}

/// Hashable identity for a window, for the restore history. AXUIElement
/// implements CFEqual/CFHash based on the underlying (pid, element token)
/// pair, so two references to the same window compare equal.
struct AXWindowKey: Hashable {
    let element: AXUIElement

    init(_ window: AXWindow) { self.element = window.element }

    static func == (lhs: AXWindowKey, rhs: AXWindowKey) -> Bool {
        CFEqual(lhs.element, rhs.element)
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(CFHash(element))
    }
}
