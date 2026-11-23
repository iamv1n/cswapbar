import CSwapBarCore
import SwiftUI

/// One account, drawn in the user's chosen card layout. Renders identity only
/// through `AccountPresentation`, so privacy applies with no masking logic here.
struct AccountCard: View {
    let account: Account
    let presentation: AccountPresentation
    let thresholds: UsageThresholds
    let switchState: AppModel.SwitchState
    let switchingDisabled: Bool
    let now: Date
    let onSwitch: () -> Void

    @Environment(\.theme) private var theme
    @State private var hovered = false

    var body: some View {
        Group {
            if theme.layout == .list {
                listRow
            } else {
                VStack(alignment: .leading, spacing: theme.compact ? 9 : 12) {
                    header
                    usageSection
                    failureMessage
                }
                .card(highlighted: account.isActive, hovered: hovered)
            }
        }
        .onHover { hovered = $0 }
        .animation(.easeOut(duration: 0.12), value: hovered)
    }

    // MARK: Header (meters / classic / rings)

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            avatar(size: theme.compact ? 30 : 36)
            titleBlock(showSubtitle: true)
            Spacer(minLength: 8)
            trailingControl
        }
    }

    private func titleBlock(showSubtitle: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(presentation.title)
                    .font(theme.type.title)
                    .foregroundStyle(theme.text)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if account.isDisabled { Badge(text: "Paused", color: theme.muted) }
            }
            if showSubtitle, let subtitle = presentation.subtitle {
                Text(subtitle)
                    .font(theme.type.caption)
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(presentation.accessibilityLabel)
    }

    private func avatar(size: CGFloat) -> some View {
        let tint = account.isActive ? theme.accent : theme.muted
        return ZStack {
            Circle().fill(tint.opacity(account.isActive ? 0.18 : 0.12))
            Image(systemName: presentation.showsOrganizationIcon ? "building.2.fill" : "person.fill")
                .font(theme.type.icon(size * 0.42, .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var trailingControl: some View {
        if account.isActive {
            Badge(text: "Active", color: theme.accent)
        } else {
            switch switchState {
            case .switching(let id) where id == account.id:
                ProgressView().controlSize(.small)
            case .succeeded(let id) where id == account.id:
                Image(systemName: "checkmark.circle.fill")
                    .font(theme.type.icon(18))
                    .foregroundStyle(theme.healthy)
            default:
                Button("Switch", action: onSwitch)
                    .buttonStyle(AccentButtonStyle())
                    .disabled(switchingDisabled)
                    .accessibilityLabel("Switch to \(presentation.title)")
            }
        }
    }

    @ViewBuilder
    private var failureMessage: some View {
        if case .failed(let id, let message) = switchState, id == account.id {
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(theme.type.caption)
                .foregroundStyle(theme.critical)
        }
    }

    // MARK: Usage (meters / classic / rings)

    @ViewBuilder
    private var usageSection: some View {
        if let usage = account.usage {
            if presentation.showsUsage {
                windows(usage)
            } else {
                UsageHiddenRow()
            }
            if usage.isLastKnown {
                Label(lastKnownText(usage), systemImage: "clock.arrow.circlepath")
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.warning)
            }
        } else {
            Label(statusText, systemImage: "info.circle")
                .font(theme.type.caption)
                .foregroundStyle(theme.muted)
        }
    }

    @ViewBuilder
    private func windows(_ usage: Usage) -> some View {
        let resets = presentation.showsResetTimes
        switch theme.layout {
        case .meters, .list:
            HStack(alignment: .top, spacing: theme.compact ? 14 : 18) {
                UsageMeter(label: "5-hour", window: usage.fiveHour, thresholds: thresholds, showsResetTime: resets, now: now)
                UsageMeter(label: "7-day", window: usage.sevenDay, thresholds: thresholds, showsResetTime: resets, now: now)
            }
        case .classic:
            VStack(spacing: theme.compact ? 8 : 10) {
                ClassicUsageRow(label: "5-hour", window: usage.fiveHour, thresholds: thresholds, showsResetTime: resets, now: now)
                ClassicUsageRow(label: "7-day", window: usage.sevenDay, thresholds: thresholds, showsResetTime: resets, now: now)
            }
        case .rings:
            HStack(spacing: 12) {
                RingMeter(label: "5-hour", window: usage.fiveHour, thresholds: thresholds, showsResetTime: resets, now: now)
                RingMeter(label: "7-day", window: usage.sevenDay, thresholds: thresholds, showsResetTime: resets, now: now)
            }
        }
    }

    // MARK: List layout

    private var listRow: some View {
        HStack(spacing: 10) {
            avatar(size: 28)
            titleBlock(showSubtitle: false)
            Spacer(minLength: 6)
            if let usage = account.usage, presentation.showsUsage {
                VStack(alignment: .trailing, spacing: 4) {
                    MiniUsage(label: "5H", percent: usage.fiveHour?.percent, thresholds: thresholds)
                    MiniUsage(label: "7D", percent: usage.sevenDay?.percent, thresholds: thresholds)
                }
                .opacity(usage.isLastKnown ? 0.6 : 1)
                .help(usage.isLastKnown ? lastKnownText(usage) : "")
            } else if account.usage == nil {
                Image(systemName: "info.circle")
                    .foregroundStyle(theme.muted)
                    .help(statusText)
            }
            trailingControl
                .frame(minWidth: 62, alignment: .trailing)
        }
        .card(highlighted: account.isActive, hovered: hovered, padding: theme.compact ? 8 : 10)
    }

    // MARK: Text

    private var statusText: String {
        switch account.usageStatus {
        case .ok: "Usage not reported yet."
        case .apiKey: "API key — no subscription quota."
        case .tokenExpired: "Token refresh pending. Usage will return shortly."
        case .reloginRequired: "Login expired. Log in again and run `cswap add`."
        case .keychainUnavailable: "Keychain unavailable."
        case .foreignCredential: "Credential mismatch. Switching will repair it."
        case .noCredentials: "No credentials stored."
        case .unavailable: account.usageError.map { "Usage unavailable (\($0))." } ?? "Usage unavailable."
        case .unrecognized(let raw): "Status: \(raw)"
        }
    }

    private func lastKnownText(_ usage: Usage) -> String {
        if let age = CountdownFormatter.age(since: usage.fetchedAt, now: now) {
            return "Last known usage, \(age)"
        }
        return "Last known usage"
    }
}
