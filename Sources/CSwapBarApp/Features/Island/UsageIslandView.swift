import CSwapBarCore
import SwiftUI

/// Shared between the island's window and its SwiftUI content.
@MainActor
@Observable
final class UsageIslandState {
    var expanded = false
}

/// The Usage Island's content. Always black, so it reads as part of the notch;
/// usage colors come from the user's theme (a dark variant on light themes).
struct UsageIslandView: View {
    @Bindable var model: AppModel
    let state: UsageIslandState
    let geometry: IslandGeometry
    var onOpen: () -> Void = {}

    var body: some View {
        IslandBody(model: model, state: state, geometry: geometry, onOpen: onOpen)
            .environment(\.theme, Self.theme(for: model.settings))
            .environment(\.colorScheme, .dark)
    }

    /// The island is black, so it always uses a dark palette.
    static func theme(for settings: AppSettings) -> Theme {
        let palette = settings.activePalette(systemIsDark: true)
        return Theme(palette: palette.isDark && palette.style != .native ? palette : .atelierDark,
                     accent: settings.accent, font: settings.font, size: .standard,
                     compact: false, layout: settings.cardLayout, design: settings.design)
    }
}

private struct IslandBody: View {
    @Bindable var model: AppModel
    let state: UsageIslandState
    let geometry: IslandGeometry
    let onOpen: () -> Void
    @Environment(\.theme) private var theme

    private var expanded: Bool { state.expanded }
    private var size: CGSize { expanded ? geometry.expanded.size : geometry.collapsed.size }
    private var notchWidth: CGFloat { geometry.collapsed.width - 2 * IslandGeometry.wing }

