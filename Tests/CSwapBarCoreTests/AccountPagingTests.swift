import Foundation
import Testing
@testable import CSwapBarCore

@Suite("Account paging")
struct AccountPagingTests {
    @Test func fourAccountsFitOnOnePage() {
        let paging = AccountPaging(pageSize: 4, totalCount: 4)
        #expect(paging.pageCount == 1)
        #expect(!paging.isPaged)
        #expect(paging.range(forPage: 0) == 0..<4)
    }

    @Test func nineAccountsMakeThreePages() {
        let paging = AccountPaging(pageSize: 4, totalCount: 9)
        #expect(paging.pageCount == 3)
        #expect(paging.range(forPage: 1) == 4..<8)
        #expect(paging.range(forPage: 2) == 8..<9)
        #expect(paging.label(forPage: 1) == "5–8 of 9")
        #expect(paging.label(forPage: 2) == "9 of 9")
    }

    @Test func pageIsClampedWhenAccountsShrink() {
        let paging = AccountPaging(pageSize: 4, totalCount: 3)
        #expect(paging.clamp(5) == 0)
        #expect(paging.clamp(-1) == 0)
        #expect(paging.range(forPage: 5) == 0..<3)
    }

    @Test func emptyListHasOneEmptyPage() {
        let paging = AccountPaging(pageSize: 4, totalCount: 0)
        #expect(paging.pageCount == 1)
        #expect(paging.range(forPage: 0).isEmpty)
    }

    @Test func activeAccountComesFirst() {
        func account(_ slot: Int, active: Bool) -> Account {
            Account(
                id: AccountID(email: "\(slot)@example.com", organizationUUID: ""), slot: slot,
                email: "\(slot)@example.com", alias: nil, organizationName: nil, isOrganization: false,
                isActive: active, isDisabled: false, plan: nil, usage: nil, usageStatus: .ok,
                usageError: nil, loginExpiresAt: nil
            )
        }
        let ordered = AccountPaging.ordered([account(3, active: false), account(5, active: true), account(1, active: false)])
        #expect(ordered.map(\.slot) == [5, 1, 3])
    }

    @Test func pageSizeSettingIsClamped() throws {
        let settings = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"accountsPerPage": 50}"#.utf8))
        #expect(settings.accountsPerPage == 8)
        #expect(AppSettings().accountsPerPage == 4)
    }

    @Test func cardLayoutPersistsAndSuggestsPageSize() throws {
        var settings = AppSettings()
        settings.cardLayout = .rings
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.cardLayout == .rings)
        #expect(AppSettings().cardLayout == .meters)
        #expect(CardLayout.list.suggestedPageSize == 8)
        #expect(CardLayout.allCases.allSatisfy { AccountPaging.pageSizeOptions.contains($0.suggestedPageSize) })
        let unknown = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"cardLayout":"mosaic"}"#.utf8))
        #expect(unknown.cardLayout == .meters)
    }

    @Test func summaryCountsAvailability() throws {
        let result = ProcessResult(exitCode: 0, stdout: Fixtures.data(Fixtures.list), stderr: Data())
        let dto = try CSwapCLIClient.decode(CSwapListDTO.self, from: result)
        let summary = AccountSummary(AccountMapper.snapshot(from: dto, capturedAt: Date()).accounts)
        #expect(summary.total == 4)
        #expect(summary.ready == 1)          // slot 2
        #expect(summary.limited == 1)        // slot 1 at 100%
        #expect(summary.needsAttention == 1) // slot 4 relogin_required
        #expect(summary.totalText == "4 accounts")
        #expect(AccountSummary([]).totalText == "0 accounts")
    }

    @Test func desktopWidgetSettingsPersist() throws {
        var settings = AppSettings()
        #expect(settings.desktopWidgets.isEmpty)
        settings.desktopWidgets = [.gauge, .accounts]
        settings.widgetsFloatOnTop = true
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded.desktopWidgets == [.gauge, .accounts])
        #expect(decoded.widgetsFloatOnTop)
        let mixed = try JSONDecoder().decode(AppSettings.self, from: Data(#"{"desktopWidgets":["gauge","hologram","gauge","active"]}"#.utf8))
        #expect(mixed.desktopWidgets == [.gauge, .active])
    }
}
