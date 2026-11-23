import CSwapBarCore
import SwiftUI

/// One desktop widget, themed and privacy-aware. Hosted in a borderless panel
/// by `DesktopWidgetController`, and in Settings as a preview.
struct DesktopWidgetView: View {
    let kind: DesktopWidgetKind
    let model: AppModel

    var body: some View {
        DesktopWidgetContent(kind: kind, model: model)
            .themed(model.settings)
    }
}

private struct DesktopWidgetContent: View {
    let kind: DesktopWidgetKind
    let model: AppModel
    @Environment(\.theme) private var theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Group {
                switch kind {
                case .gauge: GaugeWidget(model: model, now: context.date)
                case .active: ActiveWidget(model: model, now: context.date)
                case .accounts: AccountsWidget(model: model)
                }
            }
            .padding(16)
            .frame(width: kind.size.width, alignment: .topLeading)
            .frame(minHeight: kind.size.height, alignment: .topLeading)
            .background(theme.windowTint)
            .background(theme.windowBackground, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(theme.border.opacity(0.6), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        }
    }
}

extension DesktopWidgetKind {
    /// Point size, roughly matching macOS widget proportions.
    var size: CGSize {
        switch self {
        case .gauge: CGSize(width: 164, height: 164)
        case .active: CGSize(width: 344, height: 164)
        case .accounts: CGSize(width: 344, height: 164)
        }
    }
}

// MARK: - Shared pieces

/// Big ring with a number in the middle (Battery-widget style).
private struct WidgetRing: View {
    let percent: Double?
    let thresholds: UsageThresholds
    let diameter: CGFloat
    let lineWidth: CGFloat
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Circle().stroke(theme.track, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: CGFloat((percent ?? 0) / 100))
                .stroke(theme.color(for: thresholds.level(for: percent)),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(percent.map { "\(Int($0.rounded()))" } ?? "—")
                    .font(theme.type.ringFigure(diameter * 0.3))
                    .foregroundStyle(theme.text)
                if percent != nil {
                    Text("%")
                        .font(theme.type.ringFigure(diameter * 0.14))
                        .foregroundStyle(theme.muted)
                }
            }
        }
        .frame(width: diameter, height: diameter)
    }
}

/// Small header: Orbit mark + label.
private struct WidgetHeader: View {
    let title: String
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            TriadMark().frame(width: 15, height: 15)
            Text(title.uppercased())
                .font(theme.type.label)
                .tracking(0.6)
                .foregroundStyle(theme.muted)
                .lineLimit(1)
        }
    }
}

private struct WidgetEmpty: View {
    let message: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(message)
            .font(theme.type.caption)
            .foregroundStyle(theme.muted)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .multilineTextAlignment(.center)
    }
}

// MARK: - Gauge (small)

private struct GaugeWidget: View {
    let model: AppModel
    let now: Date
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            WidgetHeader(title: "5-hour")
            if let account = model.activeAccount {
                let presentation = model.presentation(for: account)
                let window = account.usage?.fiveHour
                HStack {
                    Spacer()
                    WidgetRing(percent: presentation.showsUsage ? window?.percent : nil,
                               thresholds: model.thresholds, diameter: 78, lineWidth: 9)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(presentation.title)
                        .font(theme.type.font(12, .semibold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if presentation.showsResetTimes, let countdown = CountdownFormatter.string(until: window?.resetsAt, now: now) {
                        Text("Resets in \(countdown)")
                            .font(theme.type.footnote)
                            .foregroundStyle(theme.muted)
                    }
                }
            } else {
                WidgetEmpty(message: "No active account")
            }
        }
    }
}

// MARK: - Active (wide)

private struct ActiveWidget: View {
    let model: AppModel
    let now: Date
    @Environment(\.theme) private var theme

