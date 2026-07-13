import CoreGraphics

/// Resolves a pointer position near a screen edge to a drag-snap action.
///
/// CG coordinates (top-left origin, y downward). `visibleFrame` excludes the
/// menu bar and Dock; a pointer hovering over those areas still falls inside
/// the edge bands because the comparisons are open toward the screen border.
///
/// Zone map (Magnet-compatible):
///
///     ┌────┬──────── maximize ────────┬────┐
///     │ TL │                          │ TR │   left/right edge:
///     ├────┤                          ├────┤   top/bottom `cornerFraction`
///     │ L  │                          │  R │   → quarters, middle → half
///     ├────┤                          ├────┤
///     │ BL │                          │ BR │   bottom edge: thirds
///     └────┴── ⅓ ──── ⅓ ──── ⅓ ──────┴────┘
public enum EdgeZone {
    public static func action(
        for p: CGPoint,
        inVisibleFrame vf: CGRect,
        edgeThreshold t: CGFloat = 12,
        cornerFraction cf: CGFloat = 0.25
    ) -> SnapAction? {
        let topBand = vf.minY + vf.height * cf
        let bottomBand = vf.maxY - vf.height * cf

        if p.x <= vf.minX + t {
            if p.y <= topBand { return .topLeftQuarter }
            if p.y >= bottomBand { return .bottomLeftQuarter }
            return .leftHalf
        }
        if p.x >= vf.maxX - t {
            if p.y <= topBand { return .topRightQuarter }
            if p.y >= bottomBand { return .bottomRightQuarter }
            return .rightHalf
        }
        if p.y <= vf.minY + t {
            return .maximize
        }
        if p.y >= vf.maxY - t {
            let third = (p.x - vf.minX) / vf.width
            if third < 1.0 / 3.0 { return .leftThird }
            if third < 2.0 / 3.0 { return .centerThird }
            return .rightThird
        }
        return nil
    }
}
