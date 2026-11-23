import Foundation

/// How a theme paints surfaces.
public enum ThemeStyle: String, Sendable, Equatable {
    /// Opaque colors from the palette.
    case solid
    /// macOS system materials (vibrancy), system text colors, system accent.
    case native
    /// Translucent frosted glass tinted by the accent.
    case glass
    /// Like macOS widgets: system colors, borderless rounded tiles over the
    /// system material, big SF Rounded figures.
    case widget
    /// Vivid gradient background with frosted cards (`background` → `backgroundEnd`).
    case gradient
}

/// A complete set of color tokens, as 0xRRGGBB. Kept UI-free so contrast can be unit-tested.
///
/// For `.native` and `.glass` themes the app replaces surfaces and text with
/// macOS semantic colors and materials; the hex values here are the closest
/// opaque equivalents and are what the contrast tests check.
public struct ThemePalette: Sendable, Equatable {
    public let name: String
    public let isDark: Bool

    public let background: UInt32
    public let surface: UInt32
    public let elevated: UInt32
    public let border: UInt32
    public let text: UInt32
    public let muted: UInt32
    /// The theme's own accent, used when the accent setting is "Theme default".
    public let accent: UInt32

    // Usage bands.
    public let healthy: UInt32
    public let warning: UInt32
    public let high: UInt32
    public let critical: UInt32

    public var style: ThemeStyle = .solid
    /// Second gradient stop for `.gradient` themes (top → bottom).
    public var backgroundEnd: UInt32? = nil
}

public enum ThemeChoice: String, CaseIterable, Codable, Sendable {
    // Adaptive: follow macOS light/dark.
    case system
    case native
    case glass
    case widgets
    // Vivid gradients
    case sky
    case sunset
    case aurora
    // Dark
    case atelierDark
    case graphite
    case midnight
    case forest
    case espresso
    case plum
    case ocean
    case ember
    case mono
    // Light
    case atelierLight
    case paper
    case sandstone
    case lavender
    case mint
    // High contrast
    case highContrastDark
    case highContrastLight

    public enum Group: String, CaseIterable, Sendable {
        case adaptive = "Adaptive"
        case vivid = "Vivid"
        case dark = "Dark"
        case light = "Light"
        case highContrast = "High Contrast"
    }

    public var group: Group {
        switch self {
        case .system, .native, .glass, .widgets: .adaptive
        case .sky, .sunset, .aurora: .vivid
        case .atelierDark, .graphite, .midnight, .forest, .espresso, .plum, .ocean, .ember, .mono: .dark
        case .atelierLight, .paper, .sandstone, .lavender, .mint: .light
        case .highContrastDark, .highContrastLight: .highContrast
        }
    }

    public static func choices(in group: Group) -> [ThemeChoice] {
        allCases.filter { $0.group == group }
    }

    /// Dark and light palettes for adaptive themes; `nil` for fixed ones.
    public var adaptiveVariants: (dark: ThemePalette, light: ThemePalette)? {
        switch self {
        case .system: (.atelierDark, .atelierLight)
        case .native: (.nativeDark, .nativeLight)
        case .glass: (.glassDark, .glassLight)
        case .widgets: (.widgetsDark, .widgetsLight)
        default: nil
        }
    }

    public var fixedPalette: ThemePalette? {
        switch self {
        case .system, .native, .glass, .widgets: nil
        case .sky: .sky
        case .sunset: .sunset
        case .aurora: .aurora
        case .atelierDark: .atelierDark
        case .graphite: .graphite
        case .midnight: .midnight
        case .forest: .forest
        case .espresso: .espresso
        case .plum: .plum
        case .ocean: .ocean
        case .ember: .ember
        case .mono: .mono
        case .atelierLight: .atelierLight
        case .paper: .paper
        case .sandstone: .sandstone
        case .lavender: .lavender
        case .mint: .mint
        case .highContrastDark: .highContrastDark
        case .highContrastLight: .highContrastLight
        }
    }

    public func palette(systemIsDark: Bool) -> ThemePalette {
        if let variants = adaptiveVariants { return systemIsDark ? variants.dark : variants.light }
        return fixedPalette!
    }

