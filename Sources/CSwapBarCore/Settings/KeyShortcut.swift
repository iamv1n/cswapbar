import Foundation

/// A keyboard shortcut: a virtual key code plus modifiers.
///
/// `keyCode` is the macOS virtual key code (the same number Carbon hot keys and
/// `NSEvent.keyCode` use). `keyLabel` is what the key printed when it was
/// recorded, kept for display so the label matches the user's keyboard layout.
public struct KeyShortcut: Codable, Sendable, Equatable, Hashable {
    public struct Modifiers: OptionSet, Codable, Sendable, Hashable {
        public let rawValue: Int
        public init(rawValue: Int) { self.rawValue = rawValue }

        public static let control = Modifiers(rawValue: 1 << 0)
        public static let option = Modifiers(rawValue: 1 << 1)
        public static let shift = Modifiers(rawValue: 1 << 2)
        public static let command = Modifiers(rawValue: 1 << 3)
    }

    public var keyCode: UInt32
    public var modifiers: Modifiers
    public var keyLabel: String

    public init(keyCode: UInt32, modifiers: Modifiers, keyLabel: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.keyLabel = keyLabel
    }

    /// ⌃⌥⌘P: unlikely to clash with app shortcuts.
    public static let defaultPrivacyToggle = KeyShortcut(keyCode: 35, modifiers: [.control, .option, .command], keyLabel: "P")

    /// ⌃⌥⌘C opens or closes the popover from any app.
    public static let defaultOpenPopover = KeyShortcut(keyCode: 8, modifiers: [.control, .option, .command], keyLabel: "C")

    /// In the order macOS menus use: ⌃⌥⇧⌘.
    public var displayString: String {
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + keyLabel
    }

    /// A global shortcut needs ⌘, ⌃ or ⌥; Shift alone would swallow normal typing.
    public var isValidGlobalShortcut: Bool {
        !modifiers.intersection([.command, .control, .option]).isEmpty && !keyLabel.isEmpty
    }

    /// Readable label for a recorded key. Letters are uppercased; a few
    /// special keys get their symbols.
    public static func label(forKeyCode keyCode: UInt32, characters: String?) -> String {
        if let special = specialKeys[keyCode] { return special }
        let trimmed = (characters ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.uppercased()
    }

    private static let specialKeys: [UInt32: String] = [
        49: "Space", 36: "↩", 48: "⇥", 51: "⌫", 117: "⌦", 53: "⎋",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        115: "↖", 119: "↘", 116: "⇞", 121: "⇟",
        122: "F1", 120: "F2", 99: "F3", 118: "F4", 96: "F5", 97: "F6",
        98: "F7", 100: "F8", 101: "F9", 109: "F10", 103: "F11", 111: "F12",
    ]
}
