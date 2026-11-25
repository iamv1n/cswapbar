import CSwapBarCore
import SwiftUI

/// Settings → Layout → Usage Colors: where bars and rings turn yellow, orange and red.
struct UsageColorsSection: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme

    private var t: UsageThresholds { model.settings.usageThresholds }

    var body: some View {
        SettingsGroup("Usage Colors", footer: "Applies to bars, rings and widgets. Notification levels are set separately in Notifications.") {
            BandStrip(thresholds: t)
                .frame(height: 30)
                .padding(.horizontal, 14)
                .padding(.top, 14)
                .padding(.bottom, 6)
            row("Yellow from", color: theme.warning, value: t.warning, range: 1...98) { new in
                UsageThresholds(warning: new, high: max(t.high, new + 1), critical: max(t.critical, new + 2))
            }
            RowDivider()
            row("Orange from", color: theme.high, value: t.high, range: 2...99) { new in
                UsageThresholds(warning: min(t.warning, new - 1), high: new, critical: max(t.critical, new + 1))
            }
            RowDivider()
            row("Red from", color: theme.critical, value: t.critical, range: 3...100) { new in
                UsageThresholds(warning: min(t.warning, new - 2), high: min(t.high, new - 1), critical: new)
            }
            if t != .default {
                RowDivider()
                SettingsRow("Reset to 60 · 80 · 95", symbol: "arrow.uturn.backward") {
                    Button("Reset") { model.settings.usageThresholds = .default }
                        .buttonStyle(AccentButtonStyle())
                }
            }
        }
    }

    /// Changing one band nudges its neighbours so the order always stays yellow < orange < red.
    private func row(
        _ title: String, color: Color, value: Double, range: ClosedRange<Double>,
        update: @escaping (Double) -> UsageThresholds
    ) -> some View {
        SettingsRow(title, symbol: "circle.fill", symbolColor: color) {
            PercentStepper(value: value, range: range) { new in
                model.settings.usageThresholds = update(new).normalized
            }
        }
    }
}

/// −  80%  +   (steps of 5, snapping to multiples of 5; Option-click steps by 1)
struct PercentStepper: View {
    let value: Double
    let range: ClosedRange<Double>
    let onChange: (Double) -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 2) {
            button("minus", label: "Lower") { step(-1) }
            Text("\(Int(value))%")
                .font(theme.type.font(13, .semibold).monospacedDigit())
                .foregroundStyle(theme.text)
                .frame(minWidth: 46)
            button("plus", label: "Higher") { step(1) }
        }
        .padding(2)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int(value)) percent")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: step(1)
            case .decrement: step(-1)
            @unknown default: break
            }
        }
    }

    private func button(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(theme.type.icon(11, .bold))
                .foregroundStyle(theme.muted)
                .frame(width: 26, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.quiet)
        .accessibilityLabel(label)
    }

    private func step(_ direction: Double) {
        let fine = NSEvent.modifierFlags.contains(.option)
        let size: Double = fine ? 1 : 5
        // Snap to the grid first, so 83 → 85 → 90.
        let snapped = direction > 0 ? (value / size).rounded(.down) * size + size
                                    : (value / size).rounded(.up) * size - size
        onChange(min(max(snapped, range.lowerBound), range.upperBound))
    }
}

/// A 0–100% strip painted in the four bands, labelled at each threshold.
private struct BandStrip: View {
    let thresholds: UsageThresholds
    @Environment(\.theme) private var theme

    /// Thresholds to label, skipping any too close to the previous one to fit.
    private var labelledMarks: [Double] {
        var marks: [Double] = []
        for mark in [thresholds.warning, thresholds.high, thresholds.critical] where mark - (marks.last ?? -100) >= 6 {
            marks.append(mark)
        }
        return marks
    }

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let bands: [(Double, Double, Color)] = [
                (0, thresholds.warning, theme.healthy),
                (thresholds.warning, thresholds.high, theme.warning),
                (thresholds.high, thresholds.critical, theme.high),
                (thresholds.critical, 100, theme.critical),
            ]
            VStack(spacing: 4) {
                HStack(spacing: 0) {
                    ForEach(Array(bands.enumerated()), id: \.offset) { _, band in
                        Rectangle()
                            .fill(band.2)
                            .frame(width: max(w * (band.1 - band.0) / 100, 0))
                    }
                }
                .frame(height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
                ZStack(alignment: .topLeading) {
                    ForEach(labelledMarks, id: \.self) { mark in
                        Text("\(Int(mark))")
                            .font(theme.type.font(10, .medium).monospacedDigit())
                            .foregroundStyle(theme.muted)
                            .fixedSize()
                            .position(x: min(max(w * mark / 100, 8), w - 10), y: 7)
                    }
                }
                .frame(height: 14)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Green below \(Int(thresholds.warning))%, yellow from \(Int(thresholds.warning))%, orange from \(Int(thresholds.high))%, red from \(Int(thresholds.critical))%")
    }
}
