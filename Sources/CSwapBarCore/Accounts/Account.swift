import Foundation

/// Stable identity for an account across refreshes.
///
/// CSwap slot numbers can change (`cswap swap`, `cswap move`), so identity is
/// email + organization UUID. Never shown in the UI.
public struct AccountID: Hashable, Sendable, CustomStringConvertible {
    public let email: String
    public let organizationUUID: String

    public init(email: String, organizationUUID: String) {
        self.email = email.lowercased()
        self.organizationUUID = organizationUUID.lowercased()
    }

    public var description: String { "\(email)|\(organizationUUID)" }
}

public struct UsageWindow: Sendable, Equatable {
    /// 0–100. `nil` when CSwap reported the window without a figure.
    public let percent: Double?
    public let resetsAt: Date?
    /// Per-model windows only (e.g. "Fable").
    public let name: String?

    public init(percent: Double?, resetsAt: Date?, name: String? = nil) {
        self.percent = percent
        self.resetsAt = resetsAt
        self.name = name
    }
}

public struct Usage: Sendable, Equatable {
    public let fiveHour: UsageWindow?
    public let sevenDay: UsageWindow?
    public let scoped: [UsageWindow]
    public let fetchedAt: Date?
    /// True when CSwap could not fetch fresh usage and this is the last good reading.
    public let isLastKnown: Bool

    public init(
        fiveHour: UsageWindow?,
        sevenDay: UsageWindow?,
        scoped: [UsageWindow] = [],
        fetchedAt: Date?,
        isLastKnown: Bool = false
    ) {
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
        self.scoped = scoped
        self.fetchedAt = fetchedAt
        self.isLastKnown = isLastKnown
    }

    /// The tightest of the 5-hour and 7-day windows.
    public var peakPercent: Double? {
        [fiveHour?.percent, sevenDay?.percent].compactMap { $0 }.max()
    }
}

public struct SubscriptionPlan: Sendable, Equatable {
    public let label: String?
    public let tier: String?
    public let subscriptionStatus: String?
    public let isExpired: Bool

    public init(label: String?, tier: String?, subscriptionStatus: String?, isExpired: Bool) {
        self.label = label
        self.tier = tier
        self.subscriptionStatus = subscriptionStatus
        self.isExpired = isExpired
    }
}

/// CSwap's `usageStatus`.
public enum UsageStatus: Sendable, Equatable {
    case ok
    case tokenExpired
    case apiKey
    case keychainUnavailable
    case reloginRequired
    case foreignCredential
    case noCredentials
    case unavailable
    case unrecognized(String)

    init(raw: String?) {
        switch raw {
        case "ok": self = .ok
        case "token_expired": self = .tokenExpired
        case "api_key": self = .apiKey
        case "keychain_unavailable": self = .keychainUnavailable
        case "relogin_required": self = .reloginRequired
        case "foreign_credential": self = .foreignCredential
        case "no_credentials": self = .noCredentials
        case "unavailable", nil: self = .unavailable
        case let other?: self = .unrecognized(other)
        }
    }
}

/// Whether an account can be used right now, derived from CSwap's data.
public enum Availability: Sendable, Equatable {
    case available
    case rateLimited
    case expired
    case unavailable
    case unknown
}

public struct Account: Identifiable, Sendable, Equatable {
    public let id: AccountID
    /// Current CSwap slot. Use only for switching; it can change.
    public let slot: Int
    public let email: String
    public let alias: String?
    public let organizationName: String?
    public let isOrganization: Bool
    public let isActive: Bool
    /// Held out of CSwap's auto-rotation. Still switchable manually.
    public let isDisabled: Bool
    public let plan: SubscriptionPlan?
    public let usage: Usage?
    public let usageStatus: UsageStatus
    /// Last fetch failure kind, e.g. "http-429" or "timeout".
    public let usageError: String?
    public let loginExpiresAt: Date?

    public init(
        id: AccountID,
        slot: Int,
        email: String,
        alias: String?,
        organizationName: String?,
        isOrganization: Bool,
        isActive: Bool,
        isDisabled: Bool,
        plan: SubscriptionPlan?,
        usage: Usage?,
        usageStatus: UsageStatus,
        usageError: String?,
        loginExpiresAt: Date?
    ) {
        self.id = id
        self.slot = slot
        self.email = email
        self.alias = alias
        self.organizationName = organizationName
        self.isOrganization = isOrganization
        self.isActive = isActive
        self.isDisabled = isDisabled
        self.plan = plan
        self.usage = usage
        self.usageStatus = usageStatus
        self.usageError = usageError
        self.loginExpiresAt = loginExpiresAt
    }

    public var availability: Availability {
        if usageStatus == .reloginRequired || plan?.isExpired == true { return .expired }
        switch usageStatus {
        case .ok:
            guard let usage, !usage.isLastKnown else { return .unknown }
            if let peak = usage.peakPercent, peak >= 100 { return .rateLimited }
            return .available
        case .apiKey:
            return .available
        case .noCredentials, .keychainUnavailable, .foreignCredential:
            return .unavailable
        case .reloginRequired:
            return .expired
        case .tokenExpired, .unavailable, .unrecognized:
            return .unknown
        }
    }

    /// Alias if set, otherwise the email. Not privacy-aware; see PrivacyManager (Phase 4).
    public var displayName: String {
        if let alias, !alias.isEmpty { return alias }
        return email
    }
}

/// All accounts from one `cswap list --json` call.
public struct AccountSnapshot: Sendable, Equatable {
    public let accounts: [Account]
    public let capturedAt: Date

    public init(accounts: [Account], capturedAt: Date) {
        self.accounts = accounts
        self.capturedAt = capturedAt
    }

    public var activeAccount: Account? { accounts.first(where: \.isActive) }
}
