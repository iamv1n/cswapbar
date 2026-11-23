import Foundation

/// Counts for the popover header and widgets ("4 accounts · 3 ready · 1 limited").
public struct AccountSummary: Sendable, Equatable {
    public let total: Int
    /// Usable right now.
    public let ready: Int
    /// At a 5-hour or 7-day limit.
    public let limited: Int
    /// Expired login or missing credentials: the user has to act.
    public let needsAttention: Int

    public init(_ accounts: [Account]) {
        total = accounts.count
        ready = accounts.filter { $0.availability == .available }.count
        limited = accounts.filter { $0.availability == .rateLimited }.count
        needsAttention = accounts.filter { $0.availability == .expired || $0.availability == .unavailable }.count
    }

    /// "4 accounts"
    public var totalText: String { "\(total) account\(total == 1 ? "" : "s")" }

    /// "3 of 4 ready"
    public var readyText: String { "\(ready) of \(total) ready" }
}