    public var title: String {
        switch self {
        case .system: "Atelier Auto"
        case .native: "macOS"
        case .glass: "Glass"
        case .widgets: "macOS Widgets"
        default: fixedPalette?.name ?? rawValue
        }
    }

    public var tagline: String {
        switch self {
        case .system: "Atelier, follows light/dark"
        case .native: "System materials & accent"
        case .glass: "Frosted, translucent"
        case .widgets: "System colors, like Calendar & Battery"
        case .sky: "Deep blue gradient"
        case .sunset: "Berry to wine gradient"
        case .aurora: "Teal to violet gradient"
        case .atelierDark: "Warm charcoal, terracotta"
        case .graphite: "Neutral, cool grey"
        case .midnight: "Deep navy, indigo"
        case .forest: "Pine green, brass"
        case .espresso: "Roasted brown, caramel"
        case .plum: "Dark plum, rosé"
        case .ocean: "Deep sea, aqua"
        case .ember: "Black, glowing orange"
        case .mono: "Pure greyscale"
        case .atelierLight: "Warm paper, clay"
        case .paper: "Crisp white, ink blue"
        case .sandstone: "Sunlit beige, rust"
        case .lavender: "Soft lilac, violet"
        case .mint: "Fresh mint, pine"
        case .highContrastDark: "Maximum legibility, dark"
        case .highContrastLight: "Maximum legibility, light"
        }
    }
}

// MARK: - Palettes

extension ThemePalette {
    /// Every palette, including both variants of adaptive themes.
    public static let all: [ThemePalette] = [
        .atelierDark, .atelierLight, .nativeDark, .nativeLight, .glassDark, .glassLight,
        .widgetsDark, .widgetsLight, .sky, .sunset, .aurora,
        .graphite, .midnight, .forest, .espresso, .plum, .ocean, .ember, .mono,
        .paper, .sandstone, .lavender, .mint,
        .highContrastDark, .highContrastLight,
    ]

    // Adaptive -------------------------------------------------------------

    /// The reference palette: warm charcoal and terracotta.
    public static let atelierDark = ThemePalette(
        name: "Atelier Dark", isDark: true,
        background: 0x191817, surface: 0x252321, elevated: 0x292624, border: 0x3C3732,
        text: 0xF0E8DE, muted: 0xA99D91, accent: 0xD77D60,
        healthy: 0x89A77D, warning: 0xD4A66E, high: 0xDB8A56, critical: 0xD96D63
    )

    public static let atelierLight = ThemePalette(
        name: "Atelier Light", isDark: false,
        background: 0xF7F3ED, surface: 0xFFFDFA, elevated: 0xF0EAE1, border: 0xE2D9CC,
        text: 0x2A2521, muted: 0x6E6359, accent: 0xB9583A,
        healthy: 0x4F7D45, warning: 0x9A6A1F, high: 0xB25A22, critical: 0xB83B32
    )

    /// Opaque approximations of macOS dark-mode window colors.
    public static let nativeDark = ThemePalette(
        name: "macOS Dark", isDark: true,
        background: 0x1E1E1E, surface: 0x2A2A2A, elevated: 0x323232, border: 0x3D3D3D,
        text: 0xE5E5E5, muted: 0x9D9DA2, accent: 0x409CFF,
        healthy: 0x30D158, warning: 0xFFD60A, high: 0xFF9F0A, critical: 0xFF453A,
        style: .native
    )

    public static let nativeLight = ThemePalette(
        name: "macOS Light", isDark: false,
        background: 0xECECEC, surface: 0xFFFFFF, elevated: 0xF5F5F5, border: 0xD9D9D9,
        text: 0x1D1D1F, muted: 0x636368, accent: 0x0068DA,
        healthy: 0x248A3D, warning: 0x946800, high: 0xC24E00, critical: 0xD70015,
        style: .native
    )

    public static let glassDark = ThemePalette(
        name: "Glass Dark", isDark: true,
        background: 0x1C1D22, surface: 0x2A2C33, elevated: 0x31343C, border: 0x464953,
        text: 0xF2F3F7, muted: 0xA9ACB8, accent: 0x7FB2FF,
        healthy: 0x5FD08A, warning: 0xF0C75E, high: 0xF5A05A, critical: 0xF5736B,
        style: .glass
    )

