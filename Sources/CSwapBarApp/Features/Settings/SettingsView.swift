import AppKit
import CSwapBarCore
import SwiftUI

enum SettingsPane: String, CaseIterable, Identifiable {
    case general, notifications, switching, history, appearance, layout, widgets, privacy, about

    var id: Self { self }

    var title: String {
        switch self {
        case .general: "General"
        case .notifications: "Notifications"
        case .switching: "Switching"
        case .history: "History"
        case .appearance: "Appearance"
        case .layout: "Layout"
        case .widgets: "Widgets"
        case .privacy: "Privacy"
        case .about: "About"
        }
    }

    /// Monochrome outline icons for the sidebar.
    var symbol: String {
        switch self {
        case .general: "slider.horizontal.3"
        case .notifications: "bell"
        case .switching: "arrow.triangle.2.circlepath"
        case .history: "chart.xyaxis.line"
        case .appearance: "paintpalette"
        case .layout: "rectangle.3.group"
        case .widgets: "square.grid.2x2"
        case .privacy: "lock.shield"
        case .about: "sparkles"
        }
    }
}

/// Settings window: ambient background, floating glass sidebar, pages.
struct SettingsView: View {
    @Bindable var model: AppModel

    init(model: AppModel, initialPane: SettingsPane? = nil) {
        self.model = model
        if let initialPane { model.settingsPane = initialPane }
    }

    var body: some View {
        SettingsShell(model: model, pane: $model.settingsPane)
            .themed(model.settings)
    }
}

private struct SettingsShell: View {
    @Bindable var model: AppModel
    @Binding var pane: SettingsPane
    @Environment(\.theme) private var theme
    @Environment(\.isSnapshot) private var isSnapshot

    static let windowWidth: CGFloat = SettingsShellMetrics.width
    static let sidebarWidth: CGFloat = 224
    static let detailWidth: CGFloat = windowWidth - sidebarWidth

    var body: some View {
        if isSnapshot {
            // Fixed size, so renders are uniform.
            HStack(spacing: 0) {
                sidebar.frame(width: Self.sidebarWidth)
                paddedPage
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: Self.detailWidth)
            }
            .frame(width: Self.windowWidth)
            .background(AmbientBackground())
        } else {
            // Resizable: the sidebar keeps its width, the page grows. Never smaller
            // than the original size, so controls never squeeze or wrap.
            HStack(spacing: 0) {
                sidebar.frame(width: Self.sidebarWidth)
                ScrollView {
                    paddedPage
                        .frame(maxWidth: SettingsShellMetrics.maxPageWidth)
                        .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.automatic)
                .frame(minWidth: Self.detailWidth, maxWidth: .infinity)
            }
            .frame(minWidth: Self.windowWidth, maxWidth: .infinity,
                   minHeight: SettingsShellMetrics.minHeight, maxHeight: .infinity)
            .background(AmbientBackground())
        }
    }

    private var paddedPage: some View {
        page
            .padding(.horizontal, 32)
            .padding(.top, isSnapshot ? 28 : 40)
            .padding(.bottom, 32)
            .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    /// Floating glass panel, inset from the window edges.
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                AppGlyph(size: 34)
                VStack(alignment: .leading, spacing: 1) {
                    Text("CSwapBar")
                        .font(theme.type.font(15, .bold))
                        .tracking(-0.2)
                        .foregroundStyle(theme.text)
                    Text("Settings")
                        .font(theme.type.footnote)
                        .foregroundStyle(theme.muted)
                }
            }
            .padding(.horizontal, 6)
            .padding(.top, 4)
            .padding(.bottom, 18)

            ForEach(Array(SettingsPane.allCases.enumerated()), id: \.element) { offset, item in
                SidebarItem(pane: item, isSelected: pane == item) {
                    withAnimation(.easeOut(duration: 0.18)) { pane = item }
                }
                .help("\(item.title) (⌘\(offset + 1))")
                // ⌘1, ⌘2… jump to each page.
                .background {
                    if offset < 9 {
                        Button(item.title) { withAnimation(.easeOut(duration: 0.18)) { pane = item } }
                            .keyboardShortcut(KeyEquivalent(Character("\(offset + 1)")), modifiers: .command)
                            .opacity(0)
                            .frame(width: 0, height: 0)
                            .accessibilityHidden(true)
                    }
                }
            }

            Spacer()

            // Quick Privacy Mode switch, always reachable.
            HStack(spacing: 8) {
                Image(systemName: model.privacy.privacyModeEnabled ? "eye.slash.fill" : "eye")
                    .font(theme.type.icon(12))
                    .foregroundStyle(model.privacy.privacyModeEnabled ? theme.accent : theme.muted)
                Text("Privacy Mode")
                    .font(theme.type.caption)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .fixedSize()
                Spacer(minLength: 4)
                Toggle("Privacy Mode", isOn: $model.settings.privacy.privacyModeEnabled)
                    .toggleStyle(.themedSwitch)
                    .labelsHidden()
            }
            .padding(10)
            .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            // ⌘W closes the window (an accessory app has no menu bar to provide it).
            Button("Close") { NSApp.keyWindow?.close() }
                .keyboardShortcut("w")
                .opacity(0)
                .frame(width: 0, height: 0)
                .accessibilityHidden(true)
        }
        .padding(12)
        .frame(maxHeight: .infinity, alignment: .top)
        .glassPanel(cornerRadius: 18)
        .padding(.leading, 10)
        .padding(.trailing, 4)
        .padding(.bottom, 10)
        .padding(.top, isSnapshot ? 10 : 38)   // clear the traffic lights
    }

    @ViewBuilder
    private var page: some View {
        switch pane {
        case .general: GeneralPage(model: model)
        case .notifications: NotificationsPage(model: model)
        case .switching: SwitchingPage(model: model)
        case .history: HistoryPage(model: model)
        case .appearance: AppearancePage(model: model)
        case .layout: LayoutPage(model: model)
        case .widgets: WidgetsPage(model: model)
        case .privacy: PrivacyPage(model: model)
        case .about: AboutPage()
        }
    }
}

