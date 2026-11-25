import AppKit
import CSwapBarCore
import SwiftUI

/// Settings → General → Updates.
struct UpdatesSection: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme

    private var updater: Updater? { model.updater }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let update = updater?.availableUpdate {
                availableCard(update)
            }

            SettingsGroup("Updates", footer: "Checks GitHub Releases once a day. The request carries no information about you or your accounts.") {
                SettingsRow("CSwapBar \(Updater.currentVersionString)", subtitle: statusText, symbol: "shippingbox") {
                    HStack(spacing: 8) {
                        if isBusy { ProgressView().controlSize(.small) }
                        Button("Check Now") { Task { await updater?.check(userInitiated: true) } }
                            .buttonStyle(AccentButtonStyle())
                            .disabled(updater == nil || isBusy)
                    }
                }
                RowDivider()
                SettingsRow("Check automatically", symbol: "arrow.triangle.2.circlepath") {
                    Toggle("Check automatically", isOn: $model.settings.updates.checkAutomatically)
                        .toggleStyle(.themedSwitch).labelsHidden()
                }
                RowDivider()
                SettingsRow("Install automatically", subtitle: installSubtitle, symbol: "arrow.down.app") {
                    Toggle("Install automatically", isOn: $model.settings.updates.installAutomatically)
                        .toggleStyle(.themedSwitch).labelsHidden()
                        .disabled(!model.settings.updates.checkAutomatically || !Updater.canSelfInstall)
                }
            }
        }
    }

    private var isBusy: Bool {
        switch updater?.state {
        case .checking, .installing: true
        default: false
        }
    }

    private var statusText: String {
        guard let updater else { return "Update checks run in the app." }
        switch updater.state {
        case .checking: return "Checking GitHub…"
        case .installing(let step): return step
        case .failed(let message): return message
        case .available(let update): return "Version \(update.version) is available."
        case .upToDate, .idle:
            guard let checked = updater.lastChecked else { return "Not checked yet." }
            let age = CountdownFormatter.age(since: checked) ?? ""
            return updater.state == .upToDate ? "Up to date · checked \(age)" : "Last checked \(age)"
        }
    }

    private var installSubtitle: String {
        Updater.canSelfInstall
            ? "Downloads the release, verifies its checksum, and restarts CSwapBar."
            : "Available when CSwapBar runs from the Applications folder."
    }

    private func availableCard(_ update: AvailableUpdate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .font(theme.type.icon(16, .semibold))
                    .foregroundStyle(theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CSwapBar \(update.version) is available")
                        .font(theme.type.title)
                        .foregroundStyle(theme.text)
                    Text("You have \(Updater.currentVersionString).")
                        .font(theme.type.caption)
                        .foregroundStyle(theme.muted)
                }
            }
            if !update.notes.isEmpty {
                Text(update.notes)
                    .font(theme.type.caption)
                    .foregroundStyle(theme.muted)
                    .lineLimit(6)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 10) {
                if update.canInstall && Updater.canSelfInstall {
                    Button("Install and Restart") { Task { await updater?.install(update) } }
                        .buttonStyle(AccentButtonStyle())
                        .disabled(isBusy)
                } else {
                    Button("Download") { NSWorkspace.shared.open(update.releasePage) }
                        .buttonStyle(AccentButtonStyle())
                }
                Button("Release Notes") { NSWorkspace.shared.open(update.releasePage) }
                    .buttonStyle(.quiet)
                    .font(theme.type.font(12, .semibold))
                    .foregroundStyle(theme.accent)
                Spacer()
                Button("Skip This Version") {
                    model.settings.updates.skippedVersion = update.version.description
                    Task { await updater?.check(userInitiated: false) }
                }
                .buttonStyle(.quiet)
                .font(theme.type.font(12, .medium))
                .foregroundStyle(theme.muted)
            }
        }
        .card(highlighted: true)
    }
}
