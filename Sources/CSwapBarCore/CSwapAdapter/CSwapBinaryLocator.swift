import Foundation

/// Finds the `cswap` executable.
///
/// Apps launched from Finder don't inherit the login shell's `PATH`, so the
/// usual install locations are checked explicitly before falling back to `PATH`.
public struct CSwapBinaryLocator: Sendable {
    /// A path the user set in Settings. Checked first.
    public var configuredPath: String?
    private let homeDirectory: String
    private let pathEnvironment: String
    private let isExecutable: @Sendable (String) -> Bool

    public init(
        configuredPath: String? = nil,
        homeDirectory: String = NSHomeDirectory(),
        pathEnvironment: String = ProcessInfo.processInfo.environment["PATH"] ?? "",
        isExecutable: @escaping @Sendable (String) -> Bool = { FileManager.default.isExecutableFile(atPath: $0) }
    ) {
        self.configuredPath = configuredPath
        self.homeDirectory = homeDirectory
        self.pathEnvironment = pathEnvironment
        self.isExecutable = isExecutable
    }

    /// Candidate paths in priority order (deduplicated).
    public var candidates: [String] {
        var paths: [String] = []
        if let configuredPath, !configuredPath.isEmpty {
            paths.append((configuredPath as NSString).expandingTildeInPath)
        }
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
