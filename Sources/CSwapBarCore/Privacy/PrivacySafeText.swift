import Foundation

/// What the menu-bar item shows next to its icon.
public enum MenuBarDisplay: String, CaseIterable, Codable, Sendable {
    case iconOnly
    case accountName
    case fiveHourUsage
    case peakUsage

    public var title: String {
        switch self {
        case .iconOnly: "Icon only"
        case .accountName: "Icon + account name"
        case .fiveHourUsage: "Icon + 5-hour usage"
        case .peakUsage: "Icon + highest usage"
        }
    }
}

public enum MenuBarText {
    /// Text beside the menu-bar icon, or `nil` for icon only.
    /// Never contains masked identity: in Privacy Mode the account name is replaced
    /// by nothing (a privacy indicator is shown instead, see `showsPrivacyIndicator`).
    public static func text(
        display: MenuBarDisplay,
        activeAccount: Account?,
        preferences: PrivacyPreferences
    ) -> String? {
        guard let account = activeAccount else { return nil }
        switch display {
        case .iconOnly:
            return nil
        case .accountName:
            if preferences.privacyModeEnabled { return nil }
            return AccountPresenter.present(account, preferences: preferences).title
        case .fiveHourUsage:
            guard !preferences.shouldMask(.usage), let pct = account.usage?.fiveHour?.percent else { return nil }
            return "\(Int(pct.rounded()))%"
        case .peakUsage:
            guard !preferences.shouldMask(.usage), let pct = account.usage?.peakPercent else { return nil }
            return "\(Int(pct.rounded()))%"
        }
    }

    public static func showsPrivacyIndicator(_ preferences: PrivacyPreferences) -> Bool {
        preferences.privacyModeEnabled
    }
}

/// Notification copy that respects privacy. For the upcoming notifications
/// feature (see ROADMAP.md); kept here so the wording is unit-tested now.
public enum NotificationText {
    public enum Window: Sendable {
        case fiveHour
        case sevenDay

        var name: String {
            switch self {
            case .fiveHour: "5-hour"
            case .sevenDay: "weekly"
            }
        }
    }

    public static func usageThreshold(
        account: Account,
        window: Window,
        percent: Double,
        preferences: PrivacyPreferences
    ) -> (title: String, body: String) {
        if preferences.shouldMask(.notificationDetails) {
            return ("Usage threshold reached", "One of your Claude accounts has reached a usage threshold.")
        }
        let name = AccountPresenter.present(account, preferences: preferences).title
        let body = preferences.shouldMask(.usage)
            ? "\(name) has reached its \(window.name) usage threshold."
            : "\(name) has reached \(Int(percent.rounded()))% \(window.name) usage."
        return ("Usage threshold reached", body)
    }

    public static func switched(to account: Account, preferences: PrivacyPreferences) -> (title: String, body: String) {
        if preferences.shouldMask(.notificationDetails) {
            return ("Account switched", "Claude Code is now using a different account.")
        }
        let name = AccountPresenter.present(account, preferences: preferences).title
        return ("Account switched", "Claude Code is now using \(name).")
    }
}
