import AppKit
import CSwapBarCore
import SwiftUI
import UniformTypeIdentifiers

/// Shape options that apply on top of any theme (Settings → Appearance).
struct ShapeSection: View {
    @Bindable var model: AppModel

    var body: some View {
        SettingsGroup("Shape", footer: "Applies on top of any theme, built-in or custom.") {
            HStack(spacing: 8) {
                ForEach(CornerStyle.allCases, id: \.self) { style in
                    CornerTile(style: style, isSelected: model.settings.design.corners == style) {
                        model.settings.design.corners = style
                    }
                }
            }
            .padding(12)
            RowDivider()
            SettingsRow("Borders", symbol: "square.dashed") {
                ThemedSegmented(selection: $model.settings.design.borders,
                                options: BorderWeight.allCases.map { ($0, $0.title) })
            }
            RowDivider()
            SettingsRow("Bars and rings", symbol: "chart.bar.fill") {
                ThemedSegmented(selection: $model.settings.design.bars,
                                options: BarThickness.allCases.map { ($0, $0.title) })
            }
            RowDivider()
            SettingsRow("Buttons and badges", symbol: "capsule") {
                ThemedSegmented(selection: $model.settings.design.controls,
                                options: ControlShape.allCases.map { ($0, $0.title) })
            }
        }
    }
}

/// The user's own themes, shown with the built-in ones in Settings → Appearance,
/// plus the editor for the selected one.
struct CustomThemesSection: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme
    @State private var message: String?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            customThemesSection
            if let index = activeIndex {
                CustomThemeEditor(model: model, index: index, message: $message)
            }
        }
    }

    // MARK: Custom themes

    private var activeIndex: Int? {
        guard let id = model.settings.activeCustomTheme?.id else { return nil }
        return model.settings.customThemes.firstIndex { $0.id == id }
    }

    private var customThemesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("CUSTOM")
                    .font(theme.type.label)
                    .tracking(0.8)
                    .foregroundStyle(theme.muted)
                Spacer()
                Button("Import…", action: importTheme)
                    .buttonStyle(.quiet)
                    .font(theme.type.font(12, .semibold))
                    .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(model.settings.customThemes) { custom in
                    SelectableTile(isSelected: model.settings.customThemeID == custom.id) {
                        model.settings.customThemeID = custom.id
                    } content: {
                        VStack(alignment: .leading, spacing: 8) {
                            MiniPopover(palette: custom.palette, accent: .themeDefault)
                                .frame(height: 70)
                                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(theme.border, lineWidth: 1))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(custom.name)
                                    .font(theme.type.font(12.5, .semibold))
                                    .foregroundStyle(theme.text)
                                    .lineLimit(1)
                                Text(custom.isDark ? "Custom · Dark" : "Custom · Light")
                                    .font(theme.type.footnote)
                                    .foregroundStyle(theme.muted)
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .accessibilityLabel("\(custom.name) custom theme")
                }

                if model.settings.customThemes.count < CustomTheme.maxCount {
                    NewThemeTile(action: newTheme)
                }
            }

            if let message {
                Label(message, systemImage: "info.circle")
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.muted)
                    .padding(.horizontal, 4)
            }
        }
    }

    /// Starts from whatever is on screen now, so tweaking a built-in theme is one click.
    private func newTheme() {
        let base = model.settings.activeCustomTheme?.name ?? model.settings.theme.title
        let name = CustomTheme.uniqueName("\(base) Custom", existing: model.settings.customThemes)
        let custom = CustomTheme.based(on: theme.palette, name: name)
        if model.settings.addCustomTheme(custom) {
            message = "Made \(name) from the current theme. Edit its colors below."
        }
    }

    private func importTheme() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        panel.message = "Choose a CSwapBar theme file (.json)"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let data = try Data(contentsOf: url)
            let custom = try CustomTheme.importing(data, existing: model.settings.customThemes)
            if model.settings.addCustomTheme(custom) {
                message = "Imported \(custom.name)."
            } else {
                message = "You have \(CustomTheme.maxCount) themes already. Delete one to import another."
            }
        } catch CustomTheme.FileError.newerVersion {
            message = "That theme was made by a newer CSwapBar. Update CSwapBar to import it."
        } catch {
            message = "That file isn't a CSwapBar theme."
        }
    }
}