    public static let glassLight = ThemePalette(
        name: "Glass Light", isDark: false,
        background: 0xE9ECF2, surface: 0xF8F9FC, elevated: 0xEEF1F6, border: 0xD3D8E2,
        text: 0x1A1D24, muted: 0x5D6372, accent: 0x2C5FD4,
        healthy: 0x237D4B, warning: 0x8A6410, high: 0xAE4F16, critical: 0xC0352D,
        style: .glass
    )

    /// Apple system colors as used by Notification Center widgets (dark).
    public static let widgetsDark = ThemePalette(
        name: "macOS Widgets Dark", isDark: true,
        background: 0x1C1C1E, surface: 0x2C2C2E, elevated: 0x3A3A3C, border: 0x3A3A3C,
        text: 0xFFFFFF, muted: 0xA6A6AD, accent: 0x409CFF,
        healthy: 0x30D158, warning: 0xFFD60A, high: 0xFF9F0A, critical: 0xFF453A,
        style: .widget
    )

    /// Light widgets use Apple's higher-contrast system color variants so
    /// usage colors stay readable on white tiles.
    public static let widgetsLight = ThemePalette(
        name: "macOS Widgets Light", isDark: false,
        background: 0xF2F2F7, surface: 0xFFFFFF, elevated: 0xF2F2F7, border: 0xE5E5EA,
        text: 0x000000, muted: 0x6C6C70, accent: 0x0062D6,
        healthy: 0x248A3D, warning: 0x9A6A00, high: 0xC93400, critical: 0xD70015,
        style: .widget
    )

    // Vivid: gradients. surface/elevated are the frosted-card composites. ----

    public static let sky = ThemePalette(
        name: "Sky", isDark: true,
        background: 0x18418E, surface: 0x2B4A85, elevated: 0x34528A, border: 0x476295,
        text: 0xFFFFFF, muted: 0xD0D7E4, accent: 0xFFFFFF,
        healthy: 0x7EF0A0, warning: 0xFFE070, high: 0xFFB066, critical: 0xFF9C9C,
        style: .gradient, backgroundEnd: 0x0E2B60
    )

    public static let sunset = ThemePalette(
        name: "Sunset", isDark: true,
        background: 0x7A2852, surface: 0x793855, elevated: 0x7F415C, border: 0x8B536C,
        text: 0xFFFFFF, muted: 0xE1D3D9, accent: 0xFFFFFF,
        healthy: 0x8CF0A8, warning: 0xFFE07A, high: 0xFFB870, critical: 0xFFA3A3,
        style: .gradient, backgroundEnd: 0x5A1D33
    )

    public static let aurora = ThemePalette(
        name: "Aurora", isDark: true,
        background: 0x0E4442, surface: 0x334762, elevated: 0x3C5069, border: 0x4E6077,
        text: 0xFFFFFF, muted: 0xD2D6DC, accent: 0xFFFFFF,
        healthy: 0x7CF0B4, warning: 0xFFE27A, high: 0xFFB475, critical: 0xFF9AA0,
        style: .gradient, backgroundEnd: 0x2A2260
    )

    // Dark -----------------------------------------------------------------

    public static let graphite = ThemePalette(
        name: "Graphite", isDark: true,
        background: 0x161719, surface: 0x202124, elevated: 0x28292D, border: 0x36383D,
        text: 0xECEDEF, muted: 0x9C9FA7, accent: 0x8EA7FF,
        healthy: 0x6CC08E, warning: 0xE0B65E, high: 0xE98C4E, critical: 0xEB6A62
    )

    public static let midnight = ThemePalette(
        name: "Midnight", isDark: true,
        background: 0x0E1320, surface: 0x161D2D, elevated: 0x1D2539, border: 0x2B3550,
        text: 0xE6EAF3, muted: 0x929DB4, accent: 0x9B97FF,
        healthy: 0x5FCBA4, warning: 0xE8BC62, high: 0xF09157, critical: 0xF26C68
    )

