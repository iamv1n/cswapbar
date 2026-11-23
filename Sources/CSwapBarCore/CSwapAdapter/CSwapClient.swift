import Foundation

public enum CSwapError: Error, Equatable, Sendable {
    /// No `cswap` executable was found.
    case notInstalled
    /// Installed version is older than `CSwapVersion.minimumSupported`.
    case unsupportedVersion(String)
    /// The payload's `schemaVersion` isn't one this build understands.
    case unsupportedSchema(Int)
    /// CSwap reported a handled error (`{"error": {"type", "message"}}`).
    case cliError(type: String, message: String)
    /// Non-zero exit without a JSON error envelope.
    case commandFailed(exitCode: Int32, message: String)
    /// Stdout wasn't the JSON we expected.
    case invalidOutput(String)
    case timedOut
}

public struct CSwapVersion: Comparable, Sendable, CustomStringConvertible {
    public static let minimumSupported = CSwapVersion(major: 1, minor: 1, patch: 0)

    public let major: Int
    public let minor: Int
    public let patch: Int

    public init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    /// Parses `cswap --version` output, e.g. "cswap 1.1.0".
    public init?(versionOutput: String) {
        guard let token = versionOutput
            .split(whereSeparator: { $0.isWhitespace })
            .first(where: { $0.first?.isNumber == true })
        else { return nil }
        let parts = token.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) }
        guard let major = parts.first ?? nil else { return nil }
        self.init(
            major: major,
            minor: parts.count > 1 ? (parts[1] ?? 0) : 0,
            patch: parts.count > 2 ? (parts[2] ?? 0) : 0
        )
    }

    public var description: String { "\(major).\(minor).\(patch)" }

    public static func < (lhs: Self, rhs: Self) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

public struct CSwapInstallation: Sendable, Equatable {
    public let executable: URL
    public let version: CSwapVersion

    public init(executable: URL, version: CSwapVersion) {
        self.executable = executable
        self.version = version
    }
}

/// The live account according to `cswap status --json`.
public struct ActiveAccountStatus: Sendable, Equatable {
    /// `nil` when no Claude login is active.
    public let id: AccountID?
    public let slot: Int?
    /// False when the live login isn't one of CSwap's managed accounts.
    public let isManaged: Bool

    public init(id: AccountID?, slot: Int?, isManaged: Bool) {
        self.id = id
        self.slot = slot
        self.isManaged = isManaged
    }
}

public struct SwitchResponse: Sendable, Equatable {
    public let switched: Bool
    public let reason: String?
    public let message: String?
    public let warnings: [String]

    public init(switched: Bool, reason: String?, message: String?, warnings: [String]) {
        self.switched = switched
        self.reason = reason
        self.message = message
        self.warnings = warnings
    }
}

/// Everything CSwapBar needs from CSwap. Mockable for tests.
public protocol CSwapClient: Sendable {
    func detect() async throws -> CSwapInstallation
    func listAccounts() async throws -> AccountSnapshot
    func status() async throws -> ActiveAccountStatus
    func switchTo(slot: Int) async throws -> SwitchResponse
}

public struct CSwapCLIClient: CSwapClient {
    public static let defaultTimeout: Double = 30
    /// Switching can wait on CSwap's locks while Claude Code is busy.
    public static let switchTimeout: Double = 60

    private let locator: CSwapBinaryLocator
    private let runner: any ProcessRunning
    private let clock: @Sendable () -> Date

    public init(
        locator: CSwapBinaryLocator = CSwapBinaryLocator(),
        runner: any ProcessRunning = ProcessRunner(environment: ["NO_COLOR": "1"]),
        clock: @escaping @Sendable () -> Date = Date.init
    ) {
        self.locator = locator
        self.runner = runner
        self.clock = clock
    }

    public func detect() async throws -> CSwapInstallation {
        guard let executable = locator.locate() else { throw CSwapError.notInstalled }
        let result = try await run(executable, ["--version"], timeout: 10)
        let output = String(decoding: result.stdout + result.stderr, as: UTF8.self)
        guard result.exitCode == 0, let version = CSwapVersion(versionOutput: output) else {
            throw CSwapError.invalidOutput("Could not read the CSwap version from: \(output.prefix(200))")
        }
        guard version >= .minimumSupported else {
            throw CSwapError.unsupportedVersion(version.description)
        }
        return CSwapInstallation(executable: executable, version: version)
    }

    public func listAccounts() async throws -> AccountSnapshot {
        let dto: CSwapListDTO = try await runJSON(["list", "--json"])
        return AccountMapper.snapshot(from: dto, capturedAt: clock())
    }

    public func status() async throws -> ActiveAccountStatus {
        let dto: CSwapStatusDTO = try await runJSON(["status", "--json"])
        guard let active = dto.active else {
            return ActiveAccountStatus(id: nil, slot: nil, isManaged: false)
        }
        return ActiveAccountStatus(
            id: AccountID(email: active.email, organizationUUID: active.organizationUuid ?? ""),
            slot: active.number,
            isManaged: active.managed ?? (active.number != nil)
        )
    }

    public func switchTo(slot: Int) async throws -> SwitchResponse {
        let dto: CSwapSwitchDTO = try await runJSON(["switch", String(slot), "--json"], timeout: Self.switchTimeout)
        return SwitchResponse(
            switched: dto.switched ?? false,
            reason: dto.reason,
            message: dto.message,
            warnings: dto.warnings ?? []
        )
    }

    // MARK: - Execution

    private func runJSON<T: Decodable>(_ arguments: [String], timeout: Double = Self.defaultTimeout) async throws -> T {
        guard let executable = locator.locate() else { throw CSwapError.notInstalled }
        let result = try await run(executable, arguments, timeout: timeout)
        return try Self.decode(T.self, from: result)
    }

    private func run(_ executable: URL, _ arguments: [String], timeout: Double) async throws -> ProcessResult {
        do {
            return try await runner.run(executable: executable, arguments: arguments, timeout: timeout)
        } catch ProcessRunnerError.timedOut {
            throw CSwapError.timedOut
        } catch ProcessRunnerError.launchFailed(let reason) {
            throw CSwapError.commandFailed(exitCode: -1, message: reason)
        }
    }

    /// Decodes a CSwap JSON payload, surfacing error envelopes and schema mismatches.
    static func decode<T: Decodable>(_ type: T.Type, from result: ProcessResult) throws -> T {
        let decoder = JSONDecoder()
        let envelope = try? decoder.decode(CSwapEnvelopeDTO.self, from: result.stdout)

        if let error = envelope?.error {
            throw CSwapError.cliError(
                type: error.type ?? "UnknownError",
                message: error.message ?? result.stderrText
            )
        }
        guard result.exitCode == 0 else {
            let message = result.stderrText.isEmpty ? "cswap exited with code \(result.exitCode)" : result.stderrText
            throw CSwapError.commandFailed(exitCode: result.exitCode, message: String(message.prefix(500)))
        }
        guard let schema = envelope?.schemaVersion else {
            throw CSwapError.invalidOutput("Expected a JSON object with schemaVersion.")
        }
        guard schema == supportedCSwapSchemaVersion else {
            throw CSwapError.unsupportedSchema(schema)
        }
        do {
            return try decoder.decode(T.self, from: result.stdout)
        } catch {
            throw CSwapError.invalidOutput(String(describing: error).prefix(300).description)
        }
    }
}
