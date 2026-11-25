import Foundation

/// A theme the user made. Stores five key colors; the rest of the palette
/// (muted text, borders, raised cards, usage colors) is derived from them.
///
/// Saved inside the settings and shared as a small JSON file:
///
///     { "format": "cswapbar-theme", "version": 1, "name": "Nightfall", "dark": true,
///       "gradient": false, "background": "#14161C", "backgroundEnd": "#14161C",
///       "surface": "#1E2129", "text": "#ECEEF3", "accent": "#7AA2F7" }
public struct CustomTheme: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var isDark: Bool
    /// Paint the background as a top-to-bottom gradient.
    public var gradient: Bool
    public var background: UInt32
    public var backgroundEnd: UInt32
    public var surface: UInt32
    public var text: UInt32
    public var accent: UInt32

    public static let fileFormat = "cswapbar-theme"
    public static let fileVersion = 1
    public static let maxNameLength = 40
    /// Limit on saved custom themes.
    public static let maxCount = 24

    public init(
        id: UUID = UUID(), name: String, isDark: Bool, gradient: Bool = false,
        background: UInt32, backgroundEnd: UInt32? = nil, surface: UInt32, text: UInt32, accent: UInt32
    ) {
        self.id = id
        self.name = Self.cleanName(name)
        self.isDark = isDark
        self.gradient = gradient
        self.background = background
        self.backgroundEnd = backgroundEnd ?? background
        self.surface = surface
        self.text = text
        self.accent = accent
    }

    /// Starts a custom theme from an existing palette.
    public static func based(on palette: ThemePalette, name: String) -> CustomTheme {
        CustomTheme(name: name, isDark: palette.isDark, gradient: palette.style == .gradient,
                    background: palette.background, backgroundEnd: palette.backgroundEnd,
                    surface: palette.surface, text: palette.text, accent: palette.accent)
    }

    // MARK: Derived palette

    public var palette: ThemePalette {
        let bands = isDark ? ThemePalette.atelierDark : ThemePalette.atelierLight
        return ThemePalette(
            name: name, isDark: isDark,
            background: background,
            surface: surface,
            elevated: ColorMath.mix(surface, text, 0.07),
            border: ColorMath.mix(surface, text, 0.16),
            text: text,
            muted: mutedText,
            accent: accent,
            healthy: bands.healthy, warning: bands.warning, high: bands.high, critical: bands.critical,
            style: gradient ? .gradient : .solid,
            backgroundEnd: gradient ? backgroundEnd : nil
        )
    }

    /// Secondary text: text faded toward the card color, but never below 4.5:1.
    var mutedText: UInt32 {
        var amount = 0.42
        while amount > 0 {
            let candidate = ColorMath.mix(text, surface, amount)
            if ColorContrast.ratio(candidate, surface) >= 4.5 { return candidate }
            amount -= 0.04
        }
        return text
    }

    // MARK: Readability

    public struct Issue: Sendable, Equatable {
        public let message: String
        public let ratio: Double
    }

    /// Contrast problems worth warning about in the editor. Empty means readable.
    public var readabilityIssues: [Issue] {
        var issues: [Issue] = []
        let onCard = ColorContrast.ratio(text, surface)
        if onCard < 4.5 { issues.append(Issue(message: "Text on cards is hard to read", ratio: onCard)) }
        let onBackground = min(ColorContrast.ratio(text, background), ColorContrast.ratio(text, gradient ? backgroundEnd : background))
        if onBackground < 4.5 { issues.append(Issue(message: "Text on the background is hard to read", ratio: onBackground)) }
        let accentOnCard = ColorContrast.ratio(accent, surface)
        if accentOnCard < 3 { issues.append(Issue(message: "The accent is hard to see on cards", ratio: accentOnCard)) }
        return issues
    }

    // MARK: Names

    static func cleanName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let short = String(trimmed.prefix(maxNameLength))
        return short.isEmpty ? "Custom Theme" : short
    }

    /// "Nightfall", then "Nightfall 2", "Nightfall 3"…
    public static func uniqueName(_ base: String, existing: [CustomTheme]) -> String {
        let names = Set(existing.map(\.name))
        let clean = cleanName(base)
        guard names.contains(clean) else { return clean }
        var n = 2
        while names.contains("\(clean) \(n)") { n += 1 }
        return "\(clean) \(n)"
    }

    // MARK: Codable (hex strings, readable and hand-editable)

    private enum CodingKeys: String, CodingKey {
        case format, version, id, name, dark, gradient, background, backgroundEnd, surface, text, accent
    }

    public enum FileError: Error, Equatable {
        case notATheme
        case newerVersion(Int)
        case badColor(String)
    }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if let format = try c.decodeIfPresent(String.self, forKey: .format), format != Self.fileFormat {
            throw FileError.notATheme
        }
        if let version = try c.decodeIfPresent(Int.self, forKey: .version), version > Self.fileVersion {
            throw FileError.newerVersion(version)
        }
        func color(_ key: CodingKeys) throws -> UInt32 {
            let raw = try c.decode(String.self, forKey: key)
            guard let value = ColorMath.parseHex(raw) else { throw FileError.badColor(key.stringValue) }
            return value
        }
        id = (try? c.decodeIfPresent(UUID.self, forKey: .id)) ?? UUID()
        name = Self.cleanName((try? c.decodeIfPresent(String.self, forKey: .name)) ?? "")
        isDark = (try? c.decodeIfPresent(Bool.self, forKey: .dark)) ?? true
        gradient = (try? c.decodeIfPresent(Bool.self, forKey: .gradient)) ?? false
        background = try color(.background)
        surface = try color(.surface)
        text = try color(.text)
        accent = try color(.accent)
        backgroundEnd = (try? color(.backgroundEnd)) ?? background
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Self.fileFormat, forKey: .format)
        try c.encode(Self.fileVersion, forKey: .version)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(isDark, forKey: .dark)
        try c.encode(gradient, forKey: .gradient)
        try c.encode(ColorMath.hexString(background), forKey: .background)
        try c.encode(ColorMath.hexString(backgroundEnd), forKey: .backgroundEnd)
        try c.encode(ColorMath.hexString(surface), forKey: .surface)
        try c.encode(ColorMath.hexString(text), forKey: .text)
        try c.encode(ColorMath.hexString(accent), forKey: .accent)
    }

    /// JSON for sharing. The id is left out so an import always makes a new theme.
    public func exportData() throws -> Data {
        var copy = self
        copy.id = UUID()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(copy)
        // Drop the throwaway id from the file.
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return data }
        object.removeValue(forKey: CodingKeys.id.stringValue)
        return try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    }

    /// Reads a shared theme file. Always gets a fresh id.
    public static func importing(_ data: Data, existing: [CustomTheme] = []) throws -> CustomTheme {
        var theme = try JSONDecoder().decode(CustomTheme.self, from: data)
        theme.id = UUID()
        theme.name = uniqueName(theme.name, existing: existing)
        return theme
    }
}

/// Small helpers for 0xRRGGBB colors.
public enum ColorMath {
    /// Linear blend in sRGB: `t` = 0 gives `a`, 1 gives `b`.
    public static func mix(_ a: UInt32, _ b: UInt32, _ t: Double) -> UInt32 {
        let t = min(max(t, 0), 1)
        func channel(_ shift: UInt32) -> UInt32 {
            let x = Double((a >> shift) & 0xFF), y = Double((b >> shift) & 0xFF)
            return UInt32((x + (y - x) * t).rounded()) << shift
        }
        return channel(16) | channel(8) | channel(0)
    }

    /// Accepts "#RRGGBB", "RRGGBB", "#RGB" (any case).
    public static func parseHex(_ string: String) -> UInt32? {
        var s = string.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6, let value = UInt32(s, radix: 16) else { return nil }
        return value
    }

    public static func hexString(_ value: UInt32) -> String {
        String(format: "#%06X", value & 0xFFFFFF)
    }
}
