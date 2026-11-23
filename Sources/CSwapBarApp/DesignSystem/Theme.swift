import AppKit
import CSwapBarCore
import SwiftUI

// MARK: - Typography

/// Type scale tuned for macOS (13 pt body, like menus and Control Center).
struct Typography {
    let design: Font.Design
    let scale: CGFloat
    /// Design for big figures. Widget-style themes use SF Rounded, like macOS widgets.
    var figureDesign: Font.Design

    init(font: FontChoice = .system, size: TextSizeChoice = .standard, roundedFigures: Bool = false) {
        design = switch font {
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        case .mono: .monospaced
        }
        scale = CGFloat(size.scale)
        figureDesign = (roundedFigures && font == .system) ? .rounded : design
    }

    private func figure(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        .system(size: (size * scale * 2).rounded() / 2, weight: weight, design: figureDesign).monospacedDigit()
    }

    func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: (size * scale * 2).rounded() / 2, weight: weight, design: design)
    }

    var largeTitle: Font { font(22, .bold) }
    var appTitle: Font { font(15, .semibold) }
    var title: Font { font(14, .semibold) }
    var body: Font { font(13) }
    var caption: Font { font(12) }
    var footnote: Font { font(11) }
    /// Uppercase section labels ("5-HOUR").
    var label: Font { font(10.5, .semibold) }
    var badge: Font { font(11, .semibold) }
    /// Big usage figures. Tabular digits so numbers don't jitter.
    var metric: Font { figure(figureDesign == .rounded ? 24 : 22, figureDesign == .rounded ? .bold : .semibold) }
    var metricCompact: Font { figure(18, .semibold) }
    var metricSmall: Font { figure(13, .semibold) }
    var metricUnit: Font { figure(13, .semibold) }
    /// Number inside a ring gauge.
    func ringFigure(_ size: CGFloat) -> Font { figure(size, .semibold) }

    func icon(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size * scale, weight: weight)
    }
}

// MARK: - Theme

/// Resolved colors, materials, and type for the current settings.
/// Read it with `@Environment(\.theme)`.
struct Theme {
    let palette: ThemePalette
    let text: Color
    let muted: Color
    let accent: Color
    /// Label color on accent-filled controls, picked for contrast.
    let onAccent: Color
    /// Same, for large/bold labels (sidebar selection), which need only 3:1.
    let onAccentLarge: Color
    let border: Color
    /// Unfilled part of bars and rings. Always visible, even when card borders aren't.
    let track: Color
    let healthy: Color
    let warning: Color
    let high: Color
    let critical: Color
    let type: Typography
    let compact: Bool
    let layout: CardLayout

    private let solidBackground: Color
    private let solidSurface: Color
    private let solidElevated: Color

    static let popoverWidth: CGFloat = 420

    /// Widgets use the big macOS widget corner radius.
    var cardRadius: CGFloat {
        switch style {
        case .widget: 20
        case .gradient: 18
        default: 14
        }
    }

    var style: ThemeStyle { palette.style }
    var colorScheme: ColorScheme { palette.isDark ? .dark : .light }
    var spacing: CGFloat { compact ? 10 : 14 }

