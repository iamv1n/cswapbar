import Foundation
import Testing
@testable import CSwapBarCore

@Suite("Parsing CSwap JSON")
struct CSwapParsingTests {
    private func listSnapshot() throws -> AccountSnapshot {
        let result = ProcessResult(exitCode: 0, stdout: Fixtures.data(Fixtures.list), stderr: Data())
        let dto = try CSwapCLIClient.decode(CSwapListDTO.self, from: result)
        return AccountMapper.snapshot(from: dto, capturedAt: Date(timeIntervalSince1970: 0))
    }

    @Test func accountsAreSortedBySlotAndUnknownFieldsIgnored() throws {
        let snapshot = try listSnapshot()
        #expect(snapshot.accounts.map(\.slot) == [1, 2, 3, 4])
    }

    @Test func activeAccountIsIdentified() throws {
        let active = try #require(try listSnapshot().activeAccount)
        #expect(active.slot == 2)
        #expect(active.alias == "work")
        #expect(active.displayName == "work")
        #expect(active.organizationName == "Example Corp")
        #expect(active.isOrganization)
        #expect(active.plan?.label == "Max 20x")
    }

    @Test func usageWindowsAndResetDatesAreParsed() throws {
        let active = try #require(try listSnapshot().activeAccount)
        let usage = try #require(active.usage)
        #expect(usage.fiveHour?.percent == 38)
        #expect(usage.sevenDay?.percent == 24)
        #expect(usage.scoped.first?.name == "Fable")
        #expect(usage.isLastKnown == false)

        // "2026-11-23T19:00:00.611925+00:00"
        let reset = try #require(usage.fiveHour?.resetsAt)
        #expect(abs(reset.timeIntervalSince1970 - 1_795_460_400.611925) < 0.01)
        #expect(usage.fetchedAt != nil)
    }

    @Test func lastGoodUsageIsUsedWhenUsageIsNull() throws {
        let stale = try #require(try listSnapshot().accounts.first { $0.slot == 3 })
        let usage = try #require(stale.usage)
        #expect(usage.isLastKnown)
        #expect(usage.fiveHour?.percent == nil)       // "pct": null
        #expect(usage.sevenDay?.percent == 12)
        #expect(usage.sevenDay?.resetsAt == nil)      // malformed date doesn't fail the payload
        #expect(stale.isDisabled)
        #expect(stale.usageError == "http-429")
    }

    @Test func availabilityFollowsStatusRules() throws {
        let bySlot = Dictionary(uniqueKeysWithValues: try listSnapshot().accounts.map { ($0.slot, $0) })
        #expect(bySlot[2]?.availability == .available)
        #expect(bySlot[1]?.availability == .rateLimited)  // 5h at 100%
        #expect(bySlot[3]?.availability == .unknown)      // only last-known data
        #expect(bySlot[4]?.availability == .expired)      // relogin_required
    }

    @Test func emptyAliasFallsBackToEmail() throws {
        let personal = try #require(try listSnapshot().accounts.first { $0.slot == 1 })
        #expect(personal.alias == nil)
        #expect(personal.displayName == "personal@example.com")
        #expect(personal.organizationName == nil)
    }

    @Test func errorEnvelopeBecomesCLIError() {
        let result = ProcessResult(exitCode: 1, stdout: Fixtures.data(Fixtures.errorEnvelope), stderr: Data())
        #expect(throws: CSwapError.cliError(type: "AccountNotFoundError", message: "No account matches 9")) {
            try CSwapCLIClient.decode(CSwapSwitchDTO.self, from: result)
        }
    }

    @Test func unknownSchemaVersionIsRejected() {
        let result = ProcessResult(exitCode: 0, stdout: Fixtures.data(Fixtures.futureSchema), stderr: Data())
        #expect(throws: CSwapError.unsupportedSchema(2)) {
            try CSwapCLIClient.decode(CSwapListDTO.self, from: result)
        }
    }

    @Test func nonJSONFailureUsesStderr() {
        let result = ProcessResult(exitCode: 2, stdout: Data(), stderr: Data("usage: cswap …\n".utf8))
        #expect(throws: CSwapError.commandFailed(exitCode: 2, message: "usage: cswap …")) {
            try CSwapCLIClient.decode(CSwapListDTO.self, from: result)
        }
    }

    @Test func garbageOutputIsInvalid() {
        let result = ProcessResult(exitCode: 0, stdout: Data("hello".utf8), stderr: Data())
        #expect(throws: CSwapError.self) {
            try CSwapCLIClient.decode(CSwapListDTO.self, from: result)
        }
    }

    @Test(arguments: [
        ("2026-11-23T19:00:00.611925+00:00", 1_795_460_400.611925),
        ("2026-12-11T15:36:16Z", 1_797_003_376.0),
        ("2026-11-23T19:00:00.5Z", 1_795_460_400.5),
        ("2026-11-23T19:00:00+00:00", 1_795_460_400.0),
    ])
    func isoDatesParse(input: String, expected: Double) throws {
        let date = try #require(CSwapDate.parse(input))
        #expect(abs(date.timeIntervalSince1970 - expected) < 0.01)
    }

    @Test func invalidDatesReturnNil() {
        #expect(CSwapDate.parse("not-a-date") == nil)
        #expect(CSwapDate.parse("") == nil)
        #expect(CSwapDate.parse(nil) == nil)
    }
}
