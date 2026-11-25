import Foundation

/// Where updates come from.
public enum UpdateSource {
    public static let repository = "iamv1n/cswapbar"
    public static let latestReleaseAPI = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    public static let releasesPage = URL(string: "https://github.com/\(repository)/releases")!
    /// Daily, like most menu-bar apps.
    public static let checkInterval: TimeInterval = 24 * 60 * 60
}

/// Update settings.
public struct UpdatePreferences: Codable, Sendable, Equatable {
    /// Ask GitHub once a day whether a newer release exists.
    public var checkAutomatically: Bool = true
    /// Download, verify and install new releases without asking.
    public var installAutomatically: Bool = false
    /// A version the user chose to skip.
    public var skippedVersion: String?

    public init() {}

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = UpdatePreferences()
        checkAutomatically = (try? c.decodeIfPresent(Bool.self, forKey: .checkAutomatically)) ?? d.checkAutomatically
        installAutomatically = (try? c.decodeIfPresent(Bool.self, forKey: .installAutomatically)) ?? d.installAutomatically
        skippedVersion = (try? c.decodeIfPresent(String.self, forKey: .skippedVersion)) ?? nil
    }
}

/// A semantic version: "1.2.3", "v1.2.3", "1.2.3-beta.1".
public struct AppVersion: Sendable, Equatable, Comparable, CustomStringConvertible {
    public let major: Int
    public let minor: Int
    public let patch: Int
    /// Pre-release label, e.g. "beta.1". A pre-release sorts before its release.
    public let prerelease: String?

    public init?(_ string: String) {
        var s = string.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("v") || s.hasPrefix("V") { s.removeFirst() }
        let parts = s.split(separator: "-", maxSplits: 1)
        guard let core = parts.first else { return nil }
        let numbers = core.split(separator: ".").map { Int($0) }
        guard (1...3).contains(numbers.count), numbers.allSatisfy({ $0 != nil && $0! >= 0 }) else { return nil }
        major = numbers[0]!
        minor = numbers.count > 1 ? numbers[1]! : 0
        patch = numbers.count > 2 ? numbers[2]! : 0
        prerelease = parts.count > 1 ? String(parts[1]) : nil
    }

    public var description: String {
        "\(major).\(minor).\(patch)" + (prerelease.map { "-\($0)" } ?? "")
    }

    public static func < (a: AppVersion, b: AppVersion) -> Bool {
        if (a.major, a.minor, a.patch) != (b.major, b.minor, b.patch) {
            return (a.major, a.minor, a.patch) < (b.major, b.minor, b.patch)
        }
        switch (a.prerelease, b.prerelease) {
        case (nil, nil), (nil, _?): return false
        case (_?, nil): return true
        case let (x?, y?): return x.compare(y, options: .numeric) == .orderedAscending
        }
    }
}

/// The parts of GitHub's release JSON CSwapBar uses.
public struct GitHubRelease: Decodable, Sendable, Equatable {
    public struct Asset: Decodable, Sendable, Equatable {
        public let name: String
        public let browserDownloadURL: URL
        public let size: Int

        enum CodingKeys: String, CodingKey {
            case name, size
            case browserDownloadURL = "browser_download_url"
        }
    }

    public let tagName: String
    public let name: String?
    public let body: String?
    public let htmlURL: URL
    public let draft: Bool
    public let prerelease: Bool
    public let publishedAt: Date?
    public let assets: [Asset]

    enum CodingKeys: String, CodingKey {
        case name, body, draft, prerelease, assets
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case publishedAt = "published_at"
    }

    public static func decode(_ data: Data) throws -> GitHubRelease {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(GitHubRelease.self, from: data)
    }
}

/// A newer release that can be installed.
public struct AvailableUpdate: Sendable, Equatable {
    public let version: AppVersion
    public let notes: String
    public let releasePage: URL
    public let publishedAt: Date?
    /// The zipped app and its checksum file. Nil when the release lacks them;
    /// the update can then only be downloaded by hand.
    public let archive: GitHubRelease.Asset?
    public let checksum: GitHubRelease.Asset?

    public var canInstall: Bool { archive != nil && checksum != nil }

    /// Expected archive name, as `scripts/package.sh` produces it.
    public static func archiveName(for version: AppVersion) -> String { "CSwapBar-\(version).zip" }

    /// Returns the update if `release` is newer than `current` and a normal (not draft
    /// or pre-release) release. Pre-releases are only offered to pre-release builds.
    public static func from(_ release: GitHubRelease, current: AppVersion) -> AvailableUpdate? {
        guard !release.draft, let version = AppVersion(release.tagName), version > current else { return nil }
        if release.prerelease, current.prerelease == nil { return nil }
        let zipName = archiveName(for: version)
        let archive = release.assets.first { $0.name == zipName }
        let checksum = release.assets.first { $0.name == zipName + ".sha256" }
        return AvailableUpdate(
            version: version,
            notes: (release.body ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
            releasePage: release.htmlURL,
            publishedAt: release.publishedAt,
            archive: archive,
            checksum: checksum)
    }
}

public enum Checksum {
    /// Reads `shasum -a 256` output ("<64 hex>  <file name>") and returns the
    /// lowercase digest for `fileName`. Also accepts a bare digest.
    public static func sha256(fromChecksumFile text: String, fileName: String) -> String? {
        for line in text.split(whereSeparator: \.isNewline) {
            let fields = line.split(whereSeparator: \.isWhitespace)
            guard let digest = fields.first.map(String.init)?.lowercased(), isDigest(digest) else { continue }
            if fields.count == 1 { return digest }
            let name = fields[1].hasPrefix("*") ? String(fields[1].dropFirst()) : String(fields[1])
            if name == fileName { return digest }
        }
        return nil
    }

    static func isDigest(_ s: String) -> Bool {
        s.count == 64 && s.allSatisfy { $0.isHexDigit }
    }
}
