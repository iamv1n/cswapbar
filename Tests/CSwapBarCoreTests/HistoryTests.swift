import Foundation
import Testing
@testable import CSwapBarCore

private func acct(_ name: String, slot: Int, five: Double?, seven: Double?, active: Bool = false,
                  status: UsageStatus = .ok, disabled: Bool = false, lastKnown: Bool = false) -> Account {
    let email = "\(name)@example.com"
    return Account(
        id: AccountID(email: email, organizationUUID: ""), slot: slot, email: email, alias: name,
        organizationName: nil, isOrganization: false, isActive: active, isDisabled: disabled, plan: nil,
        usage: Usage(fiveHour: UsageWindow(percent: five, resetsAt: nil), sevenDay: UsageWindow(percent: seven, resetsAt: nil),
                     fetchedAt: Date(), isLastKnown: lastKnown),
        usageStatus: status, usageError: nil, loginExpiresAt: nil)
}

@Suite("Usage history")
struct HistoryTests {
    let hasher = AccountHasher(salt: "test-salt")

    @Test func hashesAreStableSaltedAndOpaque() {
        let id = AccountID(email: "you@example.com", organizationUUID: "")
        let key = hasher.key(for: id)
        #expect(key.count == 20)
        #expect(key == hasher.key(for: AccountID(email: "YOU@example.com", organizationUUID: "")))
        #expect(key != AccountHasher(salt: "other").key(for: id))
        #expect(!key.contains("example"))
        #expect(AccountHasher.makeSalt() != AccountHasher.makeSalt())
    }

    @Test func storeRoundTripsPrunesAndClears() throws {
        let store = try HistoryStore(path: ":memory:")
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let old = now.addingTimeInterval(-31 * 86_400)
        try store.record([
            UsageSample(date: old, account: "a", fiveHour: 10, sevenDay: 20),
            UsageSample(date: now, account: "a", fiveHour: 55.5, sevenDay: nil),
            UsageSample(date: now, account: "b", fiveHour: nil, sevenDay: 70),
        ])
        try store.record(SwitchRecord(date: now, from: "a", to: "b", source: .auto))
        try store.record(SwitchRecord(date: old, from: nil, to: "a", source: .cswapbar))

        let recent = try store.samples(since: now.addingTimeInterval(-60))
        #expect(recent.count == 2)
        #expect(recent.first { $0.account == "a" } == UsageSample(date: now, account: "a", fiveHour: 55.5, sevenDay: nil))
        #expect(try store.switches(since: old) == [
            SwitchRecord(date: old, from: nil, to: "a", source: .cswapbar),
            SwitchRecord(date: now, from: "a", to: "b", source: .auto),
        ])

        try store.prune(before: now.addingTimeInterval(-HistoryStore.retention))
        #expect(try store.counts() == (2, 1))
        try store.clear()
        #expect(try store.counts() == (0, 0))
    }

    @Test func storePersistsOnDisk() throws {
        let path = FileManager.default.temporaryDirectory.appendingPathComponent("cswapbar-\(UUID().uuidString)/h.sqlite").path
        defer { try? FileManager.default.removeItem(atPath: (path as NSString).deletingLastPathComponent) }
        try HistoryStore(path: path).record([UsageSample(date: Date(), account: "x", fiveHour: 1, sevenDay: 2)])
        #expect(try HistoryStore(path: path).counts().samples == 1)
    }

    @Test func samplerThrottlesButCatchesBigMoves() {
        var sampler = HistorySampler()
        let t0 = Date(timeIntervalSince1970: 1_800_000_000)
        func snap(_ t: TimeInterval, _ five: Double) -> AccountSnapshot {
            AccountSnapshot(accounts: [acct("w", slot: 1, five: five, seven: 30, active: true)], capturedAt: t0.addingTimeInterval(t))
        }
        #expect(sampler.samples(from: snap(0, 10), hasher: hasher).count == 1)
        #expect(sampler.samples(from: snap(60, 12), hasher: hasher).isEmpty)       // too soon, small move
        #expect(sampler.samples(from: snap(120, 25), hasher: hasher).count == 1)   // big move
        #expect(sampler.samples(from: snap(200, 26), hasher: hasher).isEmpty)
        #expect(sampler.samples(from: snap(120 + 300, 26), hasher: hasher).count == 1)  // interval passed

        let stale = AccountSnapshot(accounts: [acct("w", slot: 1, five: 99, seven: 99, lastKnown: true)], capturedAt: t0.addingTimeInterval(9_999))
        #expect(sampler.samples(from: stale, hasher: hasher).isEmpty)
    }

    @Test func csvIsOrderedEscapedAndSafe() {
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        let csv = HistoryCSV.make(
            samples: [UsageSample(date: t.addingTimeInterval(60), account: "k1", fiveHour: 42, sevenDay: 61.25)],
            switches: [SwitchRecord(date: t, from: "k2", to: "k1", source: .external)],
            name: { ["k1": "Work, \"main\"", "k2": "=HYPERLINK()"][$0] ?? $0 })
        let lines = csv.split(separator: "\n").map(String.init)
        #expect(lines[0] == "type,timestamp,account,five_hour_pct,seven_day_pct,from_account,source")
        #expect(lines[1].hasPrefix("switch,"))
        #expect(lines[1].hasSuffix(",'=HYPERLINK(),external"))
        #expect(lines[2].contains(",\"Work, \"\"main\"\"\",42,61.2,") || lines[2].contains(",\"Work, \"\"main\"\"\",42,61.3,"))
    }
}

