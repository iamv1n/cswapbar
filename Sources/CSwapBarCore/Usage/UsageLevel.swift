import Foundation

/// Color band for a usage percentage.
public enum UsageLevel: Sendable, Equatable {
    case healthy
    case warning
    case high
    case critical
    case unknown
}

public struct UsageThresholds: Sendable, Equatable, Codable {
    public var warning: Double
    public var high: Double
    public var critical: Double

    public static let `default` = UsageThresholds(warning: 60, high: 80, critical: 95)

    public init(warning: Double, high: Double, critical: Double) {
        self.warning = warning
        self.high = high
        self.critical = critical
    }

    public func level(for percent: Double?) -> UsageLevel {
        guard let percent else { return .unknown }
        switch percent {
        case critical...: return .critical
        case high...: return .high
        case warning...: return .warning
        default: return .healthy
        }
    }
}
