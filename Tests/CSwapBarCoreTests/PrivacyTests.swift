import Foundation
import Testing
@testable import CSwapBarCore

private func makeAccount(
    slot: Int = 2,
    email: String = "you@example.com",
    alias: String? = "work",
    org: String? = "Example Corp",
    plan: String? = "Max 20x",
    fiveHour: Double? = 38,
    sevenDay: Double? = 24,
    active: Bool = true
) -> Account {
    Account(
        id: AccountID(email: email, organizationUUID: org == nil ? "" : "org-uuid"),
        slot: slot, email: email, alias: alias, organizationName: org,
        isOrganization: org != nil, isActive: active, isDisabled: false,
        plan: plan.map { SubscriptionPlan(label: $0, tier: nil, subscriptionStatus: nil, isExpired: false) },
        usage: Usage(
            fiveHour: UsageWindow(percent: fiveHour, resetsAt: Date(timeIntervalSinceNow: 3600)),
            sevenDay: UsageWindow(percent: sevenDay, resetsAt: Date(timeIntervalSinceNow: 86_400)),
            fetchedAt: Date()
        ),
        usageStatus: .ok, usageError: nil, loginExpiresAt: nil
    )
}

/// Every string a presentation can put on screen.
private func visibleStrings(_ p: AccountPresentation) -> String {
    [p.title, p.subtitle ?? "", p.accessibilityLabel].joined(separator: " | ")
}

private var privacyMode: PrivacyPreferences {
    var prefs = PrivacyPreferences()
    prefs.privacyModeEnabled = true
    return prefs
}

@Suite("Privacy masking")
struct PrivacyTests {
    @Test func defaultsShowEverything() {
        let p = AccountPresenter.present(makeAccount(), preferences: PrivacyPreferences())
        #expect(p.title == "work")
        #expect(p.subtitle == "you@example.com · Example Corp · Max 20x")
        #expect(p.showsUsage && p.showsResetTimes && p.showsOrganizationIcon)
        #expect(!p.isMasked)
    }

    @Test func maskedEmailKeepsFirstLetterAndTLD() {
        #expect(Masking.email("you@example.com") == "y••@•••••••.com")
        #expect(Masking.email("a@b.io") == "a••@•.io")
        #expect(Masking.email("no-at-sign") == "••••••••••")
    }

    @Test func hideEmailsShowsPartialMask() {
        var prefs = PrivacyPreferences()
        prefs.hideEmails = true
        let p = AccountPresenter.present(makeAccount(), preferences: prefs)
        #expect(!visibleStrings(p).contains("you@example.com"))
        #expect(p.subtitle?.contains("y••@•••••••.com") == true)
    }

    @Test func hideAliasesUsesGenericLabelFromSlotNotName() {
        var prefs = PrivacyPreferences()
        prefs.hideAliases = true
        prefs.hideEmails = true
        let p = AccountPresenter.present(makeAccount(slot: 3), preferences: prefs)
        #expect(p.title == "Account 03")
        #expect(!visibleStrings(p).contains("work"))
    }

    @Test func hideAliasFallsBackToEmailWhenEmailVisible() {
        var prefs = PrivacyPreferences()
        prefs.hideAliases = true
        let p = AccountPresenter.present(makeAccount(), preferences: prefs)
        #expect(p.title == "you@example.com")
        #expect(!visibleStrings(p).contains("work"))
    }

    @Test func genericNamesOverrideAlias() {
        var prefs = PrivacyPreferences()
        prefs.useGenericAccountNames = true
        let p = AccountPresenter.present(makeAccount(slot: 12), preferences: prefs)
        #expect(p.title == "Account 12")
    }

    @Test func hideOrganizationAndSubscription() {
        var prefs = PrivacyPreferences()
        prefs.hideOrganization = true
        prefs.hideSubscriptionDetails = true
        let p = AccountPresenter.present(makeAccount(), preferences: prefs)
        #expect(!visibleStrings(p).contains("Example Corp"))
        #expect(!visibleStrings(p).contains("Max 20x"))
        #expect(!p.showsOrganizationIcon)
    }

    @Test func hideUsageAndResets() {
        var prefs = PrivacyPreferences()
        prefs.hideUsagePercentages = true
        prefs.hideResetTimestamps = true
        let p = AccountPresenter.present(makeAccount(), preferences: prefs)
        #expect(!p.showsUsage)
        #expect(!p.showsResetTimes)
    }