@Suite("Recommendations and cswap auto")
struct RecommendationTests {
    @Test func picksMostHeadroomLikeCSwapBest() throws {
        // Mirrors a real `cswap auto` poll: headroom 1:94, 2:48, 3:61, 4:39 (active).
        let accounts = [
            acct("one", slot: 1, five: 0, seven: 6),
            acct("two", slot: 2, five: 52, seven: 43),
            acct("three", slot: 3, five: 1, seven: 39),
            acct("four", slot: 4, five: 8, seven: 61, active: true),
        ]
        let best = try #require(AccountRecommendation.best(in: accounts))
        #expect(best.account.alias == "one")
        #expect(best.headroom == 94)
        #expect(best.activeHeadroom == 39)
        #expect(best.explanation(preferences: PrivacyPreferences()) == "one has the most headroom: 94% left (you have 39%).")
        #expect(best.isWorthShowing(thresholds: .default))   // active is at 61%, past yellow
    }

    @Test func skipsUnusableAndRespectsPrivacy() throws {
        let accounts = [
            acct("active", slot: 1, five: 92, seven: 50, active: true),
            acct("disabled", slot: 2, five: 0, seven: 0, disabled: true),
            acct("expired", slot: 3, five: 0, seven: 0, status: .reloginRequired),
            acct("limited", slot: 4, five: 100, seven: 10),
            acct("stale", slot: 5, five: 0, seven: 0, lastKnown: true),
            acct("ok", slot: 6, five: 30, seven: 20),
        ]
        let best = try #require(AccountRecommendation.best(in: accounts))
        #expect(best.account.alias == "ok")
        var privacy = PrivacyPreferences()
        privacy.privacyModeEnabled = true
        privacy.hideUsagePercentages = true
        let text = best.explanation(preferences: privacy)
        #expect(!text.contains("ok@") && !text.contains("%"))
    }

    @Test func noRecommendationWhenActiveIsBest() {
        let accounts = [acct("a", slot: 1, five: 5, seven: 5, active: true), acct("b", slot: 2, five: 20, seven: 10)]
        #expect(AccountRecommendation.best(in: accounts) == nil)
        let calm = AccountRecommendation(account: accounts[1], headroom: 80, activeHeadroom: 70)
        #expect(!calm.isWorthShowing(thresholds: .default))
    }

