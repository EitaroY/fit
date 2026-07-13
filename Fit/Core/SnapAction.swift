import Foundation

/// Every window operation Fit can perform. The raw value is used as the
/// persistence key for shortcut bindings, so renaming a case is a breaking
/// change for stored settings.
public enum SnapAction: String, CaseIterable, Codable, Sendable {
    case leftHalf, rightHalf, topHalf, bottomHalf
    case topLeftQuarter, topRightQuarter, bottomLeftQuarter, bottomRightQuarter
    case leftThird, centerThird, rightThird, leftTwoThirds, rightTwoThirds
    case topThird, middleThird, bottomThird, topTwoThirds, bottomTwoThirds
    case maximize, center, restore
    case previousDisplay, nextDisplay

    public var title: String {
        switch self {
        case .leftHalf: return "Left Half"
        case .rightHalf: return "Right Half"
        case .topHalf: return "Top Half"
        case .bottomHalf: return "Bottom Half"
        case .topLeftQuarter: return "Top Left Quarter"
        case .topRightQuarter: return "Top Right Quarter"
        case .bottomLeftQuarter: return "Bottom Left Quarter"
        case .bottomRightQuarter: return "Bottom Right Quarter"
        case .leftThird: return "Left Third"
        case .centerThird: return "Center Third"
        case .rightThird: return "Right Third"
        case .leftTwoThirds: return "Left Two Thirds"
        case .rightTwoThirds: return "Right Two Thirds"
        case .topThird: return "Top Third"
        case .middleThird: return "Middle Third"
        case .bottomThird: return "Bottom Third"
        case .topTwoThirds: return "Top Two Thirds"
        case .bottomTwoThirds: return "Bottom Two Thirds"
        case .maximize: return "Maximize"
        case .center: return "Center"
        case .restore: return "Restore"
        case .previousDisplay: return "Previous Display"
        case .nextDisplay: return "Next Display"
        }
    }

    /// Display order for the status menu and the shortcuts settings tab.
    public static let menuGroups: [(title: String, actions: [SnapAction])] = [
        ("Halves", [.leftHalf, .rightHalf, .topHalf, .bottomHalf]),
        ("Quarters", [.topLeftQuarter, .topRightQuarter, .bottomLeftQuarter, .bottomRightQuarter]),
        ("Column Thirds", [.leftThird, .centerThird, .rightThird, .leftTwoThirds, .rightTwoThirds]),
        ("Row Thirds", [.topThird, .middleThird, .bottomThird, .topTwoThirds, .bottomTwoThirds]),
        ("Other", [.maximize, .center, .restore]),
        ("Display", [.previousDisplay, .nextDisplay]),
    ]

    /// Pressing the same shortcut repeatedly walks this chain, wrapping at
    /// the end (e.g. ⌃⌥←: ½ → ⅔ → ⅓ → ½ …). Index 0 is always the action
    /// itself.
    public var cycleChain: [SnapAction]? {
        switch self {
        case .leftHalf: return [.leftHalf, .leftTwoThirds, .leftThird]
        case .rightHalf: return [.rightHalf, .rightTwoThirds, .rightThird]
        case .topHalf: return [.topHalf, .topTwoThirds, .topThird]
        case .bottomHalf: return [.bottomHalf, .bottomTwoThirds, .bottomThird]
        default: return nil
        }
    }

    /// If the previous snap was one half and the new press is a perpendicular
    /// half, returns the quarter that corresponds to their overlap. This is
    /// what makes ⌃⌥← then ⌃⌥↑ land on the top-left corner without adding
    /// dedicated corner shortcuts.
    public static func combinedQuarter(base: SnapAction, add: SnapAction) -> SnapAction? {
        switch (base, add) {
        case (.leftHalf, .topHalf), (.topHalf, .leftHalf): return .topLeftQuarter
        case (.leftHalf, .bottomHalf), (.bottomHalf, .leftHalf): return .bottomLeftQuarter
        case (.rightHalf, .topHalf), (.topHalf, .rightHalf): return .topRightQuarter
        case (.rightHalf, .bottomHalf), (.bottomHalf, .rightHalf): return .bottomRightQuarter
        default: return nil
        }
    }
}