private struct SidebarItem: View {
    let pane: SettingsPane
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: pane.symbol)
                    .font(theme.type.icon(13, isSelected ? .semibold : .regular))
                    .frame(width: 20)
                    .foregroundStyle(isSelected ? theme.onAccentLarge : theme.muted)
                Text(pane.title)
                    .font(theme.type.font(13, isSelected ? .semibold : .medium))
                    .foregroundStyle(isSelected ? theme.onAccentLarge : theme.text)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background {
                let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
                if isSelected {
                    shape
                        .fill(LinearGradient(colors: [theme.accent, theme.accent.opacity(0.78)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(shape.strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
                        .shadow(color: theme.accent.opacity(0.45), radius: 10, y: 3)
                } else {
                    shape.fill(Color.primary.opacity(hovered ? 0.06 : 0))
                }
            }
        }
        .buttonStyle(.quiet)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - General

private struct GeneralPage: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsPageHeader(title: "General", subtitle: "Menu bar, refresh, the CSwap connection, and updates.")

            SettingsGroup("Startup", footer: loginFooter) {
                SettingsRow("Open at login", subtitle: loginSubtitle, symbol: "power") {
                    HStack(spacing: 8) {
                        if model.loginItem.state == .needsApproval {
                            Button("Allow…") { model.loginItem.openSystemSettings() }
                                .buttonStyle(AccentButtonStyle())
                        }
                        Toggle("Open at login", isOn: Binding(
                            get: { model.loginItem.state == .on || model.loginItem.state == .needsApproval },
                            set: { model.loginItem.set($0) }))
                            .toggleStyle(.themedSwitch).labelsHidden()
                            .disabled(model.loginItem.state == .unavailable)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                model.loginItem.refresh()
            }

            SettingsGroup("Menu Bar", footer: model.settings.usageIsland.enabled
                          ? "The menu bar icon is hidden while CSwapBar lives in the Usage Island. Style options are in Widgets." : nil) {
                SettingsRow("Show CSwapBar in", symbol: "macwindow") {
                    ThemedSegmented(selection: $model.settings.usageIsland.enabled,
                                    options: [(false, "Menu bar"), (true, "Usage Island")])
                }
                RowDivider()
                SettingsRow("Show next to the icon", symbol: "menubar.rectangle") {
                    ThemedSegmented(selection: $model.settings.menuBarDisplay, options: [
                        (.iconOnly, "Icon"), (.accountName, "Name"), (.fiveHourUsage, "5-hour"), (.peakUsage, "Highest"),
                    ])
                }
                .opacity(model.settings.usageIsland.enabled ? 0.45 : 1)
                .disabled(model.settings.usageIsland.enabled)
            }

            SettingsGroup("Refresh", footer: "CSwap caches usage, so refreshing often is cheap.") {
                SettingsRow("Refresh every", symbol: "arrow.clockwise") {
                    ThemedSegmented(selection: $model.settings.refreshIntervalSeconds, options: [
                        (30, "30s"), (60, "1m"), (120, "2m"), (300, "5m"),
                    ])
                }
            }

            SettingsGroup("CSwap") {
                SettingsRow("Status", subtitle: statusDetail, symbol: "link") {
                    HStack(spacing: 6) {
                        Circle().fill(statusColor).frame(width: 8, height: 8)
                        Text(statusText).font(theme.type.caption).foregroundStyle(theme.muted)
                    }
                }
                RowDivider()
                SettingsRow("Executable", subtitle: executableDetail, symbol: "terminal") {
                    HStack(spacing: 8) {
                        if model.settings.cswapPath != nil {
                            Button("Automatic") { model.settings.cswapPath = nil }
                                .buttonStyle(.quiet)
                                .font(theme.type.caption)
                                .foregroundStyle(theme.muted)
                        }
                        Button("Choose…", action: chooseExecutable)
                            .buttonStyle(AccentButtonStyle())
                    }
                }
                RowDivider()
                SettingsRow("Reconnect", subtitle: "Re-detect CSwap after installing or upgrading it.", symbol: "bolt.horizontal") {
                    Button("Reconnect") {
                        Task {
                            await model.reconnect()
                            await model.checkCSwapMenubarIfDue(force: true)
                        }
                    }
                    .buttonStyle(AccentButtonStyle())
                }
            }

            if let menubar = model.cswapMenubar, menubar.isPresent {
                CSwapMenubarNotice(status: menubar)
            }

            KeyboardSection(model: model)

            UpdatesSection(model: model)
        }
    }

    private var loginSubtitle: String? {
        switch model.loginItem.state {
        case .needsApproval: "Waiting for your OK in System Settings → General → Login Items."
        case .unavailable: "Available in the app bundle (scripts/build.sh), not with swift run."
        case .on, .off: model.loginItem.lastError
        }
    }

    private var loginFooter: String? {
        Bundle.main.bundleURL.deletingLastPathComponent().lastPathComponent == "Applications" || model.loginItem.state == .unavailable
            ? nil
            : "Tip: move CSwapBar to Applications first, so the login item keeps pointing at the right copy."
    }

    private var executableDetail: String {
        if let path = model.settings.cswapPath {
            return "Set by you: \(path)"
        }
        return "Found automatically in ~/.local/bin, Homebrew, or your PATH."
    }

    /// Lets the user point at a `cswap` installed somewhere unusual.
    private func chooseExecutable() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.showsHiddenFiles = true
        panel.treatsFilePackagesAsDirectories = true
        panel.message = "Choose the cswap executable (for example ~/.local/bin/cswap)"
        panel.prompt = "Use This"
        if let path = model.settings.cswapPath {
            panel.directoryURL = URL(fileURLWithPath: (path as NSString).deletingLastPathComponent)
        } else {
            panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".local/bin")
        }
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        model.settings.cswapPath = url.path
    }

    private var statusText: String {
        switch model.connection {
        case .connecting: "Connecting…"
        case .connected(let install): "CSwap \(install.version)"
        case .notInstalled: "Not installed"
        case .unsupported(let version): "\(version) unsupported"
        case .failed: "Error"
        }
    }

    private var statusDetail: String? {
        switch model.connection {
        case .connected(let install): install.executable.path
        case .failed(let message): message
        case .notInstalled: model.settings.cswapPath.map { "No working cswap at \($0). Choose another, or use Automatic." }
            ?? "Install with: uv tool install claude-swap"
        default: nil
        }
    }

    private var statusColor: Color {
        switch model.connection {
        case .connected: theme.healthy
        case .connecting: theme.muted
        case .unsupported: theme.warning
        case .notInstalled, .failed: theme.critical
        }
    }
}

