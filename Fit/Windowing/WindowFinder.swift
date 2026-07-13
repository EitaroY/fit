import AppKit
import ApplicationServices

enum WindowFinder {
    /// The window snap actions should target: the focused window of the
    /// frontmost app. When Fit itself is frontmost (status menu, settings),
    /// callers pass the pid of the previously active app instead.
    static func focusedWindow(preferringPid pid: pid_t?) -> AXWindow? {
        let targetPid = pid ?? NSWorkspace.shared.frontmostApplication?.processIdentifier
        guard let targetPid else { return nil }
        let app = AXUIElementCreateApplication(targetPid)
        if let element = copyElement(app, kAXFocusedWindowAttribute) {
            return AXWindow(element: element)
        }
        // Some apps expose only a main window (e.g. right after activation).
        if let element = copyElement(app, kAXMainWindowAttribute) {
            return AXWindow(element: element)
        }
        return nil
    }

    /// Window under a point in CG coordinates, used by drag-to-snap.
    static func window(atCG point: CGPoint) -> AXWindow? {
        let systemWide = AXUIElementCreateSystemWide()
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(systemWide, Float(point.x), Float(point.y), &hit) == .success,
              let hit else { return nil }
        return containingWindow(of: hit)
    }

    /// Walks from an arbitrary UI element to its window: first via the
    /// element's AXWindow attribute, then by climbing parents.
    private static func containingWindow(of element: AXUIElement) -> AXWindow? {
        if let window = copyElement(element, kAXWindowAttribute) {
            return AXWindow(element: window)
        }
        var current = element
        for _ in 0..<20 {
            if role(of: current) == kAXWindowRole {
                return AXWindow(element: current)
            }
            guard let parent = copyElement(current, kAXParentAttribute) else { return nil }
            current = parent
        }
        return nil
    }

    private static func role(of element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private static func copyElement(_ element: AXUIElement, _ attribute: String) -> AXUIElement? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID() else {
            return nil
        }
        return (value as! AXUIElement)
    }
}
