import Foundation

/// Synthetic CSwap schema-v1 payloads. Shapes mirror CSwap 1.1.0's real output;
/// all identities are fake. Never paste real account data here.
enum Fixtures {
    static let list = """
    {
      "schemaVersion": 1,
      "activeAccountNumber": 2,
      "accounts": [
        {
          "number": 2,
          "email": "work@example.com",
          "organizationName": "Example Corp",
          "organizationUuid": "11111111-2222-3333-4444-555555555555",
          "isOrganization": true,
          "active": true,
          "usageStatus": "ok",
          "alias": "work",
          "loginExpiresAt": "2027-01-01T00:00:00Z",
          "plan": {
            "label": "Max 20x",
            "tier": "max_20x",
            "subscriptionStatus": "active",
            "expired": false,
            "fetchedAt": "2026-11-23T10:00:00Z"
          },
          "usage": {
            "fiveHour": { "pct": 38.0, "resetsAt": "2026-11-23T19:00:00.611925+00:00", "countdown": "3h 29m", "clock": "Nov 24 00:30" },
            "sevenDay": { "pct": 24.0, "resetsAt": "2026-11-24T23:00:00.611947+00:00", "expectedPct": 81.2, "aheadOfPace": false, "projectedExhaustionAt": "2026-12-11T15:36:16Z", "willLastToReset": true },
            "scoped": [ { "name": "Fable", "pct": 18.0, "resetsAt": "2026-11-24T22:59:59.612150+00:00" } ]
          },
          "usageFetchedAt": "2026-11-23T15:27:54Z",
          "usageAgeSeconds": 154.2,
          "someFutureField": { "nested": [1, 2, 3] }
        },
        {
          "number": 1,
          "email": "personal@example.com",
          "organizationName": "",
          "organizationUuid": "",
          "isOrganization": false,
          "active": false,
          "usageStatus": "ok",
          "usage": {
            "fiveHour": { "pct": 100.0, "resetsAt": "2026-11-23T17:00:00Z" },
            "sevenDay": { "pct": 61.0, "resetsAt": "2026-11-27T09:00:00Z" }
          },
          "usageFetchedAt": "2026-11-23T15:20:00Z"
        },
        {
          "number": 3,
          "email": "old@example.com",
          "organizationName": "",
          "organizationUuid": "",
          "isOrganization": false,
          "active": false,
          "usageStatus": "unavailable",
          "usage": null,
          "disabled": true,
          "lastGoodUsage": {
            "fiveHour": { "pct": null },
            "sevenDay": { "pct": 12.0, "resetsAt": "not-a-date" }
          },
          "lastGoodFetchedAt": "2026-11-22T08:00:00Z",
          "usageError": "http-429",
          "usageRetryAt": "2026-11-23T16:00:00Z"
        },
        {
          "number": 4,
          "email": "expired@example.com",
          "organizationName": "",
          "organizationUuid": "",
          "isOrganization": false,
          "active": false,
          "usageStatus": "relogin_required",
          "usage": null
        }
      ]
    }
    """

    static let statusManaged = """
    {
      "schemaVersion": 1,
      "active": {
        "number": 2,
        "email": "Work@Example.com",
        "organizationName": "Example Corp",
        "organizationUuid": "11111111-2222-3333-4444-555555555555",
        "isOrganization": true,
        "managed": true,
        "usageStatus": "ok",
        "usage": null
      },
      "totalManagedAccounts": 4
    }
    """

    static let statusNoLogin = #"{ "schemaVersion": 1, "active": null }"#

    static let statusUnmanaged = #"{ "schemaVersion": 1, "active": { "email": "someone@example.com", "managed": false } }"#

    static let switchSucceeded = """
    {
      "schemaVersion": 1,
      "switched": true,
      "from": { "number": 2, "email": "work@example.com" },
      "to": { "number": 1, "email": "personal@example.com" },
      "strategy": "explicit",
      "reason": "switched",
      "message": "Switched to Account-1 (personal@example.com)",
      "warnings": []
    }
    """

    static let errorEnvelope = """
    { "schemaVersion": 1, "error": { "type": "AccountNotFoundError", "message": "No account matches 9" } }
    """

    static let futureSchema = #"{ "schemaVersion": 2, "accounts": [] }"#

    static func data(_ string: String) -> Data { Data(string.utf8) }
}
