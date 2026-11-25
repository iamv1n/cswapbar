import CSwapBarCore
import SwiftUI

/// One usage window as a meter: label, big percentage, bar, reset time.
/// Two of these sit side by side on each account card.
struct UsageMeter: View {
    let label: String
    let window: UsageWindow?
    let thresholds: UsageThresholds
    let showsResetTime: Bool
    let now: Date

    @Environment(\.theme) private var theme

    private var percent: Double? { window?.percent }
    private var level: UsageLevel { thresholds.level(for: percent) }
    private var countdown: String? {
        showsResetTime ? CountdownFormatter.string(until: window?.resetsAt, now: now) : nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: theme.compact ? 3 : 4) {
            HStack(spacing: 4) {
                Text(label.uppercased())
                    .font(theme.type.label)
                    .tracking(0.6)
                    .foregroundStyle(theme.muted)
                if level == .critical {
                    Image(systemName: "exclamationmark.circle.fill")
                        .font(theme.type.icon(10))
                        .foregroundStyle(theme.critical)
                }
                Spacer(minLength: 4)
                if let countdown {
                    Label(countdown, systemImage: "clock")
                        .labelStyle(.titleAndIcon)
                        .font(theme.type.footnote)
                        .foregroundStyle(theme.muted)
                        .lineLimit(1)
                        .help("Resets in \(countdown)")
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(percent.map { "\(Int($0.rounded()))" } ?? "—")
                    .font(theme.compact ? theme.type.metricCompact : theme.type.metric)
                    .foregroundStyle(percent == nil ? theme.muted : theme.text)
                if percent != nil {
                    Text("%")
                        .font(theme.type.metricUnit)
                        .foregroundStyle(theme.muted)
                }
            }

            UsageTrack(percent: percent, color: theme.color(for: level), height: theme.barHeight(6))
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = ["\(label) usage", percent.map { "\(Int($0.rounded())) percent" } ?? "unknown"]
        if let countdown { parts.append("resets in \(countdown)") }
        return parts.joined(separator: ", ")
    }
}

/// Shown instead of meters when "Hide usage percentages" is on.
struct UsageHiddenRow: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Label("Usage hidden", systemImage: "eye.slash")
            .font(theme.type.caption)
            .foregroundStyle(theme.muted)
    }
}

/// Classic layout: label · bar · percentage on one line, reset time beside the label.
struct ClassicUsageRow: View {
    let label: String
    let window: UsageWindow?
    let thresholds: UsageThresholds
    let showsResetTime: Bool
    let now: Date

    @Environment(\.theme) private var theme

    var body: some View {
        let percent = window?.percent
        let countdown = showsResetTime ? CountdownFormatter.string(until: window?.resetsAt, now: now) : nil
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(label)
                    .font(theme.type.font(12, .medium))
                    .foregroundStyle(theme.muted)
                Spacer(minLength: 4)
                if let countdown {
                    Text("resets in \(countdown)")
                        .font(theme.type.footnote)
                        .foregroundStyle(theme.muted)
                }
                Text(percent.map { "\(Int($0.rounded()))%" } ?? "—")
                    .font(theme.type.metricSmall)
                    .foregroundStyle(percent == nil ? theme.muted : theme.text)
                    .frame(minWidth: 40, alignment: .trailing)
            }
            UsageTrack(percent: percent, color: theme.color(for: thresholds.level(for: percent)), height: theme.barHeight(6))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) usage, \(percent.map { "\(Int($0.rounded())) percent" } ?? "unknown")")
    }
}

/// Rings layout: a circular gauge with the percentage inside, label and reset beside it.
struct RingMeter: View {
    let label: String
    let window: UsageWindow?
    let thresholds: UsageThresholds
    let showsResetTime: Bool
    let now: Date

    @Environment(\.theme) private var theme

    var body: some View {
        let percent = window?.percent
        let countdown = showsResetTime ? CountdownFormatter.string(until: window?.resetsAt, now: now) : nil
        let size: CGFloat = (theme.compact ? 44 : 54) * theme.type.scale
        HStack(spacing: 10) {
            ZStack {
                Circle().stroke(theme.track, lineWidth: theme.ringWidth(6))
                Circle()
                    .trim(from: 0, to: CGFloat((percent ?? 0) / 100))
                    .stroke(theme.color(for: thresholds.level(for: percent)), style: StrokeStyle(lineWidth: theme.ringWidth(6), lineCap: theme.squareEnds ? .butt : .round))
                    .rotationEffect(.degrees(-90))
                Text(percent.map { "\(Int($0.rounded()))" } ?? "—")
                    .font(theme.type.ringFigure(theme.compact ? 13 : 15))
                    .foregroundStyle(percent == nil ? theme.muted : theme.text)
            }
            .frame(width: size, height: size)

            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(theme.type.label)
                    .tracking(0.6)
                    .foregroundStyle(theme.muted)
                Text(percent.map { "\(Int($0.rounded()))% used" } ?? "No data")
                    .font(theme.type.font(12, .medium))
                    .foregroundStyle(theme.text)
                if let countdown {
                    Text("Resets in \(countdown)")
                        .font(theme.type.footnote)
                        .foregroundStyle(theme.muted)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) usage, \(percent.map { "\(Int($0.rounded())) percent" } ?? "unknown")")
    }
}

/// List layout: "5H ▬▬▬ 42%" in a fixed width.
struct MiniUsage: View {
    let label: String
    let percent: Double?
    let thresholds: UsageThresholds

    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(theme.type.label)
                .foregroundStyle(theme.muted)
                .frame(width: 18, alignment: .leading)
            UsageTrack(percent: percent, color: theme.color(for: thresholds.level(for: percent)), height: theme.barHeight(5))
                .frame(width: 46)
            Text(percent.map { "\(Int($0.rounded()))%" } ?? "—")
                .font(theme.type.font(11.5, .semibold).monospacedDigit())
                .foregroundStyle(percent == nil ? theme.muted : theme.text)
                .frame(width: 36, alignment: .trailing)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) usage, \(percent.map { "\(Int($0.rounded())) percent" } ?? "unknown")")
    }
}

/// Rounded progress track shared by every layout.
struct UsageTrack: View {
    let percent: Double?
    let color: Color
    let height: CGFloat

    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                trackShape.fill(theme.track)
                trackShape
                    .fill(color)
                    .frame(width: max(proxy.size.width * CGFloat((percent ?? 0) / 100), (percent ?? 0) > 0 ? height : 0))
            }
        }
        .frame(height: height)
    }

    /// Capsules normally; square-ended bars with the Boxy corner style.
    private var trackShape: AnyShape {
        theme.squareEnds ? AnyShape(RoundedRectangle(cornerRadius: 1, style: .continuous)) : AnyShape(Capsule())
    }
}