    var body: some View {
        ZStack(alignment: .top) {
            shape
                .fill(Color.black)
                .overlay(shape.stroke(Color.white.opacity(geometry.hugsNotch ? 0 : 0.08), lineWidth: 1))
                .shadow(color: .black.opacity(expanded || !geometry.hugsNotch ? 0.35 : 0), radius: 14, y: 6)
            VStack(spacing: 0) {
                collapsedRow
                    .frame(height: geometry.collapsed.height)
                if expanded {
                    expandedContent
                        .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .top)))
                }
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.34, dampingFraction: 0.82), value: expanded)
        .contentShape(shape)
        .onTapGesture { if !expanded { onOpen() } }
    }

    /// Flat on top (flush with the screen edge or menu bar), rounded below.
    private var shape: some Shape {
        let bottom: CGFloat = expanded ? 26 : (geometry.hugsNotch ? 12 : geometry.collapsed.height / 2)
        let top: CGFloat = geometry.hugsNotch ? 0 : (expanded ? 22 : geometry.collapsed.height / 2)
        return UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom,
                                      bottomTrailingRadius: bottom, topTrailingRadius: top, style: .continuous)
    }

    // MARK: Collapsed

    private var active: Account? { model.activeAccount }
    private var hideUsage: Bool { model.privacy.shouldMask(.usage) }

    private var collapsedRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 7) {
                MiniRing(percent: active?.usage?.fiveHour?.percent, color: color(for: active?.usage?.fiveHour?.percent))
                    .frame(width: 16, height: 16)
                Text("5h")
                    .font(theme.type.font(11, .semibold))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer(minLength: geometry.hugsNotch ? notchWidth : 8)
            if let problem = connectionProblem {
                Text(problem)
                    .font(theme.type.font(11, .semibold))
                    .foregroundStyle(theme.warning)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
            HStack(spacing: 4) {
                if model.privacy.privacyModeEnabled {
                    Image(systemName: "eye.slash.fill")
                        .font(theme.type.icon(9, .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Text(percentText(active?.usage?.fiveHour?.percent))
                    .font(theme.type.font(12.5, .bold).monospacedDigit())
                    .foregroundStyle(color(for: active?.usage?.fiveHour?.percent))
            }
            }
        }
        .padding(.horizontal, geometry.hugsNotch ? 16 : 14)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Claude usage")
        .accessibilityValue(hideUsage ? "Hidden" : "5-hour \(percentText(active?.usage?.fiveHour?.percent))")
    }

    // MARK: Expanded

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let active {
                let presentation = model.presentation(for: active)
                HStack(spacing: 8) {
                    Text(presentation.title)
                        .font(theme.type.font(14, .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let detail = presentation.subtitle {
                        Text(detail)
                            .font(theme.type.font(11, .medium))
                            .foregroundStyle(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    Spacer()
                    Text("ACTIVE")
                        .font(theme.type.font(9.5, .bold))
                        .tracking(0.8)
                        .foregroundStyle(theme.accent)
                }
                HStack(spacing: 14) {
                    window("5-hour", active.usage?.fiveHour)
                    window("Weekly", active.usage?.sevenDay)
                }
            } else {
                Text(connectionProblem.map { "\($0). Open CSwapBar for details." } ?? "No active Claude account")
                    .font(theme.type.font(13, .medium))
                    .foregroundStyle(.white.opacity(0.7))
            }

            if let recommendation = model.recommendation {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(theme.type.icon(11, .semibold))
                        .foregroundStyle(theme.accent)
                    Text(recommendation.explanation(preferences: model.privacy))
                        .font(theme.type.font(11.5, .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    Button("Switch") { Task { await model.switchTo(recommendation.account) } }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(model.isSwitching)
                }
            }

            others

            HStack {
                Text(model.isSwitching ? "Switching…" : "")
                    .font(theme.type.font(11, .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Spacer()
                Button(action: onOpen) {
                    Label("Open CSwapBar", systemImage: "arrow.up.forward.app")
                        .font(theme.type.font(11, .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .buttonStyle(.quiet)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    private var others: some View {
        let rest = AccountPaging.ordered(model.accounts).filter { !$0.isActive }.prefix(3)
        return VStack(spacing: 5) {
            ForEach(Array(rest)) { account in
                HStack(spacing: 8) {
                    Text(model.presentation(for: account).title)
                        .font(theme.type.font(11.5, .medium))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                    Spacer(minLength: 6)
                    mini("5h", account.usage?.fiveHour?.percent)
                    mini("7d", account.usage?.sevenDay?.percent)
                }
            }
        }
    }

    private func mini(_ label: String, _ percent: Double?) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(theme.type.font(9.5, .semibold))
                .foregroundStyle(.white.opacity(0.4))
            Text(percentText(percent))
                .font(theme.type.font(11, .semibold).monospacedDigit())
                .foregroundStyle(color(for: percent))
                .frame(width: 36, alignment: .trailing)
        }
    }

    private func window(_ title: String, _ window: UsageWindow?) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title.uppercased())
                    .font(theme.type.font(9.5, .bold))
                    .tracking(0.6)
                    .foregroundStyle(.white.opacity(0.45))
                Spacer()
                if !model.privacy.shouldMask(.resetTimestamps),
                   let countdown = CountdownFormatter.string(until: window?.resetsAt) {
                    Text(countdown)
                        .font(theme.type.font(10, .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                }
            }
            Text(percentText(window?.percent))
                .font(theme.type.font(20, .bold).monospacedDigit())
                .foregroundStyle(.white)
            UsageTrack(percent: hideUsage ? nil : window?.percent, color: color(for: window?.percent), height: theme.barHeight(5))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Helpers

    /// Short status for the collapsed island when there's nothing to measure.
    private var connectionProblem: String? {
        switch model.connection {
        case .connected: model.snapshot == nil ? "Loading…" : nil
        case .connecting: "Loading…"
        case .notInstalled: "CSwap not found"
        case .unsupported: "Update CSwap"
        case .failed: "Can't reach CSwap"
        }
    }

    private func percentText(_ percent: Double?) -> String {
        guard !hideUsage else { return "••" }
        return percent.map { "\(Int($0.rounded()))%" } ?? "–"
    }

    private func color(for percent: Double?) -> Color {
        hideUsage ? .white.opacity(0.6) : theme.color(for: model.thresholds.level(for: percent))
    }
}

/// A tiny progress ring for the collapsed island.
private struct MiniRing: View {
    let percent: Double?
    let color: Color

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.18), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: CGFloat(min(max((percent ?? 0) / 100, 0), 1)))
                .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
