import Foundation
import Testing
@testable import CSwapBarCore

private func account(
    _ name: String,
    fiveHour: Double? = 10,
    sevenDay: Double? = 10,
    active: Bool = false,
    status: UsageStatus = .ok,
    lastKnown: Bool = false,
    resetsIn: TimeInterval = 2 * 3600 + 35 * 60
) -> Account {
    let email = "\(name)@example.com"
    return Account(
        id: AccountID(email: email, organizationUUID: ""),
        slot: 1, email: email, alias: name, organizationName: nil,
        isOrganization: false, isActive: active, isDisabled: false, plan: nil,
        usage: Usage(
            fiveHour: UsageWindow(percent: fiveHour, resetsAt: Date(timeIntervalSinceNow: resetsIn)),
            sevenDay: UsageWindow(percent: sevenDay, resetsAt: Date(timeIntervalSinceNow: 5 * 86_400)),
            fetchedAt: Date(), isLastKnown: lastKnown),
        usageStatus: status, usageError: nil, loginExpiresAt: nil)
}

private func snap(_ accounts: Account...) -> AccountSnapshot {
    AccountSnapshot(accounts: accounts, capturedAt: Date())
}

@Suite("Notification planner")
struct NotificationPlannerTests {
    let prefs = NotificationPreferences()
    let privacy = PrivacyPreferences()

    @Test func firstSnapshotIsSilent() {
        var planner = NotificationPlanner()
        let out = planner.process(snap(account("work", fiveHour: 97, active: true), account("side", status: .reloginRequired)),
                                  preferences: prefs, privacy: privacy)
        #expect(out.isEmpty)
    }

    @Test func crossingALevelFiresOnce() {
        var planner = NotificationPlanner()
        _ = planner.process(snap(account("work", fiveHour: 70, active: true)), preferences: prefs, privacy: privacy)
        let first = planner.process(snap(account("work", fiveHour: 82, active: true)), preferences: prefs, privacy: privacy)
        #expect(first == [PlannedNotification(kind: .usage, title: "Usage threshold reached", body: "work has reached 82% 5-hour usage.")])
        let again = planner.process(snap(account("work", fiveHour: 84, active: true)), preferences: prefs, privacy: privacy)
        #expect(again.isEmpty)
    }

    @Test func jumpingSeveralLevelsSendsOnlyTheHighest() {
        var planner = NotificationPlanner()
        _ = planner.process(snap(account("work", sevenDay: 50, active: true)), preferences: prefs, privacy: privacy)
        let out = planner.process(snap(account("work", sevenDay: 96, active: true)), preferences: prefs, privacy: privacy)
        #expect(out.count == 1)
        #expect(out.first?.body == "work has reached 96% weekly usage.")
        // 80 was passed on the way, so it doesn't fire later either.
        #expect(planner.process(snap(account("work", sevenDay: 96, active: true)), preferences: prefs, privacy: privacy).isEmpty)
    }

    @Test func limitAlertIncludesResetTime() {
        var planner = NotificationPlanner()
        _ = planner.process(snap(account("work", fiveHour: 96, active: true)), preferences: prefs, privacy: privacy)
        let out = planner.process(snap(account("work", fiveHour: 100, active: true)), preferences: prefs, privacy: privacy)
        #expect(out.first?.title == "Usage limit reached")
        #expect(out.first?.body.hasPrefix("work has hit its 5-hour limit. Resets in 2h 3") == true)
    }

    @Test func levelReArmsAfterUsageDrops() {
        var planner = NotificationPlanner()
        _ = planner.process(snap(account("work", fiveHour: 70, active: true)), preferences: prefs, privacy: privacy)
        #expect(planner.process(snap(account("work", fiveHour: 81, active: true)), preferences: prefs, privacy: privacy).count == 1)
        // A small dip inside the margin doesn't re-arm.
        _ = planner.process(snap(account("work", fiveHour: 77, active: true)), preferences: prefs, privacy: privacy)
        #expect(planner.process(snap(account("work", fiveHour: 81, active: true)), preferences: prefs, privacy: privacy).isEmpty)
        // The window resets, then usage climbs again.
        _ = planner.process(snap(account("work", fiveHour: 3, active: true)), preferences: prefs, privacy: privacy)
        #expect(planner.process(snap(account("work", fiveHour: 80, active: true)), preferences: prefs, privacy: privacy).count == 1)
    }

    @Test func disabledLevelsAndSwitchesAreRespected() {
        var only100 = prefs
        only100.setLevel(80, enabled: false)
        only100.setLevel(95, enabled: false)
        var planner = NotificationPlanner()
        _ = planner.process(snap(account("work", fiveHour: 50, active: true)), preferences: only100, privacy: privacy)
        #expect(planner.process(snap(account("work", fiveHour: 96, active: true)), preferences: only100, privacy: privacy).isEmpty)
        #expect(planner.process(snap(account("work", fiveHour: 100, active: true)), preferences: only100, privacy: privacy).count == 1)

        var off = prefs
        off.enabled = false
        var quiet = NotificationPlanner()
        _ = quiet.process(snap(account("work", fiveHour: 50, active: true), account("side")), preferences: off, privacy: privacy)
        #expect(quiet.process(snap(account("work", fiveHour: 99), account("side", active: true)), preferences: off, privacy: privacy).isEmpty)
    }

