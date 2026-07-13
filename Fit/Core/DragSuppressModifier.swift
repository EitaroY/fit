import Foundation

/// Modifier key that pauses drag-to-snap while held, for placing a window
/// near a screen edge without it snapping.
public enum DragSuppressModifier: String, CaseIterable, Codable, Sendable {
    case off, shift, option, control, command

    public var title: String {
        switch self {
        case .off: return "Off"
        case .shift: return "⇧ Shift"
        case .option: return "⌥ Option"
        case .control: return "⌃ Control"
        case .command: return "⌘ Command"
        }
    }
}
