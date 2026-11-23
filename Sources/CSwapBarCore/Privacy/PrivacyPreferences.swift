import Foundation

/// Privacy settings. All OFF by default.
public struct PrivacyPreferences: Codable, Sendable, Equatable {
    public var privacyModeEnabled: Bool = false

    public var hideEmails: Bool = false
    public var hideAliases: Bool = false
    public var hideAccountIDs: Bool = false
    public var hideOrganization: Bool = false
    public var hideSubscriptionDetails: Bool = false

    public var hideUsagePercentages: Bool = false
    public var hideResetTimestamps: Bool = false

    public var hideNotificationDetails: Bool = false
    public var useGenericAccountNames: Bool = false

    public init() {}

    // Decode leniently so a preference added later doesn't reset the others.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func flag(_ key: CodingKeys) -> Bool { (try? c.decodeIfPresent(Bool.self, forKey: key)) ?? false }
        privacyModeEnabled = flag(.privacyModeEnabled)
        hideEmails = flag(.hideEmails)
        hideAliases = flag(.hideAliases)
        hideAccountIDs = flag(.hideAccountIDs)
        hideOrganization = flag(.hideOrganization)
        hideSubscriptionDetails = flag(.hideSubscriptionDetails)
        hideUsagePercentages = flag(.hideUsagePercentages)
        hideResetTimestamps = flag(.hideResetTimestamps)
        hideNotificationDetails = flag(.hideNotificationDetails)
        useGenericAccountNames = flag(.useGenericAccountNames)
    }
}

/// Anything that could identify an account or reveal its state.
public enum SensitiveField: CaseIterable, Sendable {
    case email
    case alias
    case accountID
    case organization
    case subscription
    case usage
    case resetTimestamps
    case notificationDetails
}

extension PrivacyPreferences {
    /// The single masking rule every surface uses.
    ///
    /// Privacy Mode always masks identity fields, whatever the individual
    /// settings say. Usage values and reset times aren't identifying, so they
    /// follow their own toggles even in Privacy Mode (hiding usage is optional).
    public func shouldMask(_ field: SensitiveField) -> Bool {
        switch field {
        case .email: privacyModeEnabled || hideEmails
        case .alias: privacyModeEnabled || hideAliases
        case .accountID: privacyModeEnabled || hideAccountIDs
        case .organization: privacyModeEnabled || hideOrganization
        case .subscription: privacyModeEnabled || hideSubscriptionDetails
        case .notificationDetails: privacyModeEnabled || hideNotificationDetails
        case .usage: hideUsagePercentages
        case .resetTimestamps: hideResetTimestamps
        }
    }
}

/// Free-function form of `PrivacyPreferences.shouldMask(_:)`.
public func shouldMask(field: SensitiveField, preferences: PrivacyPreferences) -> Bool {
    preferences.shouldMask(field)
}