    @Test func staleReadingsAreIgnored() {
        var planner = NotificationPlanner()
        _ = planner.process(snap(account("work", fiveHour: 50, active: true)), preferences: prefs, privacy: privacy)
        #expect(planner.process(snap(account("work", fiveHour: 99, active: true, lastKnown: true)), preferences: prefs, privacy: privacy).isEmpty)
    }

    @Test func externalSwitchIsAnnouncedButInAppSwitchIsNot() {
        var planner = NotificationPlanner()
        _ = planner.process(snap(account("work", active: true), account("side")), preferences: prefs, privacy: privacy)
        let external = planner.process(snap(account("work"), account("side", active: true)), preferences: prefs, privacy: privacy)
        #expect(external == [PlannedNotification(kind: .switched, title: "Account switched", body: "Claude Code is now using side.")])

        let side = account("side")
        let inApp = planner.process(snap(account("work", active: true), side), preferences: prefs, privacy: privacy,
                                    inAppSwitchTarget: account("work").id)
        #expect(inApp.isEmpty)
    }

    @Test func newLoginProblemIsAnnouncedOnce() {
        var planner = NotificationPlanner()
        _ = planner.process(snap(account("work", active: true), account("side")), preferences: prefs, privacy: privacy)
        let out = planner.process(snap(account("work", active: true), account("side", status: .reloginRequired)), preferences: prefs, privacy: privacy)
        #expect(out == [PlannedNotification(kind: .needsLogin, title: "Login needed", body: "side needs a new login before CSwap can use it.")])
        #expect(planner.process(snap(account("work", active: true), account("side", status: .reloginRequired)), preferences: prefs, privacy: privacy).isEmpty)
    }

    @Test func newAccountsStartSilent() {
        var planner = NotificationPlanner()
        _ = planner.process(snap(account("work", active: true)), preferences: prefs, privacy: privacy)
        let out = planner.process(snap(account("work", active: true), account("new", fiveHour: 99, status: .reloginRequired)),
                                  preferences: prefs, privacy: privacy)
        #expect(out.isEmpty)
    }

    @Test func privacyModeMasksEveryNotification() {
        var masked = PrivacyPreferences()
        masked.privacyModeEnabled = true
        var planner = NotificationPlanner()
        _ = planner.process(snap(account("work", fiveHour: 50, active: true), account("side")), preferences: prefs, privacy: masked)
        var out = planner.process(snap(account("work", fiveHour: 100), account("side", active: true, status: .reloginRequired)),
                                  preferences: prefs, privacy: masked)
        if let failed = planner.switchFailed(to: account("work"), preferences: prefs, privacy: masked) { out.append(failed) }
        #expect(out.count == 4)
        for n in out {
            #expect(!n.body.contains("work") && !n.body.contains("side") && !n.body.contains("example.com"))
        }
    }

    @Test func hiddenResetTimesStayHidden() {
        var hide = PrivacyPreferences()
        hide.hideResetTimestamps = true
        let text = NotificationText.usageThreshold(account: account("work"), window: .fiveHour, percent: 100,
                                                   resetsAt: Date(timeIntervalSinceNow: 3600), preferences: hide)
        #expect(text.body == "work has hit its 5-hour limit.")
    }
}

@Suite("Key shortcuts and notification settings")
struct ShortcutAndNotificationSettingsTests {
    @Test func displayUsesMenuOrder() {
        let s = KeyShortcut(keyCode: 35, modifiers: [.command, .shift, .option, .control], keyLabel: "P")
        #expect(s.displayString == "⌃⌥⇧⌘P")
        #expect(KeyShortcut.defaultPrivacyToggle.displayString == "⌃⌥⌘P")
        #expect(KeyShortcut.defaultOpenPopover.displayString == "⌃⌥⌘C")
        #expect(KeyShortcut.defaultOpenPopover != KeyShortcut.defaultPrivacyToggle)
        #expect(AppSettings().openShortcutEnabled)
    }

    @Test func globalShortcutNeedsARealModifier() {
        #expect(!KeyShortcut(keyCode: 35, modifiers: [.shift], keyLabel: "P").isValidGlobalShortcut)
        #expect(!KeyShortcut(keyCode: 35, modifiers: [], keyLabel: "P").isValidGlobalShortcut)
        #expect(KeyShortcut(keyCode: 35, modifiers: [.option], keyLabel: "P").isValidGlobalShortcut)
    }

    @Test func labelsForSpecialKeys() {
        #expect(KeyShortcut.label(forKeyCode: 49, characters: " ") == "Space")
        #expect(KeyShortcut.label(forKeyCode: 122, characters: nil) == "F1")
        #expect(KeyShortcut.label(forKeyCode: 0, characters: "a") == "A")
    }

    @Test func settingsRoundTripAndRejectBadShortcut() throws {
        var settings = AppSettings()
        settings.notifications.setLevel(80, enabled: false)
        settings.notifications.playSound = true
        settings.privacyShortcut = KeyShortcut(keyCode: 0, modifiers: [.command, .option], keyLabel: "A")
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
        #expect(decoded.notifications.usageLevels == [95, 100])

        let bad = #"{"privacyShortcut":{"keyCode":0,"modifiers":4,"keyLabel":"A"},"notifications":{"usageLevels":[100,7,80]}}"#
        let lenient = try JSONDecoder().decode(AppSettings.self, from: Data(bad.utf8))
        #expect(lenient.privacyShortcut == .defaultPrivacyToggle)
        #expect(lenient.notifications.usageLevels == [80, 100])
        #expect(lenient.notifications.enabled)
    }
}