    var body: some View {
        if let account = model.activeAccount {
            let presentation = model.presentation(for: account)
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    WidgetHeader(title: "Active")
                    Spacer(minLength: 0)
                    Text(presentation.title)
                        .font(theme.type.font(17, .bold))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let subtitle = presentation.subtitle {
                        Text(subtitle)
                            .font(theme.type.footnote)
                            .foregroundStyle(theme.muted)
                            .lineLimit(1)
                    }
                    Label(AccountSummary(model.accounts).readyText, systemImage: "person.2.fill")
                        .font(theme.type.footnote)
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .layoutPriority(0)

                ringColumn("5H", account.usage?.fiveHour, presentation)
                ringColumn("7D", account.usage?.sevenDay, presentation)
            }
        } else {
            WidgetEmpty(message: "No active account")
        }
    }

    private func ringColumn(_ label: String, _ window: UsageWindow?, _ presentation: AccountPresentation) -> some View {
        VStack(spacing: 6) {
            WidgetRing(percent: presentation.showsUsage ? window?.percent : nil,
                       thresholds: model.thresholds, diameter: 64, lineWidth: 7.5)
            Text(label)
                .font(theme.type.label)
                .foregroundStyle(theme.muted)
            if presentation.showsResetTimes, let countdown = CountdownFormatter.string(until: window?.resetsAt, now: now) {
                Text(countdown)
                    .font(theme.type.footnote.monospacedDigit())
                    .foregroundStyle(theme.muted)
            }
        }
        .frame(width: 66)
        .fixedSize()
    }
}

// MARK: - Accounts (tall)

private struct AccountsWidget: View {
    let model: AppModel
    @Environment(\.theme) private var theme

    private let cellWidth: CGFloat = 80

    var body: some View {
        let accounts = AccountPaging.ordered(model.accounts)
        let shown = accounts.prefix(DesktopWidgetKind.maxRows)
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                WidgetHeader(title: "Accounts")
                Spacer(minLength: 4)
                Text(AccountSummary(accounts).readyText)
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.muted)
                    .lineLimit(1)
            }
            if accounts.isEmpty {
                WidgetEmpty(message: "No accounts yet")
            } else {
                // Column labels, once.
                HStack(spacing: 8) {
                    Spacer()
                    columnLabel("5-HOUR")
                    columnLabel("7-DAY")
                }
            }
            ForEach(Array(shown)) { account in
                let presentation = model.presentation(for: account)
                HStack(spacing: 8) {
                    Circle()
                        .fill(account.isActive ? theme.accent : theme.track)
                        .frame(width: 7, height: 7)
                    Text(presentation.title)
                        .font(theme.type.font(12.5, account.isActive ? .semibold : .regular))
                        .foregroundStyle(theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if presentation.showsUsage, let usage = account.usage {
                        cell(usage.fiveHour?.percent)
                        cell(usage.sevenDay?.percent)
                    } else {
                        Text("—").font(theme.type.caption).foregroundStyle(theme.muted)
                            .frame(width: cellWidth * 2 + 8, alignment: .trailing)
                    }
                }
            }
            if accounts.count > shown.count {
                Text("+\(accounts.count - shown.count) more")
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.muted)
            }
        }
    }

    private func columnLabel(_ text: String) -> some View {
        Text(text)
            .font(theme.type.label)
            .tracking(0.5)
            .foregroundStyle(theme.muted)
            .frame(width: cellWidth, alignment: .trailing)
    }

    /// ▬▬▬ 42%
    private func cell(_ percent: Double?) -> some View {
        HStack(spacing: 6) {
            UsageTrack(percent: percent, color: theme.color(for: model.thresholds.level(for: percent)), height: 5)
            Text(percent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(theme.type.font(11.5, .semibold).monospacedDigit())
                .foregroundStyle(percent == nil ? theme.muted : theme.text)
                .lineLimit(1)
                .fixedSize()
                .frame(width: 38, alignment: .trailing)
        }
        .frame(width: cellWidth)
    }
}
