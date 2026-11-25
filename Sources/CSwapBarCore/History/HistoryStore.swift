import CryptoKit
import Foundation
import SQLite3

/// One usage reading for one account.
public struct UsageSample: Sendable, Equatable {
    public let date: Date
    /// `AccountHasher` output, never an email.
    public let account: String
    public let fiveHour: Double?
    public let sevenDay: Double?

    public init(date: Date, account: String, fiveHour: Double?, sevenDay: Double?) {
        self.date = date
        self.account = account
        self.fiveHour = fiveHour
        self.sevenDay = sevenDay
    }
}

/// A change of active account.
public struct SwitchRecord: Sendable, Equatable {
    public enum Source: String, Sendable {
        /// Switched from CSwapBar.
        case cswapbar
        /// Seen changing outside CSwapBar (terminal, CSwap's own menu bar…).
        case external
        /// Done by `cswap auto` running inside CSwapBar.
        case auto
    }

    public let date: Date
    public let from: String?
    public let to: String
    public let source: Source

    public init(date: Date, from: String?, to: String, source: Source) {
        self.date = date
        self.from = from
        self.to = to
        self.source = source
    }
}

/// Turns account identities into stable, non-reversible keys for storage.
///
/// The salt is random per install, so the same email hashes differently on
/// another Mac and the stored keys can't be matched against a list of emails.
public struct AccountHasher: Sendable {
    public let salt: String

    public init(salt: String) { self.salt = salt }

    public static func makeSalt() -> String {
        (0..<16).map { _ in String(format: "%02x", UInt8.random(in: 0...255)) }.joined()
    }

    public func key(for id: AccountID) -> String {
        let digest = SHA256.hash(data: Data((salt + "|" + id.description).utf8))
        return digest.prefix(10).map { String(format: "%02x", $0) }.joined()
    }
}

public enum HistoryError: Error, Equatable {
    case sqlite(String)
}

/// Local usage history in SQLite. Thread-safe; every call is short.
public final class HistoryStore: @unchecked Sendable {
    public static let retention: TimeInterval = 30 * 24 * 60 * 60

    private var db: OpaquePointer?
    private let lock = NSLock()

    /// Opens (or creates) the database. Use `:memory:` for tests.
    public init(path: String) throws {
        if path != ":memory:" {
            try FileManager.default.createDirectory(
                at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true)
        }
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = db.map { String(cString: sqlite3_errmsg($0)) } ?? "open failed"
            sqlite3_close(db)
            db = nil
            throw HistoryError.sqlite(message)
        }
        try exec("""
            PRAGMA journal_mode = WAL;
            CREATE TABLE IF NOT EXISTS samples (
                ts INTEGER NOT NULL, account TEXT NOT NULL, five REAL, seven REAL);
            CREATE INDEX IF NOT EXISTS samples_ts ON samples(ts);
            CREATE TABLE IF NOT EXISTS switches (
                ts INTEGER NOT NULL, from_account TEXT, to_account TEXT NOT NULL, source TEXT NOT NULL);
            CREATE INDEX IF NOT EXISTS switches_ts ON switches(ts);
            """)
    }

    deinit { sqlite3_close(db) }

    /// `~/Library/Application Support/CSwapBar/history.sqlite`
    public static var defaultPath: String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("CSwapBar/history.sqlite").path
    }

    // MARK: Writing

    public func record(_ samples: [UsageSample]) throws {
        guard !samples.isEmpty else { return }
        try locked {
            try exec("BEGIN")
            do {
                for s in samples {
                    try run("INSERT INTO samples (ts, account, five, seven) VALUES (?, ?, ?, ?)",
                            [.int(Int64(s.date.timeIntervalSince1970)), .text(s.account), .real(s.fiveHour), .real(s.sevenDay)])
                }
                try exec("COMMIT")
            } catch {
                try? exec("ROLLBACK")
                throw error
            }
        }
    }

    public func record(_ change: SwitchRecord) throws {
        try locked {
            try run("INSERT INTO switches (ts, from_account, to_account, source) VALUES (?, ?, ?, ?)",
                    [.int(Int64(change.date.timeIntervalSince1970)), .text(change.from), .text(change.to), .text(change.source.rawValue)])
        }
    }

    /// Deletes everything older than `date`.
    public func prune(before date: Date) throws {
        let ts = Int64(date.timeIntervalSince1970)
        try locked {
            try run("DELETE FROM samples WHERE ts < ?", [.int(ts)])
            try run("DELETE FROM switches WHERE ts < ?", [.int(ts)])
        }
    }

    public func clear() throws {
        try locked { try exec("DELETE FROM samples; DELETE FROM switches; VACUUM;") }
    }

    // MARK: Reading

    public func samples(since date: Date) throws -> [UsageSample] {
        try locked {
            var out: [UsageSample] = []
            try query("SELECT ts, account, five, seven FROM samples WHERE ts >= ? ORDER BY ts",
                      [.int(Int64(date.timeIntervalSince1970))]) { row in
                out.append(UsageSample(
                    date: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(row, 0))),
                    account: String(cString: sqlite3_column_text(row, 1)),
                    fiveHour: Self.optionalDouble(row, 2),
                    sevenDay: Self.optionalDouble(row, 3)))
            }
            return out
        }
    }

    public func switches(since date: Date) throws -> [SwitchRecord] {
        try locked {
            var out: [SwitchRecord] = []
            try query("SELECT ts, from_account, to_account, source FROM switches WHERE ts >= ? ORDER BY ts",
                      [.int(Int64(date.timeIntervalSince1970))]) { row in
                let from = sqlite3_column_type(row, 1) == SQLITE_NULL ? nil : String(cString: sqlite3_column_text(row, 1))
                out.append(SwitchRecord(
                    date: Date(timeIntervalSince1970: TimeInterval(sqlite3_column_int64(row, 0))),
                    from: from,
                    to: String(cString: sqlite3_column_text(row, 2)),
                    source: SwitchRecord.Source(rawValue: String(cString: sqlite3_column_text(row, 3))) ?? .external))
            }
            return out
        }
    }

    public func counts() throws -> (samples: Int, switches: Int) {
        try locked {
            var samples = 0, switches = 0
            try query("SELECT COUNT(*) FROM samples", []) { samples = Int(sqlite3_column_int64($0, 0)) }
            try query("SELECT COUNT(*) FROM switches", []) { switches = Int(sqlite3_column_int64($0, 0)) }
            return (samples, switches)
        }
    }

    // MARK: SQLite plumbing

    private enum Value {
        case int(Int64)
        case real(Double?)
        case text(String?)
    }

    private func locked<T>(_ body: () throws -> T) throws -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw error() }
    }

    private func run(_ sql: String, _ values: [Value]) throws {
        try query(sql, values) { _ in }
    }

    private func query(_ sql: String, _ values: [Value], row: (OpaquePointer) -> Void) throws {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK, let statement else { throw error() }
        defer { sqlite3_finalize(statement) }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        for (index, value) in values.enumerated() {
            let i = Int32(index + 1)
            switch value {
            case .int(let v): sqlite3_bind_int64(statement, i, v)
            case .real(let v?): sqlite3_bind_double(statement, i, v)
            case .text(let v?): sqlite3_bind_text(statement, i, v, -1, transient)
            case .real(nil), .text(nil): sqlite3_bind_null(statement, i)
            }
        }
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_ROW { row(statement); continue }
            if step == SQLITE_DONE { return }
            throw error()
        }
    }

    private func error() -> HistoryError {
        .sqlite(db.map { String(cString: sqlite3_errmsg($0)) } ?? "no database")
    }

    private static func optionalDouble(_ row: OpaquePointer, _ column: Int32) -> Double? {
        sqlite3_column_type(row, column) == SQLITE_NULL ? nil : sqlite3_column_double(row, column)
    }
}