// MARK: - Notifications

private struct NotificationsPage: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme

    private var prefs: NotificationPreferences { model.settings.notifications }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsPageHeader(title: "Notifications",
                               subtitle: "Usage alerts, account switches, and logins. The wording follows your privacy settings.")

            permissionBanner

            SettingsGroup {
                SettingsRow("Allow notifications", symbol: "bell.badge") {
                    Toggle("Allow notifications", isOn: $model.settings.notifications.enabled)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
                RowDivider()
                SettingsRow("Play a sound", symbol: "speaker.wave.2") {
                    Toggle("Play a sound", isOn: $model.settings.notifications.playSound)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
                .dimmed(!prefs.enabled)
            }

            SettingsGroup("Usage", footer: "Each level alerts once, then again after usage drops back (for example, when the window resets).") {
                SettingsRow("Usage alerts", subtitle: "For the 5-hour and weekly windows of every account.", symbol: "gauge.with.dots.needle.67percent") {
                    Toggle("Usage alerts", isOn: $model.settings.notifications.usageAlerts)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
                RowDivider()
                SettingsRow("Alert at", symbol: "chart.bar") {
                    HStack(spacing: 6) {
                        ForEach(NotificationPreferences.availableLevels, id: \.self) { level in
                            LevelChip(level: level, isOn: prefs.isLevelEnabled(level)) {
                                model.settings.notifications.setLevel(level, enabled: !prefs.isLevelEnabled(level))
                            }
                        }
                    }
                }
                .dimmed(!prefs.usageAlerts)
            }
            .dimmed(!prefs.enabled)

            SettingsGroup("Accounts") {
                SettingsRow("Account switches",
                            subtitle: "When CSwap or the terminal changes the active account, and when a switch from CSwapBar fails.",
                            symbol: "arrow.left.arrow.right") {
                    Toggle("Account switches", isOn: $model.settings.notifications.switchAlerts)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
                RowDivider()
                SettingsRow("Login needed", subtitle: "When an account needs a new login before CSwap can use it.",
                            symbol: "person.badge.key") {
                    Toggle("Login needed", isOn: $model.settings.notifications.loginAlerts)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
            }
            .dimmed(!prefs.enabled)

            SettingsGroup {
                SettingsRow("Send a test notification", subtitle: "Check how alerts look with your current privacy settings.",
                            symbol: "paperplane") {
                    Button("Send test") { model.sendTestNotification() }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(!prefs.enabled || model.notifier.permission == .unsupported)
                }
            }
        }
        // Re-check while the page is open, so changes made in System Settings show up right away.
        .task {
            while !Task.isCancelled {
                await model.notifier.refreshPermission()
                try? await Task.sleep(for: .seconds(2))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await model.notifier.refreshPermission() }
        }
    }

    @ViewBuilder
    private var permissionBanner: some View {
        switch model.notifier.permission {
        case .denied:
            banner("Notifications are turned off for CSwapBar in System Settings.", symbol: "bell.slash") {
                Button("Open System Settings") { model.notifier.openSystemSettings() }
                    .buttonStyle(AccentButtonStyle())
            }
        case .unsupported:
            banner("Notifications need the app bundle. Build it with scripts/build.sh instead of swift run.",
                   symbol: "shippingbox") { EmptyView() }
        case .allowed, .unknown:
            EmptyView()
        }
    }

    private func banner<Control: View>(_ text: String, symbol: String, @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(theme.type.icon(15, .semibold))
                .foregroundStyle(theme.warning)
            Text(text)
                .font(theme.type.caption)
                .foregroundStyle(theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            control()
        }
        .card()
    }
}

/// Toggleable percentage chip.
private struct LevelChip: View {
    let level: Int
    let isOn: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            Text("\(level)%")
                .font(theme.type.font(12, .semibold).monospacedDigit())
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(isOn ? theme.onAccent : theme.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isOn ? AnyShapeStyle(theme.accent) : AnyShapeStyle(Color.primary.opacity(0.06)), in: Capsule())
                .overlay(Capsule().strokeBorder(isOn ? .clear : theme.border, lineWidth: 1))
        }
        .buttonStyle(.quiet)
        .accessibilityLabel("Alert at \(level) percent")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

private extension View {
    /// Greys out and disables controls that have no effect right now.
    func dimmed(_ off: Bool) -> some View {
        opacity(off ? 0.45 : 1).disabled(off)
    }
}

// MARK: - Appearance

private struct AppearancePage: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsPageHeader(title: "Appearance", subtitle: "Themes, your own colors, shape, and type. Changes apply instantly.")

            LivePreview(model: model)

            ForEach(ThemeChoice.Group.allCases, id: \.self) { group in
                VStack(alignment: .leading, spacing: 10) {
                    Text(group.rawValue.uppercased())
                        .font(theme.type.label)
                        .tracking(0.8)
                        .foregroundStyle(theme.muted)
                        .padding(.leading, 4)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ThemeChoice.choices(in: group), id: \.self) { choice in
                            ThemeTile(choice: choice, accent: model.settings.accent,
                                      isSelected: model.settings.customThemeID == nil && model.settings.theme == choice) {
                                model.settings.selectBuiltInTheme(choice)
                            }
                        }
                    }
                }
            }

            CustomThemesSection(model: model)

            ShapeSection(model: model)

            SettingsGroup("Accent Color", footer: theme.style == .gradient ? "Vivid themes use white controls, so the accent color doesn't apply." : nil) {
                AccentRow(selection: $model.settings.accent, palette: theme.palette)
                    .padding(14)
            }

            SettingsGroup("Typography") {
                HStack(spacing: 10) {
                    ForEach(FontChoice.allCases, id: \.self) { font in
                        FontTile(font: font, isSelected: model.settings.font == font) { model.settings.font = font }
                    }
                }
                .padding(12)
                RowDivider()
                SettingsRow("Text size", symbol: "textformat.size") {
                    ThemedSegmented(selection: $model.settings.textSize, options: TextSizeChoice.allCases.map { ($0, $0.title) })
                }
            }
        }
    }
}

