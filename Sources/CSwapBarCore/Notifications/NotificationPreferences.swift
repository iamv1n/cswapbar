import Foundation

/// Which notifications CSwapBar sends. The wording always follows the privacy settings.
public struct NotificationPreferences: Codable, Sendable, Equatable {
    /// Master switch.
    public var enabled: Bool = true
    /// Alert when a 5-hour or weekly window crosses one of `usageLevels`.
    public var usageAlerts: Bool = true
    /// Percentages that trigger a usage alert. A subset of `availableLevels`.
    public var usageLevels: [Int] = NotificationPreferences.availableLevels
    /// Alert when the active account changes outside CSwapBar (e.g. CSwap's
    /// auto-switch or the terminal), and when a switch made in CSwapBar fails.
    public var switchAlerts: Bool = true
    /// Alert when an account needs a new login.
    public var loginAlerts: Bool = true
    public var playSound: Bool = false

    public static let availableLevels = [80, 95, 100]

    public init() {}

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = NotificationPreferences()
        func flag(_ key: CodingKeys, _ fallback: Bool) -> Bool { (try? c.decodeIfPresent(Bool.self, forKey: key)) ?? fallback }
        enabled = flag(.enabled, d.enabled)
        usageAlerts = flag(.usageAlerts, d.usageAlerts)
        switchAlerts = flag(.switchAlerts, d.switchAlerts)
        loginAlerts = flag(.loginAlerts, d.loginAlerts)
        playSound = flag(.playSound, d.playSound)
        let levels = (try? c.decodeIfPresent([Int].self, forKey: .usageLevels)) ?? d.usageLevels
        usageLevels = Self.availableLevels.filter(levels.contains)
    }

    public func isLevelEnabled(_ level: Int) -> Bool { usageLevels.contains(level) }

    public mutating func setLevel(_ level: Int, enabled on: Bool) {
        var set = Set(usageLevels)
        if on { set.insert(level) } else { set.remove(level) }
        usageLevels = Self.availableLevels.filter(set.contains)
    }
}
