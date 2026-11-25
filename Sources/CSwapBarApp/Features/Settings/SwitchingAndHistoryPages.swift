import AppKit
import CSwapBarCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Switching

/// Settings → Switching: the "best next account" hint and CSwap's auto-switch.
struct SwitchingPage: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme

    private var auto: AutoSwitchPreferences { model.settings.autoSwitch }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsPageHeader(title: "Switching", subtitle: "Suggestions, and letting CSwap switch for you.")

            SettingsGroup("Suggestion", footer: "Appears in the popover once your active account passes the yellow level. It uses CSwap's \"best\" rule: the account with the most quota left in its tighter window.") {
                SettingsRow("Suggest the best next account", symbol: "sparkles") {
                    Toggle("Suggest the best next account", isOn: $model.settings.showRecommendation)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
            }

            SettingsGroup("Auto-switch", footer: "CSwap does the switching (cswap auto). CSwapBar starts it, shows what it decides, and stops it when CSwapBar quits. Off by default.") {
                SettingsRow("Switch automatically", subtitle: statusText, symbol: "arrow.triangle.2.circlepath") {
                    Toggle("Switch automatically", isOn: $model.settings.autoSwitch.enabled)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
                RowDivider()
                SettingsRow("Switch when 5-hour usage reaches", symbol: "gauge.with.dots.needle.67percent") {
                    PercentStepper(value: auto.threshold, range: 50...99) { model.settings.autoSwitch.threshold = $0 }
                }
                .opacity(auto.enabled ? 1 : 0.5)
                RowDivider()
                VStack(alignment: .leading, spacing: 4) {
                    Text("Switch to")
                        .font(theme.type.body)
                        .foregroundStyle(theme.text)
                        .padding(.bottom, 4)
                    ForEach(AutoSwitchPreferences.Strategy.allCases, id: \.self) { strategy in
                        StrategyRow(strategy: strategy, isSelected: auto.strategy == strategy) {
                            model.settings.autoSwitch.strategy = strategy
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .opacity(auto.enabled ? 1 : 0.5)
            }

            if auto.enabled, model.cswapMenubar?.isPresent == true {
                Label("CSwap's own menu bar app is also installed. If its auto-switch is on too, turn one of them off so they don't both switch.",
                      systemImage: "exclamationmark.triangle")
                    .font(theme.type.caption)
                    .foregroundStyle(theme.warning)
            }
        }
    }

    private var statusText: String {
        guard auto.enabled else { return "Off. Accounts change only when you switch." }
        guard let runner = model.autoSwitcher else { return "Runs in the app." }
        switch runner.state {
        case .off: return "Starting…"
        case .problem(let message): return message
        case .running:
            let when = runner.lastDecisionDate.flatMap { CountdownFormatter.age(since: $0) }.map { " · \($0)" } ?? ""
            return (runner.lastDecision ?? "Running.") + when
        }
    }
}

private struct StrategyRow: View {
    let strategy: AutoSwitchPreferences.Strategy
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .font(theme.type.icon(13))
                    .foregroundStyle(isSelected ? theme.accent : theme.muted)
                Text(strategy.title)
                    .font(theme.type.caption)
                    .foregroundStyle(theme.text)
                Text(strategy.rawValue)
                    .font(theme.type.font(11, .medium).monospaced())
                    .foregroundStyle(theme.muted)
                Spacer()
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.quiet)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - History

/// Settings → History: local usage history for the dashboard.
struct HistoryPage: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme
    @Environment(\.openDashboard) private var openDashboard
    @State private var confirmClear = false
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsPageHeader(title: "History", subtitle: "Usage over time, for the dashboard. Stays on this Mac.")

            SettingsGroup(footer: "Kept for 30 days, then deleted automatically. Accounts are stored as anonymous keys (salted hashes), never emails or names.") {
                SettingsRow("Keep usage history", subtitle: countsText, symbol: "clock.arrow.circlepath") {
                    Toggle("Keep usage history", isOn: $model.settings.historyEnabled)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
                RowDivider()
                SettingsRow("Dashboard", subtitle: "Charts per account and every switch. ⌘Y in the popover.", symbol: "chart.xyaxis.line") {
                    Button("Open") { openDashboard() }
                        .buttonStyle(AccentButtonStyle())
                }
                RowDivider()
                SettingsRow("Export as CSV", subtitle: "Names follow your privacy settings at export time.", symbol: "square.and.arrow.up") {
                    Button("Export…") { message = HistoryExport.run(model: model) }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(model.history == nil)
                }
                RowDivider()
                SettingsRow("Clear history", subtitle: "Deletes every reading and switch record.", symbol: "trash") {
                    Button("Clear…") { confirmClear = true }
                        .buttonStyle(.quiet)
                        .font(theme.type.font(12, .semibold))
                        .foregroundStyle(theme.critical)
                        .disabled(model.history == nil)
                }
            }
            .confirmationDialog("Delete all usage history?", isPresented: $confirmClear) {
                Button("Delete History", role: .destructive) {
                    model.clearHistory()
                    message = "History cleared."
                }
            } message: {
                Text("This can't be undone.")
            }

            if let message {
                Label(message, systemImage: "info.circle")
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.muted)
            }
        }
    }

    private var countsText: String {
        _ = model.historyRevision
        guard let counts = try? model.history?.counts() else { return "Not available." }
        return "\(counts.samples) readings and \(counts.switches) switches stored."
    }
}

/// Shared by Settings → History and the dashboard.
@MainActor
enum HistoryExport {
    /// Asks where to save, writes the CSV, and returns a status message.
    static func run(model: AppModel) -> String? {
        guard let csv = model.historyCSV() else { return "Nothing to export yet." }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.commaSeparatedText]
        panel.nameFieldStringValue = "CSwapBar history \(Date().formatted(.iso8601.year().month().day())).csv"
        panel.message = "Exports the last 30 days. Account names follow your privacy settings."
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return "Exported to \(url.lastPathComponent)."
        } catch {
            return "Couldn't export: \(error.localizedDescription)"
        }
    }
}
