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

/// Notification copy that respects privacy. Masked variants never name an
/// account, and usage figures and reset times follow their own privacy toggles.
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
        resetsAt: Date? = nil,
        preferences: PrivacyPreferences,
        now: Date = Date()
    ) -> (title: String, body: String) {
        let atLimit = percent >= 100
        let title = atLimit ? "Usage limit reached" : "Usage threshold reached"
        if preferences.shouldMask(.notificationDetails) {
            return (title, atLimit
                ? "One of your Claude accounts has hit a usage limit."
                : "One of your Claude accounts has reached a usage threshold.")
        }
        let name = AccountPresenter.present(account, preferences: preferences).title
        var body: String
        if atLimit {
            body = "\(name) has hit its \(window.name) limit."
            if !preferences.shouldMask(.resetTimestamps),
               let countdown = CountdownFormatter.string(until: resetsAt, now: now), countdown != "now" {
                body += " Resets in \(countdown)."
            }
        } else {
            body = preferences.shouldMask(.usage)
                ? "\(name) has reached its \(window.name) usage threshold."
                : "\(name) has reached \(Int(percent.rounded()))% \(window.name) usage."
        }
        return (title, body)
    }

    public static func switched(to account: Account, preferences: PrivacyPreferences) -> (title: String, body: String) {
        if preferences.shouldMask(.notificationDetails) {
            return ("Account switched", "Claude Code is now using a different account.")
        }
        let name = AccountPresenter.present(account, preferences: preferences).title
        return ("Account switched", "Claude Code is now using \(name).")
    }

    public static func switchFailed(to account: Account, preferences: PrivacyPreferences) -> (title: String, body: String) {
        if preferences.shouldMask(.notificationDetails) {
            return ("Switch failed", "CSwapBar couldn't switch accounts. Open CSwapBar for details.")
        }
        let name = AccountPresenter.present(account, preferences: preferences).title
        return ("Switch failed", "CSwapBar couldn't switch to \(name). Open CSwapBar for details.")
    }

    public static func needsLogin(account: Account, preferences: PrivacyPreferences) -> (title: String, body: String) {
        if preferences.shouldMask(.notificationDetails) {
            return ("Login needed", "One of your Claude accounts needs a new login before CSwap can use it.")
        }
        let name = AccountPresenter.present(account, preferences: preferences).title
        return ("Login needed", "\(name) needs a new login before CSwap can use it.")
    }
}
