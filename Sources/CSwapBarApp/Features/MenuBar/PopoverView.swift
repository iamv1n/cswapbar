import AppKit
import CSwapBarCore
import SwiftUI

/// The menu-bar popover.
struct PopoverView: View {
    @Bindable var model: AppModel

    var body: some View {
        PopoverContent(model: model)
            .themed(model.settings)
    }
}

private struct PopoverContent: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme
    @Environment(\.openAppSettings) private var openSettings
    @Environment(\.snapshotHeight) private var snapshotHeight

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(theme.border)
            if model.privacy.privacyModeEnabled {
                privacyBanner
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }
            content
            if snapshotHeight != nil { Spacer(minLength: 0) }
            Divider().overlay(theme.border)
            footer
        }
        // No fixed height: the popover grows to fit one page of accounts.
        // (Snapshots for the website use a fixed height so every image matches.)
        .frame(width: Theme.popoverWidth)
        .modifier(PopoverHeight(fixed: snapshotHeight))
        .background(theme.windowTint)
        .background(theme.windowBackground)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 10) {
            AppGlyph(size: 30)

            VStack(alignment: .leading, spacing: 1) {
                Text("CSwapBar")
                    .font(theme.type.appTitle)
                    .foregroundStyle(theme.text)
                headerSubtitle
            }

            Spacer()

            ToolbarIconButton(
                symbol: model.privacy.privacyModeEnabled ? "eye.slash.fill" : "eye",
                help: model.privacy.privacyModeEnabled ? "Turn off Privacy Mode (⇧⌘P)" : "Turn on Privacy Mode (⇧⌘P)",
                active: model.privacy.privacyModeEnabled
            ) { model.togglePrivacyMode() }
                .keyboardShortcut("p", modifiers: [.command, .shift])
                .accessibilityLabel("Privacy Mode")
                .accessibilityValue(model.privacy.privacyModeEnabled ? "On" : "Off")

            Group {
                if model.isRefreshing {
                    ProgressView().controlSize(.small).frame(width: 28, height: 28)
                } else {
                    ToolbarIconButton(symbol: "arrow.clockwise", help: "Refresh now (⌘R)") {
                        Task { await model.refresh() }
                    }
                    .keyboardShortcut("r")
                }
            }

            ToolbarIconButton(symbol: "gearshape", help: "Settings (⌘,)") {
                openSettings()
            }
            .keyboardShortcut(",")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    /// Account summary when connected; otherwise the connection problem.
    /// (CSwap's version lives in Settings → General.)
    @ViewBuilder
    private var headerSubtitle: some View {
        switch model.connection {
        case .connected where model.snapshot != nil:
            AccountSummaryPills(summary: AccountSummary(model.accounts))
        default:
            HStack(spacing: 5) {
                Circle().fill(connectionStatus.color).frame(width: 6, height: 6)
                Text(connectionStatus.text)
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.muted)
            }
        }
    }

    private var connectionStatus: (text: String, color: Color) {
        switch model.connection {
        case .connecting, .connected: ("Loading accounts…", theme.muted)
        case .notInstalled: ("CSwap not found", theme.critical)
        case .unsupported: ("CSwap needs an update", theme.warning)
        case .failed: ("Can't reach CSwap", theme.critical)
        }
    }

    /// Banner shown while Privacy Mode is on.
    private var privacyBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "eye.slash.fill")
                .font(theme.type.icon(14))
                .foregroundStyle(theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text("Privacy Mode Enabled")
                    .font(theme.type.font(13, .semibold))
                    .foregroundStyle(theme.text)
                Text("Account information is hidden.")
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.muted)
            }
            Spacer()
            Button("Turn Off") { model.togglePrivacyMode() }
                .buttonStyle(.quiet)
                .font(theme.type.font(12, .semibold))
                .foregroundStyle(theme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        switch model.connection {
        case .connecting:
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, minHeight: 160)
        case .notInstalled:
            MessageView(
                symbol: "shippingbox",
                title: "CSwap not found",
                message: "CSwapBar needs the CSwap CLI. Install it, add your accounts, then refresh.",
                command: "uv tool install claude-swap"
            )
        case .unsupported(let version):
            MessageView(
                symbol: "exclamationmark.arrow.triangle.2.circlepath",
                title: "CSwap \(version) is too old",
                message: "CSwapBar needs CSwap \(CSwapVersion.minimumSupported) or newer.",
                command: "cswap upgrade"
            )
        case .failed(let message):
            MessageView(symbol: "exclamationmark.triangle", title: "Couldn't reach CSwap", message: message, command: nil)
        case .connected:
            accountsContent
        }
    }

    @ViewBuilder
    private var accountsContent: some View {
        if model.snapshot == nil {
            if let error = model.lastRefreshError {
                MessageView(symbol: "exclamationmark.triangle", title: "Couldn't load accounts", message: error, command: nil)
            } else {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, minHeight: 160)
            }
        } else if model.accounts.isEmpty {
            MessageView(
                symbol: "person.crop.circle.badge.plus",
                title: "No accounts yet",
                message: "Log in to Claude Code, then add the account to CSwap.",
                command: "cswap add"
            )
        } else {
            PagedAccountList(model: model)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            freshnessLabel
            Spacer()
            Button("Quit") { NSApplication.shared.terminate(nil) }
                .buttonStyle(.quiet)
                .font(theme.type.font(11, .medium))
                .foregroundStyle(theme.muted)
                .keyboardShortcut("q")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var freshnessLabel: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let age = CountdownFormatter.age(since: model.lastSuccessfulRefresh, now: context.date)
            let (text, color, symbol): (String, Color, String) = switch model.freshness {
            case .updating: ("Updating…", theme.muted, "arrow.triangle.2.circlepath")
            case .fresh: ("Updated \(age ?? "")", theme.muted, "checkmark.circle")
            case .stale: (age.map { "Stale · \($0)" } ?? "Stale", theme.warning, "exclamationmark.circle")
            case .unavailable: ("Not updated yet", theme.muted, "circle.dashed")
            }
            Label(text, systemImage: symbol)
                .font(theme.type.footnote)
                .foregroundStyle(color)
                .help(model.lastRefreshError ?? "")
        }
    }
}

