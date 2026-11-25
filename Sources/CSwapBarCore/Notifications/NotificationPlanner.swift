import Foundation

/// A notification ready to post. Text is already privacy-safe.
public struct PlannedNotification: Sendable, Equatable {
    public enum Kind: String, Sendable {
        case usage
        case switched
        case switchFailed
        case needsLogin
        case update
    }

    public let kind: Kind
    public let title: String
    public let body: String

    public init(kind: Kind, title: String, body: String) {
        self.kind = kind
        self.title = title
        self.body = body
    }
}

/// Decides which notifications a new snapshot deserves.
///
/// Rules:
/// - Nothing is sent for what's already true when an account is first seen
///   (app launch, a newly added account). Only changes trigger alerts.
/// - A usage level fires once when crossed upward and re-arms after usage drops
///   `rearmMargin` points below it (e.g. after the window resets). Jumping past
///   several levels at once sends one alert, for the highest.
/// - Readings CSwap marks as last-known (stale) are ignored.
/// - A change of active account is announced unless CSwapBar itself made it.
/// - An account that starts needing a login is announced once.
///
/// State is kept in memory only, keyed by `AccountID`; nothing is persisted.
public struct NotificationPlanner: Sendable {
    public static let rearmMargin: Double = 5

    private struct WindowKey: Hashable, Sendable {
        let account: AccountID
        let window: NotificationText.Window
    }

    private var firedLevels: [WindowKey: Set<Int>] = [:]
    private var knownAccounts: Set<AccountID> = []
    private var needingLogin: Set<AccountID> = []
    private var lastActive: AccountID?
    private var hasSnapshot = false

    public init() {}

    /// - Parameter inAppSwitchTarget: the account CSwapBar is switching to, if any.
    ///   Becoming active is then expected and not announced.
    public mutating func process(
        _ snapshot: AccountSnapshot,
        preferences: NotificationPreferences,
        privacy: PrivacyPreferences,
        inAppSwitchTarget: AccountID? = nil
    ) -> [PlannedNotification] {
        var out: [PlannedNotification] = []
        let send = preferences.enabled

        for account in snapshot.accounts {
            let isNew = !knownAccounts.contains(account.id)

            // Usage levels.
            if let usage = account.usage, !usage.isLastKnown {
                let windows: [(NotificationText.Window, UsageWindow?)] = [(.fiveHour, usage.fiveHour), (.sevenDay, usage.sevenDay)]
                for (window, reading) in windows {
                    guard let percent = reading?.percent else { continue }
                    let key = WindowKey(account: account.id, window: window)
                    let seen = firedLevels[key] != nil
                    var fired = firedLevels[key] ?? []
                    fired = fired.filter { percent >= Double($0) - Self.rearmMargin }
                    let crossed = NotificationPreferences.availableLevels.filter { percent >= Double($0) && !fired.contains($0) }
                    fired.formUnion(crossed)
                    firedLevels[key] = fired

                    guard seen, send, preferences.usageAlerts,
                          let level = crossed.filter(preferences.isLevelEnabled).max() else { continue }
                    let text = NotificationText.usageThreshold(
                        account: account, window: window, percent: max(percent, Double(level)),
                        resetsAt: reading?.resetsAt, preferences: privacy)
                    out.append(PlannedNotification(kind: .usage, title: text.title, body: text.body))
                }
            }

            // Login needed.
            let needsLogin = account.availability == .expired
            if needsLogin, !needingLogin.contains(account.id), !isNew, send, preferences.loginAlerts {
                let text = NotificationText.needsLogin(account: account, preferences: privacy)
                out.append(PlannedNotification(kind: .needsLogin, title: text.title, body: text.body))
            }
            if needsLogin { needingLogin.insert(account.id) } else { needingLogin.remove(account.id) }
            knownAccounts.insert(account.id)
        }

        // Active account changes.
        let active = snapshot.activeAccount
        if hasSnapshot, let active, active.id != lastActive, active.id != inAppSwitchTarget,
           send, preferences.switchAlerts {
            let text = NotificationText.switched(to: active, preferences: privacy)
            out.append(PlannedNotification(kind: .switched, title: text.title, body: text.body))
        }
        if let active { lastActive = active.id }
        hasSnapshot = true

        // Forget accounts that were removed from CSwap.
        let current = Set(snapshot.accounts.map(\.id))
        knownAccounts.formIntersection(current)
        needingLogin.formIntersection(current)
        firedLevels = firedLevels.filter { current.contains($0.key.account) }

        return out
    }

    /// A switch started in CSwapBar failed.
    public func switchFailed(
        to account: Account,
        preferences: NotificationPreferences,
        privacy: PrivacyPreferences
    ) -> PlannedNotification? {
        guard preferences.enabled, preferences.switchAlerts else { return nil }
        let text = NotificationText.switchFailed(to: account, preferences: privacy)
        return PlannedNotification(kind: .switchFailed, title: text.title, body: text.body)
    }
}
