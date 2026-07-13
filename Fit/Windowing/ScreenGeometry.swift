import AppKit

/// Conversion between the two coordinate spaces used on macOS and screen
/// selection helpers.
///
/// - Cocoa (NSScreen, NSWindow, NSEvent): origin at the bottom-left of the
///   primary screen, y grows upward.
/// - CG / AX (AXUIElement positions): origin at the top-left of the primary
///   screen, y grows downward.
///
/// All of Fit's internal math happens in CG space; Cocoa values are flipped
/// on entry and flipped back only when driving NSWindow (the overlay).
enum ScreenGeometry {
    /// Height of the primary screen (the one whose Cocoa frame origin is
    /// (0,0)). The flip axis for both conversions.
    static var primaryScreenHeight: CGFloat {
        let screens = NSScreen.screens
        let primary = screens.first { $0.frame.origin == .zero } ?? screens.first
        return primary?.frame.maxY ?? 0
    }

    /// The flip is an involution: the same formula converts Cocoa→CG and CG→Cocoa.
    static func flip(_ rect: CGRect) -> CGRect {
        CGRect(x: rect.minX, y: primaryScreenHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func flip(_ point: CGPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryScreenHeight - point.y)
    }

    static func cgFrame(of screen: NSScreen) -> CGRect { flip(screen.frame) }
    static func cgVisibleFrame(of screen: NSScreen) -> CGRect { flip(screen.visibleFrame) }
    static func toCocoa(_ cgRect: CGRect) -> CGRect { flip(cgRect) }

    /// Current pointer position in CG coordinates.
    static func cgMouseLocation() -> CGPoint { flip(NSEvent.mouseLocation) }

    static func screen(containingCG point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { cgFrame(of: $0).contains(point) }
    }

    /// Screen with the largest intersection with `windowFrame` (CG coords).
    static func screen(for windowFrame: CGRect) -> NSScreen? {
        let screens = NSScreen.screens
        let best = screens.max { a, b in
            let areaA = cgFrame(of: a).intersection(windowFrame).area
            let areaB = cgFrame(of: b).intersection(windowFrame).area
            return areaA < areaB
        }
        guard let best, cgFrame(of: best).intersects(windowFrame) else {
            return NSScreen.main ?? screens.first
        }
        return best
    }

    /// Neighbor in a stable left-to-right, top-to-bottom ordering, wrapping
    /// around at the ends.
    static func adjacentScreen(of screen: NSScreen, next: Bool) -> NSScreen? {
        let ordered = NSScreen.screens.sorted {
            let a = cgFrame(of: $0), b = cgFrame(of: $1)
            return a.minX != b.minX ? a.minX < b.minX : a.minY < b.minY
        }
        guard ordered.count > 1, let index = ordered.firstIndex(of: screen) else { return nil }
        let offset = next ? 1 : ordered.count - 1
        return ordered[(index + offset) % ordered.count]
    }
}

private extension CGRect {
    var area: CGFloat { isNull || isEmpty ? 0 : width * height }
}