    public static let forest = ThemePalette(
        name: "Forest", isDark: true,
        background: 0x121815, surface: 0x1A231E, elevated: 0x212C26, border: 0x31403A,
        text: 0xE7EEE6, muted: 0x9AAA9F, accent: 0xD0AE6E,
        healthy: 0x8CC07D, warning: 0xDDB765, high: 0xE08F57, critical: 0xDD6A61
    )

    public static let espresso = ThemePalette(
        name: "Espresso", isDark: true,
        background: 0x1A1411, surface: 0x241C18, elevated: 0x2C231E, border: 0x3E322B,
        text: 0xF3E9E1, muted: 0xB09F92, accent: 0xD9A066,
        healthy: 0x8FB77F, warning: 0xE0B566, high: 0xE28C58, critical: 0xE06C62
    )

    public static let plum = ThemePalette(
        name: "Plum", isDark: true,
        background: 0x1A1219, surface: 0x241A23, elevated: 0x2C202B, border: 0x3F2F3D,
        text: 0xF2E8F0, muted: 0xB39DB0, accent: 0xE58FB4,
        healthy: 0x7FC4A0, warning: 0xE5BC6A, high: 0xEE9160, critical: 0xF0727A
    )

    public static let ocean = ThemePalette(
        name: "Ocean", isDark: true,
        background: 0x0C1719, surface: 0x132225, elevated: 0x182A2E, border: 0x253D42,
        text: 0xE3F0F1, muted: 0x8FAEB2, accent: 0x4FD1C5,
        healthy: 0x6CD39A, warning: 0xE8C064, high: 0xF0965A, critical: 0xF07068
    )

    public static let ember = ThemePalette(
        name: "Ember", isDark: true,
        background: 0x121110, surface: 0x1B1A18, elevated: 0x22201E, border: 0x33302C,
        text: 0xF2EFEA, muted: 0xA39E96, accent: 0xFF8A3D,
        healthy: 0x7DC383, warning: 0xE8BD5A, high: 0xFF9550, critical: 0xF2665C
    )

    public static let mono = ThemePalette(
        name: "Mono", isDark: true,
        background: 0x111111, surface: 0x1B1B1B, elevated: 0x222222, border: 0x333333,
        text: 0xF2F2F2, muted: 0xA3A3A3, accent: 0xE6E6E6,
        healthy: 0x9BC59A, warning: 0xDCC27A, high: 0xE39B6A, critical: 0xE8736B
    )

    // Light ----------------------------------------------------------------

    public static let paper = ThemePalette(
        name: "Paper", isDark: false,
        background: 0xF5F6F8, surface: 0xFFFFFF, elevated: 0xEDEFF2, border: 0xDADEE4,
        text: 0x1C1F24, muted: 0x5F6673, accent: 0x2F63E0,
        healthy: 0x24804F, warning: 0x8F6A0C, high: 0xB3541A, critical: 0xC0352D
    )

    public static let sandstone = ThemePalette(
        name: "Sandstone", isDark: false,
        background: 0xF4EEE4, surface: 0xFCF8F2, elevated: 0xEFE6D8, border: 0xDDD0BD,
        text: 0x2B241C, muted: 0x6C5F50, accent: 0xA4502A,
        healthy: 0x4E7A3F, warning: 0x8C6514, high: 0xA84F17, critical: 0xB0372E
    )

    public static let lavender = ThemePalette(
        name: "Lavender", isDark: false,
        background: 0xF3F1F8, surface: 0xFFFFFF, elevated: 0xEEEBF6, border: 0xDCD7EA,
        text: 0x221E2E, muted: 0x645E78, accent: 0x6C4FD6,
        healthy: 0x2B8050, warning: 0x8A6410, high: 0xB0521C, critical: 0xBD3548
    )

    public static let mint = ThemePalette(
        name: "Mint", isDark: false,
        background: 0xEFF6F2, surface: 0xFFFFFF, elevated: 0xE6F0EA, border: 0xD2E2D8,
        text: 0x18241D, muted: 0x56685D, accent: 0x1F7A57,
        healthy: 0x2C7D45, warning: 0x8A6611, high: 0xAE5219, critical: 0xBD3A33
    )