private struct ThemeTile: View {
    let choice: ThemeChoice
    let accent: AccentChoice
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        SelectableTile(isSelected: isSelected, action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    if let variants = choice.adaptiveVariants {
                        HStack(spacing: 0) {
                            MiniPopover(palette: variants.dark, accent: accent)
                            MiniPopover(palette: variants.light, accent: accent)
                        }
                    } else if let palette = choice.fixedPalette {
                        MiniPopover(palette: palette, accent: accent)
                    }
                }
                .frame(height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(theme.border, lineWidth: 1))

                VStack(alignment: .leading, spacing: 1) {
                    Text(choice.title)
                        .font(theme.type.font(12.5, .semibold))
                        .foregroundStyle(theme.text)
                    Text(choice.tagline)
                        .font(theme.type.footnote)
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                }
                .padding(.horizontal, 2)
            }
        }
        .accessibilityLabel("\(choice.title) theme")
    }
}

/// A miniature popover painted in one palette.
struct MiniPopover: View {
    let palette: ThemePalette
    let accent: AccentChoice

    var body: some View {
        let accentColor = Color(hex: accent.color(on: palette))
        ZStack {
            Color(hex: palette.background)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(accentColor).frame(width: 9, height: 9)
                    Capsule().fill(Color(hex: palette.text)).frame(width: 30, height: 4)
                    Spacer(minLength: 0)
                }
                HStack(spacing: 6) {
                    meter(Color(hex: palette.healthy), 0.4)
                    meter(Color(hex: palette.high), 0.82)
                }
                .padding(6)
                .background(Color(hex: palette.surface), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(accentColor.opacity(0.6), lineWidth: 1))
            }
            .padding(8)
        }
    }

    private func meter(_ color: Color, _ fraction: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Capsule().fill(Color(hex: palette.text)).frame(width: 14, height: 5)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: palette.border))
                    Capsule().fill(color).frame(width: proxy.size.width * fraction)
                }
            }
            .frame(height: 3)
        }
    }
}

