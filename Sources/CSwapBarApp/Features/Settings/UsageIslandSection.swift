import CSwapBarCore
import SwiftUI

/// Settings → Widgets → Usage Island. The island replaces the menu bar icon
/// (one or the other), so this is the same choice as General → Menu Bar.
struct UsageIslandSection: View {
    @Bindable var model: AppModel
    @Environment(\.theme) private var theme

    private var prefs: UsageIslandPreferences { model.settings.usageIsland }

    var body: some View {
        SettingsGroup("Usage Island", footer: footer) {
            SettingsRow("Show CSwapBar in",
                        subtitle: "The Usage Island is a small black bar at the top of the screen with your 5-hour usage. Hover to see more; click to open CSwapBar.",
                        symbol: "capsule.tophalf.filled") {
                ThemedSegmented(selection: $model.settings.usageIsland.enabled,
                                options: [(false, "Menu bar"), (true, "Usage Island")])
            }
            RowDivider()
            SettingsRow("Island style", symbol: "rectangle.topthird.inset.filled") {
                ThemedSegmented(selection: $model.settings.usageIsland.style,
                                options: UsageIslandPreferences.Style.allCases.map { ($0, $0.title) })
            }
            .opacity(prefs.enabled ? 1 : 0.5)
        }
    }

    private var footer: String {
        var text = "Only one shows at a time: the menu bar icon or the island. ⌃⌥⌘C opens CSwapBar either way."
        if prefs.style == .notch, !UsageIslandController.mainScreenHasNotch {
            text += " This screen has no notch, so the island floats below the menu bar."
        }
        return text
    }
}