    @Test func privacyModeMasksAllIdentityRegardlessOfIndividualSettings() {
        let p = AccountPresenter.present(makeAccount(), preferences: privacyMode)
        let text = visibleStrings(p)
        for secret in ["you@example.com", "y••@", "work", "Example Corp", "Max 20x", "org-uuid"] {
            #expect(!text.contains(secret), "leaked \(secret)")
        }
        #expect(p.title == "Account 02")
        #expect(p.subtitle == nil)
        #expect(p.isMasked)
        #expect(!p.showsOrganizationIcon)
    }

    @Test func privacyModeMasksEveryIdentityField() {
        let identity: [SensitiveField] = [.email, .alias, .accountID, .organization, .subscription, .notificationDetails]
        for field in identity {
            #expect(shouldMask(field: field, preferences: privacyMode))
        }
        // Usage values stay optional in Privacy Mode.
        #expect(!privacyMode.shouldMask(.usage))
    }

    @Test func disablingPrivacyModeRestoresDisplay() {
        var prefs = privacyMode
        prefs.privacyModeEnabled = false
        let p = AccountPresenter.present(makeAccount(), preferences: prefs)
        #expect(p == AccountPresenter.present(makeAccount(), preferences: PrivacyPreferences()))
    }

    @Test func originalAccountIsUnchanged() {
        let account = makeAccount()
        _ = AccountPresenter.present(account, preferences: privacyMode)
        #expect(account.email == "you@example.com")
        #expect(account.alias == "work")
    }
}

@Suite("Privacy-safe text")
struct PrivacySafeTextTests {
    @Test func menuBarNameHiddenInPrivacyMode() {
        let account = makeAccount()
        #expect(MenuBarText.text(display: .accountName, activeAccount: account, preferences: PrivacyPreferences()) == "work")
        #expect(MenuBarText.text(display: .accountName, activeAccount: account, preferences: privacyMode) == nil)
        #expect(MenuBarText.showsPrivacyIndicator(privacyMode))
    }

    @Test func menuBarUsageRespectsHideUsage() {
        let account = makeAccount(fiveHour: 38, sevenDay: 71)
        #expect(MenuBarText.text(display: .fiveHourUsage, activeAccount: account, preferences: PrivacyPreferences()) == "38%")
        #expect(MenuBarText.text(display: .peakUsage, activeAccount: account, preferences: PrivacyPreferences()) == "71%")
        var prefs = PrivacyPreferences()
        prefs.hideUsagePercentages = true
        #expect(MenuBarText.text(display: .fiveHourUsage, activeAccount: account, preferences: prefs) == nil)
        #expect(MenuBarText.text(display: .iconOnly, activeAccount: account, preferences: PrivacyPreferences()) == nil)
    }

    @Test func notificationsDoNotLeakInPrivacyMode() {
        let account = makeAccount()
        let usage = NotificationText.usageThreshold(account: account, window: .sevenDay, percent: 80, preferences: privacyMode)
        let switched = NotificationText.switched(to: account, preferences: privacyMode)
        for text in [usage.title, usage.body, switched.title, switched.body] {
            #expect(!text.contains("work"))
            #expect(!text.contains("example.com"))
        }
        #expect(usage.body == "One of your Claude accounts has reached a usage threshold.")
    }

    @Test func notificationsNameAccountWhenAllowed() {
        let usage = NotificationText.usageThreshold(account: makeAccount(), window: .sevenDay, percent: 80, preferences: PrivacyPreferences())
        #expect(usage.body == "work has reached 80% weekly usage.")
    }

    @Test func notificationDetailsSettingAloneMasks() {
        var prefs = PrivacyPreferences()
        prefs.hideNotificationDetails = true
        let switched = NotificationText.switched(to: makeAccount(), preferences: prefs)
        #expect(!switched.body.contains("work"))
    }
}

