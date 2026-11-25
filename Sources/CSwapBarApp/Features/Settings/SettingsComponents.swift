import CSwapBarCore
import SwiftUI

/// Pane header: accent eyebrow, big tight title, one-line description.
struct SettingsPageHeader: View {
    let title: String
    let subtitle: String
    var eyebrow: String = "Settings"
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(eyebrow.uppercased())
                .font(theme.type.font(10.5, .bold))
                .tracking(1.4)
                .foregroundStyle(theme.accent)
            Text(title)
                .font(theme.type.font(28, .bold))
                .tracking(-0.6)
                .foregroundStyle(theme.text)
            Text(subtitle)
                .font(theme.type.body)
                .foregroundStyle(theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 4)
    }
}

/// Window background for Settings: theme background, two soft ambient glows
/// in the accent and brand plum, and a faint grid that fades out.
struct AmbientBackground: View {
    @Environment(\.theme) private var theme

    var body: some View {
        let dark = theme.palette.isDark
        ZStack {
            Rectangle().fill(theme.windowBackground)
            Rectangle().fill(theme.windowTint)
            glow(theme.accent, opacity: dark ? 0.30 : 0.16, diameter: 760)
                .offset(x: -300, y: -280)
            glow(Color(hex: 0x8E3B8F), opacity: dark ? 0.24 : 0.10, diameter: 700)
                .offset(x: 340, y: 300)
            GridLines(spacing: 28)
                .stroke(theme.text.opacity(dark ? 0.045 : 0.05), lineWidth: 0.5)
                .mask(RadialGradient(colors: [.black, .clear], center: .topTrailing, startRadius: 0, endRadius: 700))
        }
        .clipped()
        .ignoresSafeArea()
    }

    /// A soft light: a radial gradient that fades to nothing (no blur filter needed).
    private func glow(_ color: Color, opacity: Double, diameter: CGFloat) -> some View {
        Circle()
            .fill(RadialGradient(colors: [color.opacity(opacity), color.opacity(opacity * 0.35), .clear],
                                 center: .center, startRadius: 0, endRadius: diameter / 2))
            .frame(width: diameter, height: diameter)
    }
}

private struct GridLines: Shape {
    let spacing: CGFloat
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var x = rect.minX
        while x <= rect.maxX { path.move(to: CGPoint(x: x, y: rect.minY)); path.addLine(to: CGPoint(x: x, y: rect.maxY)); x += spacing }
        var y = rect.minY
        while y <= rect.maxY { path.move(to: CGPoint(x: rect.minX, y: y)); path.addLine(to: CGPoint(x: rect.maxX, y: y)); y += spacing }
        return path
    }
}

/// Translucent glass panel with a hairline gradient border.
struct GlassPanel: ViewModifier {
    var cornerRadius: CGFloat = 16
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let dark = theme.palette.isDark
        content
            .background(theme.panelFill, in: shape)
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [Color.primary.opacity(dark ? 0.16 : 0.10), Color.primary.opacity(dark ? 0.04 : 0.05)],
                                   startPoint: .top, endPoint: .bottom),
                    lineWidth: 1
                )
            )
            .shadow(color: .black.opacity(dark ? 0.25 : 0.06), radius: 12, y: 4)
    }
}

extension View {
    func glassPanel(cornerRadius: CGFloat = 16) -> some View {
        modifier(GlassPanel(cornerRadius: cornerRadius))
    }
}

/// A titled group of rows on a card.
struct SettingsGroup<Content: View>: View {
    let title: String?
    var footer: String?
    @ViewBuilder let content: Content
    @Environment(\.theme) private var theme

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .font(theme.type.label)
                    .tracking(0.8)
                    .foregroundStyle(theme.muted)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) { content }
                .glassPanel()
            if let footer {
                Text(footer)
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.muted)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// Hairline between rows in a `SettingsGroup`.
struct RowDivider: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Divider().overlay(theme.border).padding(.leading, 14)
    }
}

/// Title (+ optional subtitle and icon) on the left, a control on the right.
struct SettingsRow<Control: View>: View {
    let title: String
    var subtitle: String?
    var symbol: String?
    /// Icon color; the accent by default.
    var symbolColor: Color?
    @ViewBuilder let control: Control
    @Environment(\.theme) private var theme

    init(_ title: String, subtitle: String? = nil, symbol: String? = nil, symbolColor: Color? = nil,
         @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.symbol = symbol
        self.symbolColor = symbolColor
        self.control = control()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let symbol {
                Image(systemName: symbol)
                    .font(theme.type.icon(14))
                    .foregroundStyle(symbolColor ?? theme.accent)
                    .frame(width: 22)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(theme.type.body)
                    .foregroundStyle(theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .font(theme.type.footnote)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 12)
            control
                .layoutPriority(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }
}

/// A switch drawn in the theme's colors.
struct ThemedSwitchStyle: ToggleStyle {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                Capsule()
                    .fill(configuration.isOn ? theme.accent : theme.border)
                    .frame(width: 38, height: 22)
                Circle()
                    .fill(.white)
                    .shadow(color: .black.opacity(0.2), radius: 1, y: 0.5)
                    .frame(width: 18, height: 18)
                    .padding(2)
            }
            .animation(.easeOut(duration: 0.15), value: configuration.isOn)
        }
        .buttonStyle(.quiet)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityElement()
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
    }
}

extension ToggleStyle where Self == ThemedSwitchStyle {
    static var themedSwitch: ThemedSwitchStyle { ThemedSwitchStyle() }
}

/// Segmented control drawn in the theme's colors.
struct ThemedSegmented<Value: Hashable>: View {
    @Binding var selection: Value
    let options: [(value: Value, label: String)]
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.value) { option in
                let selected = option.value == selection
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(theme.type.font(12, selected ? .semibold : .medium))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(selected ? theme.onAccent : theme.text)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .frame(minWidth: 36)
                        .background(selected ? theme.accent : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.quiet)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        // Keep every option on one line; the row's title gives way instead.
        .fixedSize()
    }
}

/// Selectable tile (themes, layouts, fonts).
struct SelectableTile<Content: View>: View {
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let content: Content
    @Environment(\.theme) private var theme
    @State private var hovered = false

    init(isSelected: Bool, action: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.action = action
        self.content = content()
    }

    var body: some View {
        Button(action: action) {
            content
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.cardFill(highlighted: isSelected, hovered: hovered),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(isSelected ? theme.accent : theme.border, lineWidth: isSelected ? 2 : 1)
                )
                .overlay(alignment: .topTrailing) {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(theme.type.icon(16, .semibold))
                            .foregroundStyle(theme.onAccent, theme.accent)
                            .padding(6)
                    }
                }
        }
        .buttonStyle(.quiet)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
