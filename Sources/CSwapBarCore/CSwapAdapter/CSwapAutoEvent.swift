import Foundation

/// Settings for running CSwap's auto-switcher (`cswap auto --json`) from CSwapBar.
/// Off by default: when on, CSwap switches accounts by itself.
public struct AutoSwitchPreferences: Codable, Sendable, Equatable {
    public enum Strategy: String, CaseIterable, Codable, Sendable {
        case best
        case weeklyFirst = "weekly-first"
        case consumeFirst = "consume-first"
        case priorityConsumeFirst = "priority-consume-first"

        public var title: String {
            switch self {
            case .best: "Most quota left"
            case .weeklyFirst: "Weekly reset soonest"
            case .consumeFirst: "Use soonest-resetting first"
            case .priorityConsumeFirst: "Priority, then soonest reset"
            }
        }
    }

    public var enabled: Bool = false
    /// Switch when the active account's 5-hour window reaches this (CSwap allows 50–99.9).
    public var threshold: Double = 90
    public var strategy: Strategy = .best

    public init() {}

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = AutoSwitchPreferences()
        enabled = (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? d.enabled
        threshold = min(max((try? c.decodeIfPresent(Double.self, forKey: .threshold)) ?? d.threshold, 50), 99)
        strategy = (try? c.decodeIfPresent(Strategy.self, forKey: .strategy)) ?? d.strategy
    }

    /// Arguments after `cswap`. Never passed through a shell.
    public func arguments(dryRun: Bool = false) -> [String] {
        var args = ["auto", "--json", "--threshold", String(Int(threshold)), "--strategy", strategy.rawValue]
        if dryRun { args.append("--dry-run") }
        return args
    }
}

/// One line of `cswap auto --json` output.
public struct CSwapAutoEvent: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// Periodic reading (carries usage; nothing changed).
        case poll
        /// Checked, didn't need to switch.
        case noSwitch
        /// Switched accounts.
        case switched
        /// Wanted to switch but nothing was usable.
        case blocked
        case error
        case other(String)
    }

    public let kind: Kind
    public let date: Date?
    public let reason: String?
    public let detail: String?
    /// The active slot, when the event says.
    public let activeSlot: Int?

    /// Parses one line; nil for blank or non-JSON lines and other schema versions.
    public init?(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let name = object["event"] as? String else { return nil }
        if let schema = object["schemaVersion"] as? Int, schema != supportedCSwapSchemaVersion { return nil }

        kind = switch name {
        case "poll": .poll
        case "no-switch": .noSwitch
        case "switch", "switched": .switched
        case "blocked", "no-target", "exhausted": .blocked
        case "error": .error
        default: name.contains("switch") && !name.hasPrefix("no") ? .switched : .other(name)
        }
        date = (object["ts"] as? String).flatMap { ISO8601DateFormatter().date(from: $0) }
        reason = object["reason"] as? String
        detail = object["detail"] as? String
        activeSlot = ((object["to"] as? [String: Any])?["number"] as? Int)
            ?? ((object["active"] as? [String: Any])?["number"] as? Int)
    }

    /// Whether CSwapBar should refresh right away.
    public var changesAccounts: Bool { kind == .switched }
}
