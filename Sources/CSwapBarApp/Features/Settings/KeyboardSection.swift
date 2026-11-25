import CSwapBarCore
import SwiftUI

/// Settings → General → Keyboard: the global "open CSwapBar" shortcut and a
/// reference of every key CSwapBar understands.
struct KeyboardSection: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            SettingsGroup("Keyboard", footer: "Global shortcuts work in any app. The Privacy Mode shortcut is in Settings → Privacy.") {
                SettingsRow("Open CSwapBar", subtitle: statusText, symbol: "menubar.arrow.down.rectangle") {
                    HStack(spacing: 8) {
                        if model.settings.openShortcut != .defaultOpenPopover {
                            Button("Reset") { model.settings.openShortcut = .defaultOpenPopover }
                                .buttonStyle(.quiet)
                                .font(theme.type.caption)
                                .foregroundStyle(theme.muted)
                        }
                        ShortcutRecorder(model: model, shortcut: $model.settings.openShortcut,
                                         isEnabled: $model.settings.openShortcutEnabled, purpose: "Open CSwapBar")
                            .opacity(model.settings.openShortcutEnabled ? 1 : 0.45)
                        Toggle("Open CSwapBar shortcut", isOn: $model.settings.openShortcutEnabled)
                            .toggleStyle(.themedSwitch).labelsHidden()
                    }
                }
            }

            SettingsGroup("Shortcuts") {
                ForEach(Array(Self.reference.enumerated()), id: \.offset) { index, item in
                    if index > 0 { RowDivider() }
                    HStack(spacing: 12) {
                        Text(item.action)
                            .font(theme.type.body)
                            .foregroundStyle(theme.text)
                        Spacer(minLength: 8)
                        Text(keys(for: item))
                            .font(theme.type.font(12.5, .semibold))
                            .tracking(0.4)
                            .foregroundStyle(theme.muted)
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                }
            }
        }
    }

    private var statusText: String {
        guard model.settings.openShortcutEnabled else { return "Off." }
        return switch model.openShortcutStatus {
        case .unavailable: "\(model.settings.openShortcut.displayString) is used by another app. Pick a different one."
        case .active: "Opens or closes the popover from any app."
        case .off: "Opens or closes the popover from any app."
        }
    }

    private struct Item {
        let action: String
        let keys: String
    }

    private func keys(for item: Item) -> String {
        switch item.keys {
        case "open": model.settings.openShortcutEnabled ? model.settings.openShortcut.displayString : "Off"
        case "privacy": model.settings.privacyShortcutEnabled
            ? "\(model.settings.privacyShortcut.displayString), or ⇧⌘P in the popover" : "⇧⌘P in the popover"
        default: item.keys
        }
    }

    private static let reference: [Item] = [
        Item(action: "Open or close CSwapBar (any app)", keys: "open"),
        Item(action: "Toggle Privacy Mode", keys: "privacy"),
        Item(action: "Highlight the previous or next account", keys: "↑  ↓"),
        Item(action: "Switch to the highlighted account", keys: "↩"),
        Item(action: "Switch to account 1–9", keys: "⌘1 – ⌘9"),
        Item(action: "Previous or next page", keys: "←  →"),
        Item(action: "Refresh now", keys: "⌘R"),
        Item(action: "Open Settings", keys: "⌘,"),
        Item(action: "Usage history dashboard", keys: "⌘Y"),
        Item(action: "Settings pages", keys: "⌘1 – ⌘9"),
        Item(action: "Close the popover", keys: "esc"),
        Item(action: "Close Settings", keys: "⌘W"),
        Item(action: "Quit", keys: "⌘Q"),
    ]
}
