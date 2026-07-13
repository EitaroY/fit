import CoreGraphics

/// Computes target window frames for snap actions.
///
/// All rects use CG coordinates: origin at the top-left of the primary
/// screen, y growing downward — the same space the Accessibility API uses.
/// `visibleFrame` is expected to already exclude the menu bar and Dock.
///
/// Gap model: `gap` points between the screen edges and windows, and `gap`
/// points between adjacent snapped windows. With gap == 0 the frames match
/// Magnet's behavior exactly.
public struct LayoutCalculator: Sendable {
    public let gap: CGFloat

    public init(gap: CGFloat = 0) {
        self.gap = gap
    }

    /// Frame for a geometric snap action. Returns nil for actions that are
    /// not pure geometry (restore, center, display moves).
    public func frame(for action: SnapAction, in visibleFrame: CGRect) -> CGRect? {
        let vf = visibleFrame
        switch action {
        case .leftHalf: return compose(vf, col: (2, 0, 1))
        case .rightHalf: return compose(vf, col: (2, 1, 1))
        case .topHalf: return compose(vf, row: (2, 0, 1))
        case .bottomHalf: return compose(vf, row: (2, 1, 1))
        case .topLeftQuarter: return compose(vf, col: (2, 0, 1), row: (2, 0, 1))
        case .topRightQuarter: return compose(vf, col: (2, 1, 1), row: (2, 0, 1))
        case .bottomLeftQuarter: return compose(vf, col: (2, 0, 1), row: (2, 1, 1))
        case .bottomRightQuarter: return compose(vf, col: (2, 1, 1), row: (2, 1, 1))
        case .leftThird: return compose(vf, col: (3, 0, 1))
        case .centerThird: return compose(vf, col: (3, 1, 1))
        case .rightThird: return compose(vf, col: (3, 2, 1))
        case .leftTwoThirds: return compose(vf, col: (3, 0, 2))
        case .rightTwoThirds: return compose(vf, col: (3, 1, 2))
        case .topThird: return compose(vf, row: (3, 0, 1))
        case .middleThird: return compose(vf, row: (3, 1, 1))
        case .bottomThird: return compose(vf, row: (3, 2, 1))
        case .topTwoThirds: return compose(vf, row: (3, 0, 2))
        case .bottomTwoThirds: return compose(vf, row: (3, 1, 2))
        case .maximize: return vf.insetBy(dx: gap, dy: gap)
        case .center, .restore, .previousDisplay, .nextDisplay: return nil
        }
    }

    /// Keeps `size`, centers it in `visibleFrame`, clamping so it fits.
    public func centered(size: CGSize, in visibleFrame: CGRect) -> CGRect {
        let inner = visibleFrame.insetBy(dx: gap, dy: gap)
        let w = min(size.width, inner.width)
        let h = min(size.height, inner.height)
        return CGRect(
            x: inner.midX - w / 2,
            y: inner.midY - h / 2,
            width: w,
            height: h
        )
    }

    /// Maps `frame` from one screen's visible frame to another, preserving
    /// relative position and relative size, then clamps it inside `to`.
    public static func proportionallyMapped(_ frame: CGRect, from: CGRect, to: CGRect) -> CGRect {
        guard from.width > 0, from.height > 0 else { return to }
        let sx = to.width / from.width
        let sy = to.height / from.height
        var mapped = CGRect(
            x: to.minX + (frame.minX - from.minX) * sx,
            y: to.minY + (frame.minY - from.minY) * sy,
            width: frame.width * sx,
            height: frame.height * sy
        )
        mapped.size.width = min(mapped.width, to.width)
        mapped.size.height = min(mapped.height, to.height)
        mapped.origin.x = max(to.minX, min(mapped.minX, to.maxX - mapped.width))
        mapped.origin.y = max(to.minY, min(mapped.minY, to.maxY - mapped.height))
        return mapped
    }

    // MARK: - Grid composition

    /// (count, index, span): one slot of an n-way split along an axis.
    private typealias Slot = (count: Int, index: Int, span: Int)

    private func compose(_ vf: CGRect, col: Slot = (1, 0, 1), row: Slot = (1, 0, 1)) -> CGRect {
        let x = segment(origin: vf.minX, length: vf.width, slot: col)
        let y = segment(origin: vf.minY, length: vf.height, slot: row)
        return CGRect(x: x.origin, y: y.origin, width: x.length, height: y.length)
    }

    /// One-dimensional split: `count` units separated by `gap`, with `gap`
    /// margins at both ends. Returns the segment covering `span` units
    /// starting at `index`.
    private func segment(origin: CGFloat, length: CGFloat, slot: Slot) -> (origin: CGFloat, length: CGFloat) {
        let count = CGFloat(slot.count)
        let unit = (length - (count + 1) * gap) / count
        let start = origin + gap + CGFloat(slot.index) * (unit + gap)
        let span = CGFloat(slot.span)
        return (start, unit * span + gap * (span - 1))
    }
}