private struct AccentRow: View {
    @Binding var selection: AccentChoice
    let palette: ThemePalette
    @Environment(\.theme) private var theme

    private let columns = [GridItem(.adaptive(minimum: 34, maximum: 40), spacing: 6)]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 6) {
                ForEach(AccentChoice.allCases, id: \.self) { choice in
                    Button { selection = choice } label: {
                        ZStack {
                            Circle().fill(swatchColor(choice)).frame(width: 24, height: 24)
                            if choice == .themeDefault {
                                Image(systemName: "paintpalette.fill").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                            } else if choice == .system {
                                Image(systemName: "apple.logo").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.9))
                            }
                            if selection == choice {
                                Circle().strokeBorder(theme.text.opacity(0.85), lineWidth: 2).frame(width: 31, height: 31)
                            }
                        }
                        .frame(width: 34, height: 34)
                    }
                    .buttonStyle(.quiet)
                    .help(choice.title)
                    .accessibilityLabel("\(choice.title) accent")
                    .accessibilityAddTraits(selection == choice ? .isSelected : [])
                }
            }
            Text(selection.title)
                .font(theme.type.caption)
                .foregroundStyle(theme.muted)
        }
    }

    private func swatchColor(_ choice: AccentChoice) -> Color {
        if choice == .system { return Color(nsColor: .controlAccentColor) }
        return Color(hex: choice.color(on: palette))
    }
}

private struct FontTile: View {
    let font: FontChoice
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    private var design: Font.Design {
        switch font {
        case .system: .default
        case .rounded: .rounded
        case .serif: .serif
        case .mono: .monospaced
        }
    }

    var body: some View {
        SelectableTile(isSelected: isSelected, action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Aa 42%")
                    .font(.system(size: 20, weight: .semibold, design: design))
                    .foregroundStyle(theme.text)
                Text(font.title)
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
            }
            .padding(4)
        }
        .accessibilityLabel("\(font.title) font")
    }
}

// MARK: - Layout