/// The app's mark: the full-color Triad on a dark tile, like the app icon.
struct AppGlyph: View {
    let size: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: size * 0.27, style: .continuous)
        shape
            .fill(RadialGradient(colors: [Color(hex: 0x2C2333), Color(hex: 0x0D0A11)],
                                 center: UnitPoint(x: 0.3, y: 0.2), startRadius: 0, endRadius: size))
            .overlay(TriadMark().frame(width: size * 0.84))
            .overlay(shape.strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

/// Empty / error / setup state with an optional copyable command.
struct MessageView: View {
    let symbol: String
    let title: String
    let message: String
    let command: String?

    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(theme.type.icon(30))
                .foregroundStyle(theme.accent)
            Text(title)
                .font(theme.type.title)
                .foregroundStyle(theme.text)
            Text(message)
                .font(theme.type.body)
                .foregroundStyle(theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if let command {
                HStack {
                    Text(command)
                        .font(.system(size: 13 * theme.type.scale, design: .monospaced))
                        .foregroundStyle(theme.text)
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(command, forType: .string)
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .buttonStyle(.quiet)
                    .foregroundStyle(theme.muted)
                    .help("Copy")
                }
                .card()
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity)
    }
}

/// "👥 4 accounts  ● 3 ready  ● 1 limited" as compact pills.
struct AccountSummaryPills: View {
    let summary: AccountSummary
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 5) {
            pill(summary.totalText, symbol: "person.2.fill", color: theme.muted, tinted: false)
            if summary.ready > 0 { pill("\(summary.ready) ready", color: theme.healthy) }
            if summary.limited > 0 { pill("\(summary.limited) limited", color: theme.critical) }
            if summary.needsAttention > 0 { pill("\(summary.needsAttention) needs login", color: theme.warning) }
        }
        .accessibilityElement(children: .combine)
    }

    private func pill(_ text: String, symbol: String? = nil, color: Color, tinted: Bool = true) -> some View {
        HStack(spacing: 4) {
            if let symbol {
                Image(systemName: symbol).font(theme.type.icon(8.5, .semibold))
            } else {
                Circle().frame(width: 5, height: 5)
            }
            Text(text).font(theme.type.font(10.5, .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(tinted ? 0.14 : 0.1), in: Capsule())
        .lineLimit(1)
        .fixedSize()
    }
}

/// Content-fitted height normally; a fixed height for uniform website snapshots.
private struct PopoverHeight: ViewModifier {
    let fixed: CGFloat?

    func body(content: Content) -> some View {
        if let fixed {
            content.frame(height: fixed, alignment: .top)
        } else {
            content.fixedSize(horizontal: false, vertical: true)
        }
    }
}
