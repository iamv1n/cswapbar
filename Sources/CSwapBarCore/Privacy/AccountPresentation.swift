import Foundation

/// Display-safe view of an account. Views render only this, never `Account`'s
/// raw identity fields, so masking can't be forgotten in one place.
public struct AccountPresentation: Sendable, Equatable, Identifiable {
    public let id: AccountID
    public let title: String
    /// Secondary line (email / organization / plan), already masked. `nil` if nothing to show.
    public let subtitle: String?
    /// False in Privacy Mode, so the icon doesn't reveal "organization account".
    public let showsOrganizationIcon: Bool
    public let showsUsage: Bool
    public let showsResetTimes: Bool
    /// True when identity is being hidden (drives the privacy indicator).
    public let isMasked: Bool
    public let accessibilityLabel: String
}

public enum AccountPresenter {
    public static func present(_ account: Account, preferences prefs: PrivacyPreferences) -> AccountPresentation {
        let generic = Masking.genericLabel(slot: account.slot)
        let maskAlias = prefs.shouldMask(.alias) || prefs.useGenericAccountNames
        let maskEmail = prefs.shouldMask(.email)

        // Privacy Mode drops the email; the individual setting shows a partial mask.
        let emailText: String? = prefs.privacyModeEnabled ? nil : (maskEmail ? Masking.email(account.email) : account.email)

        let title: String
        if let alias = account.alias, !maskAlias {
            title = alias
        } else if !maskEmail, !prefs.useGenericAccountNames, !prefs.privacyModeEnabled {
            title = account.email
        } else {
            title = generic
        }

        var details: [String] = []
        if let emailText, emailText != title { details.append(emailText) }
        if let org = account.organizationName, !prefs.shouldMask(.organization) { details.append(org) }
        if let plan = account.plan?.label, !prefs.shouldMask(.subscription) { details.append(plan) }
        let subtitle = details.isEmpty ? nil : details.joined(separator: " · ")

        let isMasked = prefs.privacyModeEnabled || maskAlias || maskEmail
        let accessibility = ([title] + (account.isActive ? ["active account"] : [])).joined(separator: ", ")

        return AccountPresentation(
            id: account.id,
            title: title,
            subtitle: subtitle,
            showsOrganizationIcon: account.isOrganization && !prefs.shouldMask(.organization),
            showsUsage: !prefs.shouldMask(.usage),
            showsResetTimes: !prefs.shouldMask(.resetTimestamps),
            isMasked: isMasked,
            accessibilityLabel: accessibility
        )
    }
}