private struct LayoutPage: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsPageHeader(title: "Layout", subtitle: "Choose how accounts are drawn in the menu-bar popover.")

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(CardLayout.allCases, id: \.self) { layout in
                    SelectableTile(isSelected: model.settings.cardLayout == layout) {
                        model.settings.cardLayout = layout
                        model.settings.accountsPerPage = layout.suggestedPageSize
                    } content: {
                        VStack(alignment: .leading, spacing: 8) {
                            LayoutSchematic(layout: layout)
                                .frame(height: 86)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(layout.title).font(theme.type.font(13, .semibold)).foregroundStyle(theme.text)
                                Text(layout.summary).font(theme.type.footnote).foregroundStyle(theme.muted)
                            }
                            .padding(.horizontal, 2)
                        }
                    }
                    .accessibilityLabel("\(layout.title) layout")
                }
            }

            SettingsGroup("Size", footer: "The popover grows to fit one page. Fewer accounts per page means a shorter popover.") {
                SettingsRow("Accounts per page", symbol: "square.stack") {
                    ThemedSegmented(selection: $model.settings.accountsPerPage,
                                    options: AccountPaging.pageSizeOptions.map { ($0, "\($0)") })
                }
                RowDivider()
                SettingsRow("Compact density", subtitle: "Tighter spacing and smaller figures.", symbol: "arrow.down.right.and.arrow.up.left") {
                    Toggle("Compact density", isOn: $model.settings.compactCards)
                        .toggleStyle(.themedSwitch)
                        .labelsHidden()
                }
            }

            UsageColorsSection(model: model)

            LivePreview(model: model)
        }
    }
}

/// Abstract drawing of each layout for its tile.
private struct LayoutSchematic: View {
    let layout: CardLayout
    @Environment(\.theme) private var theme

    var body: some View {
        let line = theme.muted.opacity(0.45)
        VStack(spacing: 5) {
            ForEach(0..<(layout == .list ? 4 : 2), id: \.self) { index in
                Group {
                    switch layout {
                    case .meters:
                        VStack(alignment: .leading, spacing: 4) {
                            header(line)
                            HStack(spacing: 8) { bigMeter(theme.healthy, 0.4); bigMeter(theme.high, 0.8) }
                        }
                    case .classic:
                        VStack(alignment: .leading, spacing: 4) {
                            header(line)
                            bar(theme.healthy, 0.4)
                            bar(theme.warning, 0.65)
                        }
                    case .rings:
                        VStack(alignment: .leading, spacing: 4) {
                            header(line)
                            HStack(spacing: 10) { ring(theme.healthy, 0.4); ring(theme.high, 0.8); Spacer() }
                        }
                    case .list:
                        HStack(spacing: 5) {
                            Circle().fill(index == 0 ? theme.accent : line).frame(width: 7, height: 7)
                            Capsule().fill(line).frame(width: 34, height: 4)
                            Spacer()
                            bar(index.isMultiple(of: 2) ? theme.healthy : theme.high, index.isMultiple(of: 2) ? 0.35 : 0.75).frame(width: 30)
                        }
                    }
                }
                .padding(5)
                .background(theme.cardFill(highlighted: index == 0), in: RoundedRectangle(cornerRadius: 4))
                .overlay(RoundedRectangle(cornerRadius: 4).strokeBorder(index == 0 ? theme.accent.opacity(0.6) : theme.border, lineWidth: 1))
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
    }

    private func header(_ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(theme.accent.opacity(0.6)).frame(width: 7, height: 7)
            Capsule().fill(color).frame(width: 36, height: 4)
            Spacer()
        }
    }

    private func bar(_ color: Color, _ fraction: CGFloat) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(theme.border)
                Capsule().fill(color).frame(width: proxy.size.width * fraction)
            }
        }
        .frame(height: 3)
    }

    private func bigMeter(_ color: Color, _ fraction: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Capsule().fill(theme.text.opacity(0.8)).frame(width: 14, height: 6)
            bar(color, fraction)
        }
    }

    private func ring(_ color: Color, _ fraction: CGFloat) -> some View {
        ZStack {
            Circle().stroke(theme.border, lineWidth: 3)
            Circle().trim(from: 0, to: fraction).stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round)).rotationEffect(.degrees(-90))
        }
        .frame(width: 16, height: 16)
    }
}

/// Real account cards, in the current theme and layout, with fake sample accounts.
struct LivePreview: View {
    let model: AppModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LIVE PREVIEW")
                .font(theme.type.label)
                .tracking(0.8)
                .foregroundStyle(theme.muted)
                .padding(.leading, 4)
            VStack(spacing: theme.layout == .list ? 6 : 10) {
                ForEach(SampleData.accounts(count: theme.layout == .list ? 4 : 2)) { account in
                    AccountCard(
                        account: account,
                        presentation: AccountPresenter.present(account, preferences: model.settings.privacy),
                        thresholds: model.thresholds,
                        switchState: .idle,
                        switchingDisabled: false,
                        now: Date()
                    ) {}
                }
            }
            .padding(16)
            .background(theme.windowTint)
            .background(theme.windowBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.border, lineWidth: 1))
            .allowsHitTesting(false)
        }
    }
}

