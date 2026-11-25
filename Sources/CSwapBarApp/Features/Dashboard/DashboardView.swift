import AppKit
import Charts
import CSwapBarCore
import SwiftUI
import UniformTypeIdentifiers

/// Usage over time per account, plus switch history, from the local history database.
struct DashboardView: View {
    @Bindable var model: AppModel

    var body: some View {
        DashboardContent(model: model)
            .themed(model.settings)
    }
}

private struct DashboardContent: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme
    @Environment(\.isSnapshot) private var isSnapshot

    enum Range: String, CaseIterable {
        case day, week, month
        var title: String { switch self { case .day: "24 hours"; case .week: "7 days"; case .month: "30 days" } }
        var seconds: TimeInterval { switch self { case .day: 86_400; case .week: 7 * 86_400; case .month: 30 * 86_400 } }
    }

    enum Window: String, CaseIterable {
        case fiveHour, sevenDay
        var title: String { self == .fiveHour ? "5-hour" : "Weekly" }
    }

    @State private var range: Range = .week
    @State private var window: Window = .fiveHour
    @State private var loadedSamples: [UsageSample] = []
    /// Real history, or made-up sample data in screenshots (no database there).
    private var samples: [UsageSample] {
        model.history == nil ? SampleData.historySamples(model: model, range: range.seconds) : loadedSamples
    }
    @State private var switches: [SwitchRecord] = []
    @State private var message: String?

    var body: some View {
        let content = VStack(alignment: .leading, spacing: 20) {
            header
            stats
            chartCard
            switchesCard
            if let message {
                Label(message, systemImage: "info.circle")
                    .font(theme.type.footnote)
                    .foregroundStyle(theme.muted)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .topLeading)

        Group {
            if isSnapshot { content } else { ScrollView { content } }
        }
        .frame(minWidth: 720, minHeight: 560)
        .background(AmbientBackground())
        .task(id: "\(range.rawValue)-\(model.historyRevision)") { load() }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Usage History")
                    .font(theme.type.font(26, .bold))
                    .foregroundStyle(theme.text)
                Text(model.settings.historyEnabled
                     ? "Kept on this Mac for 30 days. Accounts are stored as anonymous keys, never emails."
                     : "History is off. Turn it on in Settings → History.")
                    .font(theme.type.caption)
                    .foregroundStyle(theme.muted)
            }
            Spacer()
            ThemedSegmented(selection: $range, options: Range.allCases.map { ($0, $0.title) })
            Button("Export CSV…", action: export)
                .buttonStyle(AccentButtonStyle())
                .disabled(samples.isEmpty && switches.isEmpty)
        }
    }

    // MARK: Stats

    private var stats: some View {
        HStack(spacing: 12) {
            statTile("Switches", "\(switches.count)", detail: switchBreakdown)
            statTile("Busiest account", busiest?.name ?? "–", detail: busiest.map { "Peak \(Int($0.peak))% \(window.title.lowercased())" })
            statTile("Readings", "\(samples.count)", detail: "Every 5 minutes per account")
        }
    }

    private func statTile(_ title: String, _ value: String, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(theme.type.label)
                .tracking(0.8)
                .foregroundStyle(theme.muted)
            Text(value)
                .font(theme.type.font(22, .bold).monospacedDigit())
                .foregroundStyle(theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(detail ?? " ")
                .font(theme.type.footnote)
                .foregroundStyle(theme.muted)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var switchBreakdown: String? {
        guard !switches.isEmpty else { return "None in this range" }
        let auto = switches.filter { $0.source == .auto }.count
        let mine = switches.filter { $0.source == .cswapbar }.count
        return "\(mine) from CSwapBar · \(auto) auto · \(switches.count - mine - auto) other"
    }

    private var busiest: (name: String, peak: Double)? {
        let names = model.historyNames()
        let peaks = Dictionary(grouping: samples, by: \.account).compactMapValues { rows in
            rows.compactMap { value(of: $0) }.max()
        }
        guard let top = peaks.max(by: { $0.value < $1.value }) else { return nil }
        return (names[top.key] ?? "Removed account", top.value)
    }

    // MARK: Chart

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let name: String
        let value: Double
    }

    private var points: [Point] {
        let names = model.historyNames()
        return samples.compactMap { s in
            value(of: s).map { Point(date: s.date, name: names[s.account] ?? "Removed account", value: $0) }
        }
    }

    private func value(of sample: UsageSample) -> Double? {
        window == .fiveHour ? sample.fiveHour : sample.sevenDay
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Usage over time")
                    .font(theme.type.title)
                    .foregroundStyle(theme.text)
                Spacer()
                ThemedSegmented(selection: $window, options: Window.allCases.map { ($0, $0.title) })
            }
            if points.isEmpty {
                emptyState("No readings yet", detail: model.settings.historyEnabled
                           ? "CSwapBar records usage as it refreshes. Check back in a few minutes."
                           : "Turn on history in Settings → History to start recording.")
                    .frame(height: 260)
            } else {
                Chart {
                    ForEach(points) { p in
                        LineMark(x: .value("Time", p.date), y: .value("Usage", p.value))
                            .foregroundStyle(by: .value("Account", p.name))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                    }
                    RuleMark(y: .value("Red", model.thresholds.critical))
                        .foregroundStyle(theme.critical.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    RuleMark(y: .value("Orange", model.thresholds.high))
                        .foregroundStyle(theme.high.opacity(0.4))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine().foregroundStyle(theme.border)
                        AxisValueLabel { Text("\(value.as(Int.self) ?? 0)%").foregroundStyle(theme.muted) }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine().foregroundStyle(theme.border.opacity(0.5))
                        AxisValueLabel().foregroundStyle(theme.muted)
                    }
                }
                .chartLegend(position: .bottom, alignment: .leading)
                .frame(height: 280)
                .accessibilityLabel("Usage over the last \(range.title) for each account")
            }
        }
        .card()
    }

    // MARK: Switches

    private var switchesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Switches")
                .font(theme.type.title)
                .foregroundStyle(theme.text)
            if switches.isEmpty {
                emptyState("No switches in the last \(range.title)", detail: "Switches made from CSwapBar, the terminal or CSwap's auto-switch appear here.")
                    .frame(height: 90)
            } else {
                let names = model.historyNames()
                ForEach(Array(switches.reversed().prefix(50).enumerated()), id: \.offset) { index, change in
                    if index > 0 { RowDivider() }
                    HStack(spacing: 10) {
                        Text(change.date.formatted(date: .abbreviated, time: .shortened))
                            .font(theme.type.footnote.monospacedDigit())
                            .foregroundStyle(theme.muted)
                            .frame(width: 150, alignment: .leading)
                        Text(change.from.map { names[$0] ?? "Removed account" } ?? "–")
                            .foregroundStyle(theme.muted)
                        Image(systemName: "arrow.right").font(theme.type.icon(10, .semibold)).foregroundStyle(theme.muted)
                        Text(names[change.to] ?? "Removed account")
                            .foregroundStyle(theme.text)
                        Spacer()
                        Badge(text: sourceTitle(change.source), color: change.source == .auto ? theme.accent : theme.muted)
                    }
                    .font(theme.type.body)
                    .lineLimit(1)
                    .padding(.vertical, 6)
                }
            }
        }
        .card()
    }

    private func sourceTitle(_ source: SwitchRecord.Source) -> String {
        switch source {
        case .cswapbar: "CSwapBar"
        case .auto: "Auto-switch"
        case .external: "Outside CSwapBar"
        }
    }

    private func emptyState(_ title: String, detail: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.xyaxis.line")
                .font(theme.type.icon(22))
                .foregroundStyle(theme.muted)
            Text(title).font(theme.type.body).foregroundStyle(theme.text)
            Text(detail).font(theme.type.footnote).foregroundStyle(theme.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Data

    private func load() {
        guard let history = model.history else { return }
        let since = Date().addingTimeInterval(-range.seconds)
        loadedSamples = (try? history.samples(since: since)) ?? []
        switches = (try? history.switches(since: since)) ?? []
    }

    private func export() {
        message = HistoryExport.run(model: model)
    }
}
