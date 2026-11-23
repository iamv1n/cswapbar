import CSwapBarCore
import Foundation

/// Fake accounts for previews, screenshots, and `--render-popover`. Never real data.
enum SampleData {
    private static let profiles: [(email: String, alias: String?, org: String?, plan: String, five: Double?, seven: Double?)] = [
        ("you@example.com", "Personal", nil, "Pro", 42, 64),
        ("work@example.com", "Work", "Example Corp", "Max 20x", 88, 97),
        ("side@example.com", nil, nil, "Max 5x", 12, 31),
        ("team@example.com", "Team", "Acme Studio", "Team", 100, 72),
        ("lab@example.com", "Lab", nil, "Pro", 5, 9),
        ("old@example.com", nil, nil, "Pro", nil, nil),
        ("ops@example.com", "Ops", "Example Corp", "Max 5x", 61, 45),
        ("alt@example.com", "Alt", nil, "Pro", 77, 83),
        ("qa@example.com", nil, nil, "Pro", 23, 18),
    ]

    static func accounts(count: Int, activeSlot: Int = 1, now: Date = Date()) -> [Account] {
        (0..<min(count, profiles.count)).map { index in
            let p = profiles[index]
            let slot = index + 1
            let usage: Usage? = p.five == nil ? nil : Usage(
                fiveHour: UsageWindow(percent: p.five, resetsAt: now.addingTimeInterval(Double(3_000 + index * 2_400))),
                sevenDay: UsageWindow(percent: p.seven, resetsAt: now.addingTimeInterval(Double(90_000 + index * 40_000))),
                fetchedAt: now
            )
            return Account(
                id: AccountID(email: p.email, organizationUUID: p.org == nil ? "" : "sample-org-\(index)"),
                slot: slot, email: p.email, alias: p.alias, organizationName: p.org,
                isOrganization: p.org != nil, isActive: slot == activeSlot, isDisabled: false,
                plan: SubscriptionPlan(label: p.plan, tier: nil, subscriptionStatus: nil, isExpired: false),
                usage: usage, usageStatus: p.five == nil ? .unavailable : .ok,
                usageError: p.five == nil ? "timeout" : nil, loginExpiresAt: nil
            )
        }
    }
}

/// In-memory CSwap returning sample accounts. Switching is a no-op success.
struct SampleCSwapClient: CSwapClient {
    let count: Int

    func detect() async throws -> CSwapInstallation {
        CSwapInstallation(executable: URL(fileURLWithPath: "/usr/local/bin/cswap"), version: CSwapVersion(major: 1, minor: 1, patch: 0))
    }

    func listAccounts() async throws -> AccountSnapshot {
        AccountSnapshot(accounts: SampleData.accounts(count: count), capturedAt: Date())
    }

    func status() async throws -> ActiveAccountStatus {
        let active = SampleData.accounts(count: count).first(where: \.isActive)
        return ActiveAccountStatus(id: active?.id, slot: active?.slot, isManaged: true)
    }

    func switchTo(slot: Int) async throws -> SwitchResponse {
        SwitchResponse(switched: true, reason: "switched", message: nil, warnings: [])
    }
}
