import Foundation

/// A global keyboard shortcut: Carbon virtual key code + Carbon modifier
/// bits. The display label is captured at recording time (from the active
/// keyboard layout), so no layout translation is needed at render time.
public struct Shortcut: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var carbonModifiers: UInt32
    public var keyLabel: String

    public init(keyCode: UInt32, carbonModifiers: UInt32, keyLabel: String) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyLabel = keyLabel
    }

    /// Same key combination, ignoring the display label.
    public func matches(_ other: Shortcut) -> Bool {
        keyCode == other.keyCode && carbonModifiers == other.carbonModifiers
    }

    public var display: String {
        var s = ""
        if carbonModifiers & CarbonModifier.control != 0 { s += "⌃" }
        if carbonModifiers & CarbonModifier.option != 0 { s += "⌥" }
        if carbonModifiers & CarbonModifier.shift != 0 { s += "⇧" }
        if carbonModifiers & CarbonModifier.command != 0 { s += "⌘" }
        return s + keyLabel
    }
}

/// Carbon modifier-key bits (Events.h). Defined here so the core stays free
/// of a Carbon import; values are ABI-stable constants.
public enum CarbonModifier {
    public static let command: UInt32 = 0x0100 // cmdKey
    public static let shift: UInt32 = 0x0200 // shiftKey
    public static let option: UInt32 = 0x0800 // optionKey
    public static let control: UInt32 = 0x1000 // controlKey
}

/// Carbon virtual key codes used by the default bindings (kVK_* constants).
public enum KeyCode {
    public static let returnKey: UInt32 = 36
    public static let delete: UInt32 = 51 // backspace
    public static let escape: UInt32 = 53
    public static let leftArrow: UInt32 = 123
    public static let rightArrow: UInt32 = 124
    public static let downArrow: UInt32 = 125
    public static let upArrow: UInt32 = 126
    public static let c: UInt32 = 8
    public static let d: UInt32 = 2
    public static let e: UInt32 = 14
    public static let f: UInt32 = 3
    public static let g: UInt32 = 5
    public static let i: UInt32 = 34
    public static let j: UInt32 = 38
    public static let k: UInt32 = 40
    public static let t: UInt32 = 17
    public static let u: UInt32 = 32

    /// Labels for keys whose display glyph isn't the typed character.
    /// Function keys are included so they can be recorded without modifiers.
    public static let specialLabels: [UInt32: String] = [
        36: "↩", 48: "⇥", 49: "Space", 51: "⌫", 53: "⎋",
        115: "↖", 116: "⇞", 117: "⌦", 119: "↘", 121: "⇟",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]

    public static let functionKeys: Set<UInt32> = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
}

extension Shortcut {
    /// Magnet-compatible default bindings.
    public static let defaultBindings: [SnapAction: Shortcut] = {
        let ctrlOpt = CarbonModifier.control | CarbonModifier.option
        let ctrlOptCmd = ctrlOpt | CarbonModifier.command
        return [
            .leftHalf: Shortcut(keyCode: KeyCode.leftArrow, carbonModifiers: ctrlOpt, keyLabel: "←"),
            .rightHalf: Shortcut(keyCode: KeyCode.rightArrow, carbonModifiers: ctrlOpt, keyLabel: "→"),
            .topHalf: Shortcut(keyCode: KeyCode.upArrow, carbonModifiers: ctrlOpt, keyLabel: "↑"),
            .bottomHalf: Shortcut(keyCode: KeyCode.downArrow, carbonModifiers: ctrlOpt, keyLabel: "↓"),
            .topLeftQuarter: Shortcut(keyCode: KeyCode.u, carbonModifiers: ctrlOpt, keyLabel: "U"),
            .topRightQuarter: Shortcut(keyCode: KeyCode.i, carbonModifiers: ctrlOpt, keyLabel: "I"),
            .bottomLeftQuarter: Shortcut(keyCode: KeyCode.j, carbonModifiers: ctrlOpt, keyLabel: "J"),
            .bottomRightQuarter: Shortcut(keyCode: KeyCode.k, carbonModifiers: ctrlOpt, keyLabel: "K"),
            .leftThird: Shortcut(keyCode: KeyCode.d, carbonModifiers: ctrlOpt, keyLabel: "D"),
            .centerThird: Shortcut(keyCode: KeyCode.f, carbonModifiers: ctrlOpt, keyLabel: "F"),
            .rightThird: Shortcut(keyCode: KeyCode.g, carbonModifiers: ctrlOpt, keyLabel: "G"),
            .leftTwoThirds: Shortcut(keyCode: KeyCode.e, carbonModifiers: ctrlOpt, keyLabel: "E"),
            .rightTwoThirds: Shortcut(keyCode: KeyCode.t, carbonModifiers: ctrlOpt, keyLabel: "T"),
            .maximize: Shortcut(keyCode: KeyCode.returnKey, carbonModifiers: ctrlOpt, keyLabel: "↩"),
            .center: Shortcut(keyCode: KeyCode.c, carbonModifiers: ctrlOpt, keyLabel: "C"),
            .restore: Shortcut(keyCode: KeyCode.delete, carbonModifiers: ctrlOpt, keyLabel: "⌫"),
            .previousDisplay: Shortcut(keyCode: KeyCode.leftArrow, carbonModifiers: ctrlOptCmd, keyLabel: "←"),
            .nextDisplay: Shortcut(keyCode: KeyCode.rightArrow, carbonModifiers: ctrlOptCmd, keyLabel: "→"),
        ]
    }()
}