/// Decides when to store a reading: at most every `interval` per account,
/// but right away when usage moved a lot. Keeps 30 days small.
public struct HistorySampler: Sendable {
    public static let interval: TimeInterval = 5 * 60
    public static let bigChange: Double = 10

    private var last: [String: (date: Date, five: Double?, seven: Double?)] = [:]

    public init() {}

    public mutating func samples(from snapshot: AccountSnapshot, hasher: AccountHasher) -> [UsageSample] {
        var out: [UsageSample] = []
        for account in snapshot.accounts {
            guard let usage = account.usage, !usage.isLastKnown else { continue }
            let five = usage.fiveHour?.percent, seven = usage.sevenDay?.percent
            guard five != nil || seven != nil else { continue }
            let key = hasher.key(for: account.id)
            if let previous = last[key] {
                let elapsed = snapshot.capturedAt.timeIntervalSince(previous.date)
                let moved = max(abs((five ?? 0) - (previous.five ?? 0)), abs((seven ?? 0) - (previous.seven ?? 0)))
                guard elapsed >= Self.interval || moved >= Self.bigChange else { continue }
            }
            last[key] = (snapshot.capturedAt, five, seven)
            out.append(UsageSample(date: snapshot.capturedAt, account: key, fiveHour: five, sevenDay: seven))
        }
        return out
    }
}

/// CSV for "Export History…". Account names come from the caller, so they
/// follow the privacy settings at export time.
public enum HistoryCSV {
    public static func make(samples: [UsageSample], switches: [SwitchRecord], name: (String) -> String) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = ["type,timestamp,account,five_hour_pct,seven_day_pct,from_account,source"]
        var rows: [(Date, String)] = []
        for s in samples {
            rows.append((s.date, ["usage", formatter.string(from: s.date), escape(name(s.account)),
                                  s.fiveHour.map(format) ?? "", s.sevenDay.map(format) ?? "", "", ""].joined(separator: ",")))
        }
        for c in switches {
            rows.append((c.date, ["switch", formatter.string(from: c.date), escape(name(c.to)), "", "",
                                  c.from.map { escape(name($0)) } ?? "", c.source.rawValue].joined(separator: ",")))
        }
        lines += rows.sorted { $0.0 < $1.0 }.map(\.1)
        return lines.joined(separator: "\n") + "\n"
    }

    private static func format(_ value: Double) -> String {
        value == value.rounded() ? String(Int(value)) : String(format: "%.1f", value)
    }

    /// Quotes fields with commas, quotes or newlines; neutralizes spreadsheet formulas.
    static func escape(_ field: String) -> String {
        var f = field
        if let first = f.first, "=+-@".contains(first) { f = "'" + f }
        guard f.contains(where: { $0 == "," || $0 == "\"" || $0.isNewline }) else { return f }
        return "\"" + f.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