    // High contrast --------------------------------------------------------

    public static let highContrastDark = ThemePalette(
        name: "High Contrast Dark", isDark: true,
        background: 0x000000, surface: 0x0D0D0D, elevated: 0x161616, border: 0x8C8C8C,
        text: 0xFFFFFF, muted: 0xD0D0D0, accent: 0x5CB8FF,
        healthy: 0x5EE38A, warning: 0xFFD24D, high: 0xFF9F43, critical: 0xFF6B6B
    )

    public static let highContrastLight = ThemePalette(
        name: "High Contrast Light", isDark: false,
        background: 0xFFFFFF, surface: 0xFFFFFF, elevated: 0xF2F2F2, border: 0x5C5C5C,
        text: 0x000000, muted: 0x333333, accent: 0x0050B5,
        healthy: 0x006B2E, warning: 0x7A5600, high: 0x9C3D00, critical: 0xB00020
    )
}

// MARK: - Accent

/// Optional accent override, applied on top of any theme.
public enum AccentChoice: String, CaseIterable, Codable, Sendable {
    case themeDefault
    /// The user's macOS accent color (System Settings → Appearance).
    case system
    case terracotta
    case coral
    case amber
    case sage
    case teal
    case blue
    case indigo
    case violet
    case rose
    case red
    case graphite

    public var title: String {
        switch self {
        case .themeDefault: "Theme default"
        case .system: "macOS accent"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }

    /// Accent hex for this choice on the given palette. Light themes get deeper
    /// variants so the accent stays readable on white. `.system` resolves at
    /// runtime in the app; this returns the palette's accent as its stand-in.
    public func color(on palette: ThemePalette) -> UInt32 {
        // Vivid gradient themes always use white controls; a colored accent
        // can't stay readable across a colored gradient.
        if palette.style == .gradient { return palette.accent }
        guard let pair = variants else { return palette.accent }
        return palette.isDark ? pair.dark : pair.light
    }

    private var variants: (dark: UInt32, light: UInt32)? {
        switch self {
        case .themeDefault, .system: nil
        case .terracotta: (0xD77D60, 0xAA4E32)
        case .coral: (0xF08A7A, 0xBC4836)
        case .amber: (0xE3B35F, 0x8C600F)
        case .sage: (0x9DBB8E, 0x4F7D45)
        case .teal: (0x5EC4BC, 0x167A73)
        case .blue: (0x6FA8FF, 0x2F63E0)
        case .indigo: (0x9B97FF, 0x5149D6)
        case .violet: (0xC08CF5, 0x8343C9)
        case .rose: (0xF28DB2, 0xC23B72)
        case .red: (0xFF6961, 0xD70015)
        case .graphite: (0xB4B4BB, 0x5C5C61)
        }
    }
}

// MARK: - Typography

public enum FontChoice: String, CaseIterable, Codable, Sendable {
    case system
    case rounded
    case serif
    case mono

    public var title: String {
        switch self {
        case .system: "SF Pro"
        case .rounded: "SF Pro Rounded"
        case .serif: "New York"
        case .mono: "SF Mono"
        }
    }
}

public enum TextSizeChoice: String, CaseIterable, Codable, Sendable {
    case small
    case standard
    case large

    public var title: String {
        switch self {
        case .small: "Small"
        case .standard: "Default"
        case .large: "Large"
        }
    }

    public var scale: Double {
        switch self {
        case .small: 0.92
        case .standard: 1
        case .large: 1.12
        }
    }
}

// MARK: - Contrast

/// WCAG 2.x contrast helpers.
public enum ColorContrast {
    public static func luminance(_ hex: UInt32) -> Double {
        func channel(_ value: UInt32) -> Double {
            let c = Double(value) / 255
            return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel((hex >> 16) & 0xFF)
            + 0.7152 * channel((hex >> 8) & 0xFF)
            + 0.0722 * channel(hex & 0xFF)
    }

    public static func ratio(_ a: UInt32, _ b: UInt32) -> Double {
        let (la, lb) = (luminance(a), luminance(b))
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