    @Test func parsesRealAutoEvents() throws {
        let poll = try #require(CSwapAutoEvent(line: #"{"schemaVersion": 1, "event": "poll", "ts": "2026-11-24T21:38:31Z", "active": {"number": 4, "email": "x@example.com"}, "headroomPct": {"1": 94.0}}"#))
        #expect(poll.kind == .poll && poll.activeSlot == 4 && poll.date != nil && !poll.changesAccounts)
        let none = try #require(CSwapAutoEvent(line: #"{"schemaVersion": 1, "event": "no-switch", "reason": "below-threshold", "detail": "7d 61% < 90%"}"#))
        #expect(none.kind == .noSwitch && none.reason == "below-threshold")
        let switched = try #require(CSwapAutoEvent(line: #"{"schemaVersion": 1, "event": "switched", "to": {"number": 2}}"#))
        #expect(switched.changesAccounts && switched.activeSlot == 2)
        #expect(CSwapAutoEvent(line: #"{"schemaVersion": 1, "event": "auto-switched"}"#)?.kind == .switched)
        #expect(CSwapAutoEvent(line: #"{"schemaVersion": 1, "event": "no-target"}"#)?.kind == .blocked)
        #expect(CSwapAutoEvent(line: "Switching soon…") == nil)
        #expect(CSwapAutoEvent(line: #"{"schemaVersion": 2, "event": "poll"}"#) == nil)
    }

    @Test func autoArgumentsAndDefaults() throws {
        var prefs = AutoSwitchPreferences()
        #expect(!prefs.enabled)
        prefs.threshold = 85
        prefs.strategy = .weeklyFirst
        #expect(prefs.arguments() == ["auto", "--json", "--threshold", "85", "--strategy", "weekly-first"])
        #expect(prefs.arguments(dryRun: true).last == "--dry-run")
        let clamped = try JSONDecoder().decode(AutoSwitchPreferences.self, from: Data(#"{"enabled":true,"threshold":20,"strategy":"nope"}"#.utf8))
        #expect(clamped.enabled && clamped.threshold == 50 && clamped.strategy == .best)
    }
}

@Suite("Usage Island")
struct UsageIslandTests {
    @Test func islandReplacesTheMenuBarIcon() {
        var prefs = UsageIslandPreferences()
        #expect(!prefs.enabled && prefs.showsMenuBarIcon)
        prefs.enabled = true
        #expect(!prefs.showsMenuBarIcon)
        #expect(!AppSettings().usageIsland.enabled)
        // An old setting from the earlier build is ignored, not fatal.
        let old = try? JSONDecoder().decode(UsageIslandPreferences.self, from: Data(#"{"enabled":true,"onlyWhenBusy":true}"#.utf8))
        #expect(old?.enabled == true)
    }

    @Test func hugsTheNotchWhenThereIsOne() {
        let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
        let g = IslandGeometry(screen: screen, menuBarHeight: 38, notchWidth: 200)
        #expect(g.hugsNotch)
        #expect(g.collapsed == CGRect(x: 756 - 174, y: 944, width: 348, height: 38))
        #expect(g.collapsed.maxY == screen.maxY)
        #expect(g.expanded.maxY == screen.maxY)
        #expect(g.expanded.midX == screen.midX)
        #expect(g.expanded.width >= g.collapsed.width)

        // The "Floating bar" style ignores the notch.
        let bar = IslandGeometry(screen: screen, menuBarHeight: 38, notchWidth: 200, style: .bar)
        #expect(!bar.hugsNotch)
        #expect(bar.collapsed.maxY == screen.maxY - 38 - 6)
    }

    @Test func styleDecodesLeniently() throws {
        let decoded = try JSONDecoder().decode(UsageIslandPreferences.self, from: Data(#"{"enabled":true,"style":"bubble"}"#.utf8))
        #expect(decoded.enabled && decoded.style == .notch)
        let bar = try JSONDecoder().decode(UsageIslandPreferences.self, from: Data(#"{"style":"bar"}"#.utf8))
        #expect(bar.style == .bar && !bar.enabled)
    }

    @Test func floatsBelowTheMenuBarWithoutANotch() {
        let screen = CGRect(x: 1512, y: 0, width: 2560, height: 1440)   // external display to the right
        let g = IslandGeometry(screen: screen, menuBarHeight: 24, notchWidth: nil)
        #expect(!g.hugsNotch)
        #expect(g.collapsed.midX == screen.midX)
        let belowMenuBar: CGFloat = 1440 - 24 - 6
        #expect(g.collapsed.maxY == belowMenuBar)
        #expect(g.expanded.maxY == g.collapsed.maxY)
        #expect(g.collapsed.size == IslandGeometry.pillSize)
    }
}
