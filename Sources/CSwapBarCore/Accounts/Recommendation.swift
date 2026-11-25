import Foundation

/// "Which account should I use next?", explained.
///
/// Follows CSwap's `best` strategy (`cswap switch --strategy best`, `cswap auto`):
/// headroom = 100 − the account's highest window (5-hour or weekly), and the
/// account with the most headroom wins. Disabled accounts (held out of rotation),
/// API-key accounts, and accounts that can't be used right now are skipped.
public struct AccountRecommendation: Sendable, Equatable {
    public let account: Account
    /// 0–100, percent of quota left in the tighter window.
    public let headroom: Double
    /// Headroom of the active account, for comparison.
    public let activeHeadroom: Double?

    /// Headroom as CSwap computes it, or nil without usage figures.
    public static func headroom(of account: Account) -> Double? {
        guard let usage = account.usage, !usage.isLastKnown, let peak = usage.peakPercent else { return nil }
        return max(0, 100 - peak)
    }

    /// The best account to switch to, or nil when the active one is already best
    /// (or nothing else is usable).
    public static func best(in accounts: [Account]) -> AccountRecommendation? {
        let active = accounts.first(where: \.isActive)
        let activeHeadroom = active.flatMap(headroom(of:))
        let candidates = accounts.compactMap { account -> (Account, Double)? in
            guard !account.isActive, !account.isDisabled, account.usageStatus != .apiKey,
                  account.availability == .available, let room = headroom(of: account), room > 0 else { return nil }
            return (account, room)
        }
        // Most headroom; ties go to more 5-hour room, then the lower slot (stable).
        guard let best = candidates.max(by: { a, b in
            if a.1 != b.1 { return a.1 < b.1 }
            let fa = 100 - (a.0.usage?.fiveHour?.percent ?? 100), fb = 100 - (b.0.usage?.fiveHour?.percent ?? 100)
            if fa != fb { return fa < fb }
            return a.0.slot > b.0.slot
        }) else { return nil }
        if let activeHeadroom, activeHeadroom >= best.1 { return nil }
        return AccountRecommendation(account: best.0, headroom: best.1, activeHeadroom: activeHeadroom)
    }

    /// One line for the popover, privacy-aware. E.g.
    /// "Work has the most headroom: 88% left (you have 12%)".
    public func explanation(preferences: PrivacyPreferences) -> String {
        let name = AccountPresenter.present(account, preferences: preferences).title
        if preferences.shouldMask(.usage) {
            return "\(name) has the most quota left."
        }
        let left = "\(Int(headroom.rounded()))% left"
        if let activeHeadroom {
            return "\(name) has the most headroom: \(left) (you have \(Int(activeHeadroom.rounded()))%)."
        }
        return "\(name) has the most headroom: \(left)."
    }

    /// Whether to surface it: only when the active account is getting tight.
    public func isWorthShowing(thresholds: UsageThresholds) -> Bool {
        guard let activeHeadroom else { return true }
        return 100 - activeHeadroom >= thresholds.warning
    }
}