    init(
        palette: ThemePalette,
        accent accentChoice: AccentChoice = .themeDefault,
        font: FontChoice = .system,
        size: TextSizeChoice = .standard,
        compact: Bool = false,
        layout: CardLayout = .meters
    ) {
        self.palette = palette
        self.type = Typography(font: font, size: size, roundedFigures: palette.style == .widget)
        self.compact = compact
        self.layout = layout

        // macOS accent for "macOS accent", and by default on the native theme.
        let useSystemAccent = palette.style != .gradient
            && (accentChoice == .system || (accentChoice == .themeDefault && palette.style == .native))
        let accentHex = useSystemAccent
            ? (NSColor.controlAccentColor.hexValue ?? palette.accent)
            : accentChoice.color(on: palette)
        accent = Color(hex: accentHex)
        let darkInk: UInt32 = palette.isDark ? palette.background : palette.text
        onAccent = ColorContrast.ratio(0xFFFFFF, accentHex) >= 4.5 ? .white : Color(hex: darkInk)
        onAccentLarge = ColorContrast.ratio(0xFFFFFF, accentHex) >= 3 ? .white : Color(hex: darkInk)

        if palette.style == .native {
            text = .primary
            muted = .secondary
            border = .primary.opacity(0.1)
        } else {
            text = Color(hex: palette.text)
            muted = Color(hex: palette.muted)
            border = switch palette.style {
            case .glass: .primary.opacity(0.12)
            case .gradient: .white.opacity(0.14)
            case .widget: Color(hex: palette.border).opacity(palette.isDark ? 0 : 0.6)
            default: Color(hex: palette.border)
            }
        }
        track = switch palette.style {
        case .gradient: .white.opacity(0.16)
        case .native, .glass: .primary.opacity(0.12)
        default: Color(hex: palette.border)
        }
        healthy = Color(hex: palette.healthy)
        warning = Color(hex: palette.warning)
        high = Color(hex: palette.high)
        critical = Color(hex: palette.critical)
        solidBackground = Color(hex: palette.background)
        solidSurface = Color(hex: palette.surface)
        solidElevated = Color(hex: palette.elevated)
    }

    init(settings: AppSettings, systemIsDark: Bool) {
        self.init(
            palette: settings.theme.palette(systemIsDark: systemIsDark),
            accent: settings.accent,
            font: settings.font,
            size: settings.textSize,
            compact: settings.compactCards,
            layout: settings.cardLayout
        )
    }

    static let `default` = Theme(palette: .atelierDark)

    /// Popover / window background.
    var windowBackground: AnyShapeStyle {
        switch style {
        case .solid: AnyShapeStyle(solidBackground)
        case .native: AnyShapeStyle(.regularMaterial)
        case .glass: AnyShapeStyle(.ultraThinMaterial)
        case .widget: AnyShapeStyle(.regularMaterial)
        case .gradient:
            AnyShapeStyle(LinearGradient(
                colors: [solidBackground, Color(hex: palette.backgroundEnd ?? palette.background)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ))
        }
    }

    /// Accent wash layered over glass.
    var windowTint: Color {
        style == .glass ? accent.opacity(palette.isDark ? 0.12 : 0.08) : .clear
    }

    /// Slightly darker/lighter than the window, for sidebars.
    var sidebarFill: AnyShapeStyle {
        switch style {
        case .solid: AnyShapeStyle(solidSurface.opacity(palette.isDark ? 0.6 : 0.7))
        case .native, .glass, .widget: AnyShapeStyle(Color.primary.opacity(0.04))
        case .gradient: AnyShapeStyle(Color.black.opacity(0.18))
        }
    }

    /// Translucent panel over the ambient Settings background.
    var panelFill: AnyShapeStyle {
        switch style {
        case .solid, .widget: AnyShapeStyle(solidSurface.opacity(palette.isDark ? 0.62 : 0.72))
        case .native, .glass: AnyShapeStyle(Color.primary.opacity(0.05))
        case .gradient: AnyShapeStyle(Color.white.opacity(0.10))
        }
    }

    func cardFill(highlighted: Bool = false, hovered: Bool = false) -> AnyShapeStyle {
        let lifted = highlighted || hovered
        switch style {
        case .solid:
            return AnyShapeStyle(lifted ? solidElevated : solidSurface)
        case .native:
            return AnyShapeStyle(Color.primary.opacity(highlighted ? 0.085 : hovered ? 0.07 : 0.045))
        case .glass:
            let base = palette.isDark ? 0.06 : 0.5
            return AnyShapeStyle(Color.white.opacity(lifted ? base + (palette.isDark ? 0.05 : 0.2) : base))
        case .widget:
            // Opaque tiles like Notification Center widgets.
            return AnyShapeStyle(lifted ? solidElevated : solidSurface)
        case .gradient:
            return AnyShapeStyle(Color.white.opacity(lifted ? 0.14 : 0.10))
        }
    }

    func color(for level: UsageLevel) -> Color {
        switch level {
        case .healthy: healthy
        case .warning: warning
        case .high: high
        case .critical: critical
        case .unknown: muted
        }
    }
}

private struct SnapshotKey: EnvironmentKey {
    static let defaultValue = false
}

private struct ThemeKey: EnvironmentKey {
    static let defaultValue = Theme.default
}

private struct SnapshotHeightKey: EnvironmentKey {
    static let defaultValue: CGFloat? = nil
}

extension EnvironmentValues {
    /// Fixed popover height for uniform snapshots (`--height`); nil in the app.
    var snapshotHeight: CGFloat? {
        get { self[SnapshotHeightKey.self] }
        set { self[SnapshotHeightKey.self] = newValue }
    }