// MARK: - Editor

private struct CustomThemeEditor: View {
    @Bindable var model: AppModel
    let index: Int
    @Binding var message: String?
    @Environment(\.theme) private var theme
    @Environment(\.isSnapshot) private var isSnapshot

    private var custom: CustomTheme { model.settings.customThemes[index] }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsGroup("Edit \(custom.name)") {
                SettingsRow("Name", symbol: "character.cursor.ibeam") {
                    Group {
                        if isSnapshot {
                            Text(custom.name).frame(width: 200, alignment: .trailing)
                        } else {
                            TextField("Name", text: nameBinding)
                                .textFieldStyle(.plain)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 200)
                        }
                    }
                    .font(theme.type.body)
                    .foregroundStyle(theme.text)
                }
                RowDivider()
                SettingsRow("Appearance", symbol: "circle.lefthalf.filled") {
                    ThemedSegmented(selection: binding(.isDark), options: [(true, "Dark"), (false, "Light")])
                }
                RowDivider()
                SettingsRow("Background style", symbol: "square.fill.on.square") {
                    ThemedSegmented(selection: binding(.gradient), options: [(false, "Solid"), (true, "Gradient")])
                }
                RowDivider()
                colorRow(custom.gradient ? "Background top" : "Background color", .background)
                if custom.gradient {
                    RowDivider()
                    colorRow("Background bottom", .backgroundEnd)
                }
                RowDivider()
                colorRow("Cards", .surface)
                RowDivider()
                colorRow("Text", .text)
                RowDivider()
                colorRow("Accent", .accent)
            }

            readability

            HStack(spacing: 10) {
                Button("Duplicate", action: duplicate).buttonStyle(AccentButtonStyle())
                Button("Export…", action: export).buttonStyle(AccentButtonStyle())
                Spacer()
                Button(role: .destructive, action: delete) {
                    Label("Delete", systemImage: "trash")
                        .font(theme.type.font(12, .semibold))
                        .foregroundStyle(theme.critical)
                }
                .buttonStyle(.quiet)
            }
        }
    }

    @ViewBuilder
    private var readability: some View {
        let issues = custom.readabilityIssues
        if issues.isEmpty {
            Label("Readable: text and accent have enough contrast.", systemImage: "checkmark.seal")
                .font(theme.type.footnote)
                .foregroundStyle(theme.healthy)
                .padding(.horizontal, 4)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(issues, id: \.message) { issue in
                    Label("\(issue.message) (\(String(format: "%.1f", issue.ratio)):1)", systemImage: "exclamationmark.triangle")
                        .font(theme.type.footnote)
                        .foregroundStyle(theme.warning)
                }
            }
            .padding(.horizontal, 4)
        }
    }

    private func colorRow(_ title: String, _ slot: ColorSlot) -> some View {
        SettingsRow(title, symbol: "paintpalette") {
            ColorField(value: colorValue(slot))
        }
    }

    // MARK: Bindings (closures rather than key paths keep Swift 6 Sendable checks happy)

    private var nameBinding: Binding<String> {
        Binding(get: { custom.name }, set: { new in
            let trimmed = String(new.prefix(CustomTheme.maxNameLength))
            model.settings.customThemes[index].name = trimmed.isEmpty ? custom.name : trimmed
        })
    }

    private func binding(_ field: BoolField) -> Binding<Bool> {
        Binding(get: { field.get(custom) }, set: { model.settings.customThemes[index] = field.set(custom, $0) })
    }

    private func colorValue(_ slot: ColorSlot) -> Binding<UInt32> {
        Binding(get: { slot.get(custom) }, set: { model.settings.customThemes[index] = slot.set(custom, $0) })
    }

    // MARK: Actions

    private func duplicate() {
        var copy = custom
        copy.id = UUID()
        copy.name = CustomTheme.uniqueName(custom.name, existing: model.settings.customThemes)
        if model.settings.addCustomTheme(copy) {
            message = "Duplicated as \(copy.name)."
        } else {
            message = "You have \(CustomTheme.maxCount) themes already."
        }
    }

    private func export() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "\(custom.name).json"
        panel.message = "Share this file. Others can import it in Theme Studio."
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try custom.exportData().write(to: url, options: .atomic)
            message = "Exported \(custom.name)."
        } catch {
            message = "Couldn't save the theme: \(error.localizedDescription)"
        }
    }

    private func delete() {
        let name = custom.name
        model.settings.deleteCustomTheme(id: custom.id)
        message = "Deleted \(name). The previous built-in theme is back."
    }
}