// MARK: - Widgets

private struct WidgetsPage: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme
    @Environment(\.resetWidgetPositions) private var resetPositions

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsPageHeader(title: "Desktop Widgets",
                               subtitle: "Compact widgets on your desktop. Drag to move; right-click for options.")

            ForEach(DesktopWidgetKind.allCases, id: \.self) { kind in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kind.title).font(theme.type.title).foregroundStyle(theme.text)
                            Text(kind.summary).font(theme.type.footnote).foregroundStyle(theme.muted)
                        }
                        Spacer()
                        Toggle(kind.title, isOn: binding(for: kind))
                            .toggleStyle(.themedSwitch)
                            .labelsHidden()
                    }
                    DesktopWidgetView(kind: kind, model: model)
                        .allowsHitTesting(false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .card(highlighted: model.settings.desktopWidgets.contains(kind))
            }

            SettingsGroup("Placement") {
                SettingsRow("Keep above other windows", subtitle: "Off: widgets sit on the desktop, behind your windows.",
                            symbol: "rectangle.stack") {
                    Toggle("Keep above other windows", isOn: $model.settings.widgetsFloatOnTop)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
                RowDivider()
                SettingsRow("Reset positions", subtitle: "Stack widgets in the top-right corner again.",
                            symbol: "arrow.uturn.backward") {
                    Button("Reset") { resetPositions() }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(model.settings.desktopWidgets.isEmpty)
                }
            }

            UsageIslandSection(model: model)
        }
    }

    private func binding(for kind: DesktopWidgetKind) -> Binding<Bool> {
        Binding {
            model.settings.desktopWidgets.contains(kind)
        } set: { isOn in
            if isOn {
                if !model.settings.desktopWidgets.contains(kind) { model.settings.desktopWidgets.append(kind) }
            } else {
                model.settings.desktopWidgets.removeAll { $0 == kind }
            }
        }
    }
}

// MARK: - Privacy

