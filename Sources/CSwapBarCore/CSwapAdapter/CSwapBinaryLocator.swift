import Foundation

/// Finds the `cswap` executable.
///
/// Apps launched from Finder don't inherit the login shell's `PATH`, so the
/// usual install locations are checked explicitly before falling back to `PATH`.
public struct CSwapBinaryLocator: Sendable {
    /// A path the user set in Settings. When set, it's the only path tried.
    public var configuredPath: String?
    /// Reads the configured path at call time (it can change while the app runs).
    private let configuredPathProvider: (@Sendable () -> String?)?
    private let homeDirectory: String
    private let pathEnvironment: String
    private let isExecutable: @Sendable (String) -> Bool

    public init(
        configuredPath: String? = nil,
        configuredPathProvider: (@Sendable () -> String?)? = nil,
        homeDirectory: String = NSHomeDirectory(),
        pathEnvironment: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.configuredPath = configuredPath
        self.configuredPathProvider = configuredPathProvider
        self.homeDirectory = homeDirectory
        self.pathEnvironment = pathEnvironment
        self.isExecutable = isExecutable
    }

    /// The user's override, expanded, or nil for automatic detection.
    public var override: String? {
        let raw = (configuredPathProvider?() ?? configuredPath)?.trimmingCharacters(in: .whitespaces)
        guard let raw, !raw.isEmpty else { return nil }
        return (raw as NSString).expandingTildeInPath
    }

    /// Candidate paths in priority order (deduplicated).
    public var candidates: [String] {
        if let override { return [override] }
        var paths: [String] = []
        paths += [
            "\(homeDirectory)/.local/bin/cswap",   // uv tool / pipx
            "/opt/homebrew/bin/cswap",             // Homebrew, Apple Silicon
            "/usr/local/bin/cswap",                // Homebrew, Intel / manual
        ]
        paths += pathEnvironment
            .split(separator: ":")
            .map { "\($0)/cswap" }

        var seen = Set<String>()
        return paths.filter { seen.insert($0).inserted }
    }

    public func locate() -> URL? {
        candidates.first(where: isExecutable).map { URL(fileURLWithPath: $0) }
    }
}