    /// True while rendering to an image (`--render-*`), where ScrollView can't draw.
    var isSnapshot: Bool {
        get { self[SnapshotKey.self] }
        set { self[SnapshotKey.self] = newValue }
    }

    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

/// Resolves the user's theme setting (including adaptive themes) and injects it.
struct ThemedRoot: ViewModifier {
    let settings: AppSettings
    @Environment(\.colorScheme) private var systemScheme

    func body(content: Content) -> some View {
        let theme = Theme(settings: settings, systemIsDark: systemScheme == .dark)
        content
            .environment(\.theme, theme)
            .environment(\.colorScheme, theme.colorScheme)
            .tint(theme.accent)
    }
}

extension View {
    func themed(_ settings: AppSettings) -> some View {
        modifier(ThemedRoot(settings: settings))
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

extension NSColor {
    /// 0xRRGGBB in sRGB, for contrast checks against dynamic system colors.
    var hexValue: UInt32? {
        guard let rgb = usingColorSpace(.sRGB) else { return nil }
        func byte(_ c: CGFloat) -> UInt32 { UInt32((min(max(c, 0), 1) * 255).rounded()) }
        return byte(rgb.redComponent) << 16 | byte(rgb.greenComponent) << 8 | byte(rgb.blueComponent)
    }
}

// MARK: - Components

/// Rounded card on the theme's surface, with hover lift.
struct CardBackground: ViewModifier {
    var highlighted = false
    var hovered = false
    var padding: CGFloat?
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.cardRadius, style: .continuous)
        let lightShadow = !theme.palette.isDark && (theme.style == .solid || theme.style == .widget)
        content
            .padding(padding ?? theme.spacing)
            .background(theme.cardFill(highlighted: highlighted, hovered: hovered), in: shape)
            .overlay(shape.strokeBorder(highlighted ? theme.accent.opacity(0.55) : theme.border, lineWidth: highlighted ? 1.5 : 1))
            .shadow(color: .black.opacity(lightShadow ? (theme.style == .widget ? 0.08 : 0.05) : 0),
                    radius: theme.style == .widget ? 6 : 3, y: theme.style == .widget ? 2 : 1)
    }
}

extension View {
    func card(highlighted: Bool = false, hovered: Bool = false, padding: CGFloat? = nil) -> some View {
        modifier(CardBackground(highlighted: highlighted, hovered: hovered, padding: padding))
    }
}

/// Accent-filled capsule button whose label always contrasts with the accent.
struct AccentButtonStyle: ButtonStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(theme.type.font(12, .semibold))
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(theme.onAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(theme.accent.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
            .opacity(isEnabled ? 1 : 0.45)
    }
}

/// Borderless button drawn entirely in SwiftUI (renders in snapshots too).
struct QuietButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(isEnabled ? (configuration.isPressed ? 0.55 : 1) : 0.35)
    }
}

extension ButtonStyle where Self == QuietButtonStyle {
    static var quiet: QuietButtonStyle { QuietButtonStyle() }
}

/// Round toolbar icon button with a hover highlight, like macOS title-bar controls.
struct ToolbarIconButton: View {
    let symbol: String
    let help: String
    var active = false
    let action: () -> Void

    @Environment(\.theme) private var theme
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(theme.type.icon(13, .medium))
                .foregroundStyle(active ? theme.accent : theme.muted)
                .frame(width: 28, height: 28)
                .background(Circle().fill(Color.primary.opacity(hovered ? 0.08 : 0)))
        }
        .buttonStyle(.quiet)
        .onHover { hovered = $0 }
        .help(help)
    }
}

struct Badge: View {
    let text: String
    let color: Color
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .font(theme.type.badge)
            .lineLimit(1)
            .fixedSize()
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
    }
}