private struct PrivacyPage: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme

    private var overridden: Bool { model.settings.privacy.privacyModeEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsPageHeader(title: "Privacy", subtitle: "Hide account details for screen sharing and recording.")

            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(theme.accent.opacity(0.15))
                    Image(systemName: overridden ? "eye.slash.fill" : "eye.fill")
                        .font(theme.type.icon(20, .semibold))
                        .foregroundStyle(theme.accent)
                }
                .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Privacy Mode").font(theme.type.title).foregroundStyle(theme.text)
                    Text(shortcutSummary)
                        .font(theme.type.caption)
                        .foregroundStyle(theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Toggle("Privacy Mode", isOn: $model.settings.privacy.privacyModeEnabled)
                    .toggleStyle(.themedSwitch)
                    .labelsHidden()
            }
            .card(highlighted: overridden)

            SettingsGroup("Keyboard Shortcut", footer: "Works in any app, even when the popover is closed. Use ⌘, ⌃ or ⌥ in the combination.") {
                SettingsRow("Global shortcut", subtitle: shortcutStatusText, symbol: "command") {
                    Toggle("Global shortcut", isOn: $model.settings.privacyShortcutEnabled)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
                RowDivider()
                SettingsRow("Toggle Privacy Mode", subtitle: "Click, then press the keys you want.", symbol: "keyboard") {
                    HStack(spacing: 8) {
                        if model.settings.privacyShortcut != .defaultPrivacyToggle {
                            Button("Reset") { model.settings.privacyShortcut = .defaultPrivacyToggle }
                                .buttonStyle(.quiet)
                                .font(theme.type.caption)
                                .foregroundStyle(theme.muted)
                        }
                        ShortcutRecorder(model: model, shortcut: $model.settings.privacyShortcut,
                                         isEnabled: $model.settings.privacyShortcutEnabled)
                    }
                }
                .opacity(model.settings.privacyShortcutEnabled ? 1 : 0.45)
            }

            SettingsGroup("Identity", footer: overridden ? "Privacy Mode is on, so all identity details are hidden." : nil) {
                identityRow("Hide account emails", "envelope", $model.settings.privacy.hideEmails)
                RowDivider()
                identityRow("Hide account names", "person.text.rectangle", $model.settings.privacy.hideAliases)
                RowDivider()
                identityRow("Hide account IDs", "number", $model.settings.privacy.hideAccountIDs)
                RowDivider()
                identityRow("Hide organization names", "building.2", $model.settings.privacy.hideOrganization)
                RowDivider()
                identityRow("Hide subscription details", "creditcard", $model.settings.privacy.hideSubscriptionDetails)
                RowDivider()
                identityRow("Hide notification details", "bell.badge", $model.settings.privacy.hideNotificationDetails)
                RowDivider()
                SettingsRow("Use generic account names", subtitle: "\"Account 01\" instead of names.", symbol: "textformat.123") {
                    Toggle("Use generic account names", isOn: $model.settings.privacy.useGenericAccountNames)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
            }

            SettingsGroup("Usage") {
                SettingsRow("Hide usage percentages", symbol: "percent") {
                    Toggle("Hide usage percentages", isOn: $model.settings.privacy.hideUsagePercentages)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
                RowDivider()
                SettingsRow("Hide reset times", symbol: "clock") {
                    Toggle("Hide reset times", isOn: $model.settings.privacy.hideResetTimestamps)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
            }

            Label("Privacy Mode hides information on screen only. It doesn't protect files, processes, or memory on this Mac.",
                  systemImage: "info.circle")
                .font(theme.type.footnote)
                .foregroundStyle(theme.muted)
        }
    }

    private var shortcutSummary: String {
        let base = "Hides emails, names, organizations, and plans everywhere."
        guard model.settings.privacyShortcutEnabled, model.privacyShortcutStatus != .unavailable else {
            return base + " Shortcut: ⇧⌘P in the menu."
        }
        return base + " Shortcut: \(model.settings.privacyShortcut.displayString) anywhere."
    }

    private var shortcutStatusText: String? {
        guard model.settings.privacyShortcutEnabled else { return "Off. ⇧⌘P still works while the popover is open." }
        return switch model.privacyShortcutStatus {
        case .unavailable: "\(model.settings.privacyShortcut.displayString) is used by another app. Pick a different one."
        case .active: "Active: \(model.settings.privacyShortcut.displayString) toggles Privacy Mode from any app."
        case .off: nil
        }
    }

    /// Shows as on (and disabled) while Privacy Mode overrides it.
    private func identityRow(_ title: String, _ symbol: String, _ binding: Binding<Bool>) -> some View {
        SettingsRow(title, symbol: symbol) {
            Toggle(title, isOn: overridden ? .constant(true) : binding)
                .toggleStyle(.themedSwitch)
                .labelsHidden()
                .disabled(overridden)
        }
    }
}

// MARK: - About

private struct AboutPage: View {
    @Environment(\.theme) private var theme

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var body: some View {
        VStack(spacing: 22) {
            VStack(spacing: 10) {
                AppIconView(size: 96)
                Text("CSwapBar").font(theme.type.largeTitle).foregroundStyle(theme.text)
                Text("Version \(version)").font(theme.type.body).foregroundStyle(theme.muted)
                Text("A native macOS menu bar for CSwap.")
                    .font(theme.type.body)
                    .foregroundStyle(theme.text)
                Badge(text: "Unofficial — not affiliated with CSwap or Anthropic", color: theme.muted)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 10)

            SettingsGroup("Made by") {
                SettingsRow("@iamv1n", subtitle: "Designer & developer of CSwapBar", symbol: "person.crop.circle") {
                    Link("github.com/iamv1n", destination: URL(string: "https://github.com/iamv1n")!)
                        .font(theme.type.font(12, .semibold))
                        .foregroundStyle(theme.accent)
                }
            }

            SettingsGroup("Credits") {
                SettingsRow("Built on CSwap (claude-swap)", subtitle: "by Onur Cetinkol · MIT License", symbol: "heart") {
                    Link("GitHub", destination: URL(string: "https://github.com/realiti4/claude-swap")!)
                        .font(theme.type.font(12, .semibold))
                        .foregroundStyle(theme.accent)
                }
                RowDivider()
                SettingsRow("CSwapBar", subtitle: "Open source under the MIT License", symbol: "chevron.left.forwardslash.chevron.right") {
                    EmptyView()
                }
            }
        }
    }
}

/// Shared with StatusItemController so the window and layout agree.
enum SettingsShellMetrics {
    /// Smallest (and default) window width.
    static let width: CGFloat = 800
    static let defaultHeight: CGFloat = 640
    static let minHeight: CGFloat = 520
    /// Pages stop widening here and center, so lines stay readable on big windows.
    static let maxPageWidth: CGFloat = 920
}
