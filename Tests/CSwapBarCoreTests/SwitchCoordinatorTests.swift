import Foundation
import Testing
@testable import CSwapBarCore

/// In-memory CSwap that records calls.
final class FakeCSwapClient: CSwapClient, @unchecked Sendable {
    private let lock = NSLock()
    private var _activeSlot: Int
    private var _switchCalls: [Int] = []
    let accounts: [(slot: Int, email: String)]
    /// When false, `switchTo` claims success but doesn't change the active account.
    var switchTakesEffect = true
    var switchError: CSwapError?
    var switchDelay: Duration = .zero

    init(accounts: [(slot: Int, email: String)], activeSlot: Int) {
        self.accounts = accounts
        self._activeSlot = activeSlot
    }

    var switchCalls: [Int] { lock.withLock { _switchCalls } }
    private var activeSlot: Int { lock.withLock { _activeSlot } }

    static func id(_ email: String) -> AccountID { AccountID(email: email, organizationUUID: "") }

    func detect() async throws -> CSwapInstallation {
        CSwapInstallation(executable: URL(fileURLWithPath: "/fake/cswap"), version: .minimumSupported)
    }

    func listAccounts() async throws -> AccountSnapshot {
        let active = activeSlot
        let rows = accounts.map { row in
            Account(
                id: Self.id(row.email), slot: row.slot, email: row.email, alias: nil,
                organizationName: nil, isOrganization: false, isActive: row.slot == active,
                isDisabled: false, plan: nil, usage: nil, usageStatus: .ok,
                usageError: nil, loginExpiresAt: nil
            )
        }
        return AccountSnapshot(accounts: rows, capturedAt: Date())
    }

    func status() async throws -> ActiveAccountStatus {
        let active = activeSlot
        let email = accounts.first { $0.slot == active }?.email ?? ""
        return ActiveAccountStatus(id: Self.id(email), slot: active, isManaged: true)
    }

    func switchTo(slot: Int) async throws -> SwitchResponse {
        lock.withLock { _switchCalls.append(slot) }
        if switchDelay != .zero { try await Task.sleep(for: switchDelay) }
        if let switchError { throw switchError }
        if switchTakesEffect { lock.withLock { _activeSlot = slot } }
        return SwitchResponse(switched: true, reason: "switched", message: nil, warnings: [])
    }
}

@Suite("Switching")
struct SwitchCoordinatorTests {
    private func makeClient() -> FakeCSwapClient {
        FakeCSwapClient(accounts: [(1, "a@example.com"), (2, "b@example.com")], activeSlot: 1)
    }

    @Test func switchesAndVerifies() async {
        let client = makeClient()
        let outcome = await SwitchCoordinator(client: client).switchTo(FakeCSwapClient.id("b@example.com"))
        #expect(outcome == .switched)
        #expect(client.switchCalls == [2])
    }

    @Test func alreadyActiveDoesNotCallSwitch() async {
        let client = makeClient()
        let outcome = await SwitchCoordinator(client: client).switchTo(FakeCSwapClient.id("a@example.com"))
        #expect(outcome == .alreadyActive)
        #expect(client.switchCalls.isEmpty)
    }

    @Test func unknownAccountFails() async {
        let outcome = await SwitchCoordinator(client: makeClient()).switchTo(FakeCSwapClient.id("nobody@example.com"))
        #expect(outcome == .failed(.accountNotFound))
    }

    @Test func reportsFailureWhenStatusDisagrees() async {
        let client = makeClient()
        client.switchTakesEffect = false
        let outcome = await SwitchCoordinator(client: client).switchTo(FakeCSwapClient.id("b@example.com"))
        #expect(outcome == .failed(.verificationFailed))
    }

    @Test func mapsCSwapErrors() async {
        let client = makeClient()
        client.switchError = .timedOut
        let outcome = await SwitchCoordinator(client: client).switchTo(FakeCSwapClient.id("b@example.com"))
        #expect(outcome == .failed(.timedOut))
    }

    @Test func concurrentSwitchIsRejected() async {
        let client = makeClient()
        client.switchDelay = .milliseconds(200)
        let coordinator = SwitchCoordinator(client: client)
        let target = FakeCSwapClient.id("b@example.com")

        async let first = coordinator.switchTo(target)
        try? await Task.sleep(for: .milliseconds(50))
        let second = await coordinator.switchTo(target)

        #expect(second == .failed(.busy))
        #expect(await first == .switched)
        #expect(client.switchCalls == [2])
    }
}