private enum BoolField {
    case isDark, gradient

    func get(_ t: CustomTheme) -> Bool {
        switch self {
        case .isDark: t.isDark
        case .gradient: t.gradient
        }
    }

    func set(_ t: CustomTheme, _ value: Bool) -> CustomTheme {
        var t = t
        switch self {
        case .isDark: t.isDark = value
        case .gradient: t.gradient = value
        }
        return t
    }
}

private enum ColorSlot {
    case background, backgroundEnd, surface, text, accent

    func get(_ t: CustomTheme) -> UInt32 {
        switch self {
        case .background: t.background
        case .backgroundEnd: t.backgroundEnd
        case .surface: t.surface
        case .text: t.text
        case .accent: t.accent
        }
    }

    func set(_ t: CustomTheme, _ value: UInt32) -> CustomTheme {
        var t = t
        switch self {
        case .background: t.background = value
        case .backgroundEnd: t.backgroundEnd = value
        case .surface: t.surface = value
        case .text: t.text = value
        case .accent: t.accent = value
        }
        return t
    }
}

/// System color picker plus an editable hex value.
private struct ColorField: View {
    @Binding var value: UInt32
    @Environment(\.theme) private var theme
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var hexText = ""

    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isSnapshot {
                    Text(ColorMath.hexString(value)).frame(width: 74, alignment: .trailing)
                } else {
                    TextField("#RRGGBB", text: $hexText)
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 74)
                        .onSubmit(applyHex)
                }
            }
            .font(theme.type.font(12, .medium).monospaced())
            .foregroundStyle(theme.muted)
            if isSnapshot {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color(hex: value))
                    .frame(width: 40, height: 22)
                    .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(theme.border, lineWidth: 1))
            } else {
                ColorPicker("Color", selection: colorBinding, supportsOpacity: false)
                    .labelsHidden()
            }
        }
        .onAppear { hexText = ColorMath.hexString(value) }
        .onChange(of: value) { _, new in hexText = ColorMath.hexString(new) }
    }

    private var colorBinding: Binding<Color> {
        Binding(get: { Color(hex: value) }, set: { color in
            if let hex = NSColor(color).hexValue { value = hex }
        })
    }

    private func applyHex() {
        if let parsed = ColorMath.parseHex(hexText) {
            value = parsed
        } else {
            hexText = ColorMath.hexString(value)
        }
    }
}

/// Visual corner choice: a small square drawn with that radius.
private struct CornerTile: View {
    let style: CornerStyle
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                let radius = style == .themeDefault ? 8 : CGFloat(style.cardRadius(themeDefault: 14)) * 0.75
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .fill(isSelected ? theme.accent.opacity(0.18) : Color.primary.opacity(0.05))
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(isSelected ? theme.accent : theme.muted.opacity(0.6),
                                      style: StrokeStyle(lineWidth: isSelected ? 2 : 1.2, dash: style == .themeDefault ? [3, 3] : []))
                }
                .frame(width: 40, height: 30)
                Text(style.title)
                    .font(theme.type.font(11.5, isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? theme.text : theme.muted)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(isSelected ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.quiet)
        .accessibilityLabel("\(style.title) corners")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct NewThemeTile: View {
    let action: () -> Void
    @Environment(\.theme) private var theme
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(theme.type.icon(18, .semibold))
                    .foregroundStyle(theme.accent)
                Text("New theme")
                    .font(theme.type.font(12.5, .semibold))
                    .foregroundStyle(theme.text)
                Text("Starts from the current one")
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 112)
            .background(Color.primary.opacity(hovered ? 0.06 : 0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(theme.border, style: StrokeStyle(lineWidth: 1.2, dash: [5, 4])))
        }
        .buttonStyle(.quiet)
        .onHover { hovered = $0 }
        .accessibilityLabel("New custom theme")
    }
}
