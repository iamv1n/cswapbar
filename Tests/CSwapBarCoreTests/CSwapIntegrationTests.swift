import Foundation
import Testing
@testable import CSwapBarCore

/// Runs against the real CSwap install. Opt-in and strictly read-only:
/// these tests must never switch, add, or remove accounts.
///
///     CSWAPBAR_INTEGRATION=1 ./scripts/test.sh
@Suite(
    "CSwap integration (read-only)",
    .enabled(if: ProcessInfo.processInfo.environment["CSWAPBAR_INTEGRATION"] == "1")
)
struct CSwapIntegrationTests {
    let client = CSwapCLIClient()

    @Test func detectsSupportedVersion() async throws {
        let installation = try await client.detect()
        #expect(installation.version >= .minimumSupported)
    }

    @Test func listsAccounts() async throws {
        let snapshot = try await client.listAccounts()
        #expect(snapshot.accounts.filter(\.isActive).count <= 1)
    }

    @Test func statusMatchesListActiveAccount() async throws {
        let snapshot = try await client.listAccounts()
        let status = try await client.status()
        if let active = snapshot.activeAccount {
            #expect(status.id == active.id)
        }
    }
}