@Suite("Settings persistence")
struct SettingsPersistenceTests {
    private func freshDefaults() -> UserDefaults {
        let name = "CSwapBarTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func settingsSurviveRestart() {
        let defaults = freshDefaults()
        var settings = AppSettings()
        settings.privacy.privacyModeEnabled = true
        settings.privacy.hideEmails = true
        settings.theme = .midnight
        settings.accent = .teal
        settings.menuBarDisplay = .peakUsage
        settings.refreshIntervalSeconds = 120
        SettingsStore(defaults: defaults).save(settings)

        // A new store instance stands in for a relaunch.
        #expect(SettingsStore(defaults: defaults).load() == settings)
    }

    @Test func missingSettingsUseDefaults() {
        let loaded = SettingsStore(defaults: freshDefaults()).load()
        #expect(loaded == AppSettings())
        #expect(loaded.privacy.privacyModeEnabled == false)
    }

    @Test func unknownValuesFallBackWithoutLosingOthers() throws {
        let json = #"{"theme":"neon","accent":"teal","privacy":{"privacyModeEnabled":true,"futureToggle":true},"refreshIntervalSeconds":1}"#
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
        #expect(settings.theme == .system)
        #expect(settings.accent == .teal)
        #expect(settings.privacy.privacyModeEnabled)
        #expect(settings.refreshIntervalSeconds == 15)   // clamped
    }
}

@Suite("Themes")
struct ThemeTests {
    @Test(arguments: ThemePalette.all)
    func textIsReadable(palette: ThemePalette) {
        // WCAG AA body text 4.5:1; primary text aims for AAA 7:1.
        for surface in [palette.background, palette.surface, palette.elevated] {
            #expect(ColorContrast.ratio(palette.text, surface) >= 7, "\(palette.name) text")
            #expect(ColorContrast.ratio(palette.muted, surface) >= 4.5, "\(palette.name) muted")
        }
    }

    @Test(arguments: ThemePalette.all)
    func usageColorsAreDistinguishableFromCards(palette: ThemePalette) {
        // WCAG non-text contrast 3:1 for the usage bars.
        for color in [palette.healthy, palette.warning, palette.high, palette.critical] {
            #expect(ColorContrast.ratio(color, palette.surface) >= 3, "\(palette.name) usage color")
        }
    }

    @Test(arguments: ThemePalette.all)
    func everyAccentIsReadableOnEveryTheme(palette: ThemePalette) {
        for accent in AccentChoice.allCases {
            let ratio = ColorContrast.ratio(accent.color(on: palette), palette.surface)
            #expect(ratio >= 4.5, "\(accent.title) on \(palette.name): \(ratio)")
        }
    }

    @Test func adaptiveThemesFollowAppearance() {
        #expect(ThemeChoice.system.palette(systemIsDark: true) == .atelierDark)
        #expect(ThemeChoice.system.palette(systemIsDark: false) == .atelierLight)
        #expect(ThemeChoice.native.palette(systemIsDark: true) == .nativeDark)
        #expect(ThemeChoice.glass.palette(systemIsDark: false) == .glassLight)
        #expect(ThemeChoice.paper.palette(systemIsDark: true) == .paper)
    }

    @Test func everyThemeResolvesAndBelongsToOneGroup() {
        for choice in ThemeChoice.allCases {
            _ = choice.palette(systemIsDark: true)
            _ = choice.palette(systemIsDark: false)
            #expect(!choice.title.isEmpty && !choice.tagline.isEmpty)
        }
        let grouped = ThemeChoice.Group.allCases.flatMap(ThemeChoice.choices(in:))
        #expect(Set(grouped) == Set(ThemeChoice.allCases))
        #expect(grouped.count == ThemeChoice.allCases.count)
    }

    @Test func materialThemesAreMarked() {
        #expect(ThemePalette.nativeDark.style == .native)
        #expect(ThemePalette.glassLight.style == .glass)
        #expect(ThemePalette.paper.style == .solid)
    }

    @Test func typographySettingsPersist() throws {
        var settings = AppSettings()
        settings.font = .rounded
        settings.textSize = .large
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.font == .rounded)
        #expect(decoded.textSize == .large)
        let unknown = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"font":"comic"}"#.utf8))
        #expect(unknown.font == .system)
    }

    @Test func atelierDarkMatchesReferenceTokens() {
        let p = ThemePalette.atelierDark
        #expect(p.background == 0x191817)
        #expect(p.surface == 0x252321)
        #expect(p.accent == 0xD77D60)
        #expect(p.text == 0xF0E8DE)
    }
}
