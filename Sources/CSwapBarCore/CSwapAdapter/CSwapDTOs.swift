import Foundation

// Raw shapes of CSwap's `--json` output, schema v1.
//
// Source of truth: claude_swap/json_output.py and switcher.py in CSwap 1.1.0.
// The contract is additive, so every field except the envelope is optional and
// unknown fields are ignored. Dates stay as strings here; `AccountMapper`
// parses them so that one malformed timestamp can't fail the whole payload.

/// The CSwap schema version this build understands.
public let supportedCSwapSchemaVersion = 1

struct CSwapErrorDTO: Decodable, Equatable, Sendable {
    let type: String?
    let message: String?
}

/// Every payload has at least these two keys.
struct CSwapEnvelopeDTO: Decodable {
    let schemaVersion: Int?
    let error: CSwapErrorDTO?
}

/// `cswap list --json`
struct CSwapListDTO: Decodable {
    let schemaVersion: Int
    let activeAccountNumber: Int?
    let accounts: [CSwapAccountDTO]?
}

/// `cswap status --json`
struct CSwapStatusDTO: Decodable {
    let schemaVersion: Int
    let active: CSwapAccountDTO?
    let totalManagedAccounts: Int?
}

/// `cswap switch … --json`
struct CSwapSwitchDTO: Decodable {
    let schemaVersion: Int
    let switched: Bool?
    let from: CSwapAccountRefDTO?
    let to: CSwapAccountRefDTO?
    let strategy: String?
    let reason: String?
    let message: String?
    let warnings: [String]?
}

struct CSwapAccountRefDTO: Decodable, Equatable {
    let number: Int?
    let email: String?
}

/// One account row (`list`) or the active account (`status`).
struct CSwapAccountDTO: Decodable {
    let number: Int?
    let email: String
    let organizationName: String?
    let organizationUuid: String?
    let isOrganization: Bool?
    let active: Bool?
    /// `status` only: false when the live login isn't a CSwap-managed slot.
    let managed: Bool?
    let usageStatus: String?
    let usage: CSwapUsageDTO?
    let alias: String?
    let disabled: Bool?
    let threshold: Double?
    let loginExpiresAt: String?
    let plan: CSwapPlanDTO?
    let usageFetchedAt: String?
    let usageAgeSeconds: Double?
    let lastGoodUsage: CSwapUsageDTO?
    let lastGoodFetchedAt: String?
    let lastGoodAgeSeconds: Double?
    let usageError: String?
    let usageRetryAt: String?
}

struct CSwapUsageDTO: Decodable {
    let fiveHour: CSwapWindowDTO?
    let sevenDay: CSwapWindowDTO?
    let scoped: [CSwapWindowDTO]?
    let source: String?
}

struct CSwapWindowDTO: Decodable {
    /// May be `null`: the API reported the window without a figure.
    let pct: Double?
    let resetsAt: String?
    /// Scoped (per-model) windows only, e.g. "Fable".
    let name: String?
    let expectedPct: Double?
    let aheadOfPace: Bool?
    let willLastToReset: Bool?
}

struct CSwapPlanDTO: Decodable {
    let label: String?
    let tier: String?
    let organizationType: String?
    let billingType: String?
    let subscriptionStatus: String?
    let planDisplayName: String?
    let expired: Bool?
    let fetchedAt: String?
}
