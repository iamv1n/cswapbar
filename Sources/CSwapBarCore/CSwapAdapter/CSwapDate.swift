import Foundation

/// Parses the ISO-8601 timestamps CSwap emits.
///
/// CSwap passes through whatever the usage API returned, so both forms occur:
/// `2026-11-23T19:00:00.611925+00:00` and `2026-12-11T15:36:16Z`.
enum CSwapDate {
    static func parse(_ string: String?) -> Date? {
        guard let string, !string.isEmpty else { return nil }
        if let date = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(string) {
            return date
        }
        if let date = try? Date.ISO8601FormatStyle().parse(string) {
            return date
        }
        return parseTrimmingFraction(string)
    }

    /// Fallback: drop the fractional part entirely and retry.
    private static func parseTrimmingFraction(_ string: String) -> Date? {
        guard let dot = string.firstIndex(of: ".") else { return nil }
        let afterDot = string[string.index(after: dot)...]
        guard let zoneStart = afterDot.firstIndex(where: { !$0.isNumber }) else { return nil }
        let fraction = Double("0." + afterDot[..<zoneStart]) ?? 0
        let trimmed = String(string[..<dot]) + String(afterDot[zoneStart...])
        guard let base = try? Date.ISO8601FormatStyle().parse(trimmed) else { return nil }
        return base.addingTimeInterval(fraction)
    }
}
