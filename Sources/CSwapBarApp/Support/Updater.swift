import AppKit
import CryptoKit
import CSwapBarCore
import Foundation
import Observation

/// Checks GitHub Releases for a newer CSwapBar and installs it.
///
/// The check is one anonymous GET to GitHub's public API. Nothing about the
/// user or their accounts is sent. Installing:
/// 1. downloads the release's `.zip` and its `.sha256` file over HTTPS,
/// 2. verifies the SHA-256 digest,
/// 3. unpacks it and checks the bundle ID, version and code signature,
/// 4. swaps it in place of the running app, then relaunches.
///
/// Releases are ad-hoc signed (no Apple Developer ID), so the checksum and
/// HTTPS from github.com are what vouch for the download. Notarized builds
/// with signed Sparkle feeds are on the roadmap for 1.0.
@MainActor
@Observable
final class Updater {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(AvailableUpdate)
        case installing(String)
        case failed(String)
    }

    private(set) var state: State = .idle
    private(set) var lastChecked: Date? {
        didSet { UserDefaults.standard.set(lastChecked, forKey: Self.lastCheckedKey) }
    }

    @ObservationIgnored private let settings: () -> UpdatePreferences
    @ObservationIgnored private let onUpdateFound: (AvailableUpdate) -> Void
    @ObservationIgnored private var loop: Task<Void, Never>?

    private static let lastCheckedKey = "CSwapBar.updates.lastChecked"

    /// The running version, from the app bundle.
    static var currentVersion: AppVersion {
        let raw = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return raw.flatMap(AppVersion.init) ?? AppVersion("0.0.0")!
    }

    static var currentVersionString: String { currentVersion.description }

    /// Only an app inside an Applications folder replaces itself. Dev builds
    /// (build/, `swift run`) offer the download page instead.
    static var canSelfInstall: Bool {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "app" else { return false }
        let parent = url.deletingLastPathComponent()
        return parent.lastPathComponent == "Applications"
            && FileManager.default.isWritableFile(atPath: parent.path)
    }

    init(settings: @escaping () -> UpdatePreferences, onUpdateFound: @escaping (AvailableUpdate) -> Void) {
        self.settings = settings
        self.onUpdateFound = onUpdateFound
        lastChecked = UserDefaults.standard.object(forKey: Self.lastCheckedKey) as? Date
    }

    var availableUpdate: AvailableUpdate? {
        if case .available(let update) = state { return update }
        return nil
    }

    /// Checks shortly after launch, then daily, while automatic checks are on.
    func startAutomaticChecks() {
        loop?.cancel()
        loop = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            while !Task.isCancelled {
                guard let self else { return }
                if self.settings().checkAutomatically, self.isDue {
                    await self.check(userInitiated: false)
                }
                try? await Task.sleep(for: .seconds(60 * 60))
            }
        }
    }

    private var isDue: Bool {
        guard let lastChecked else { return true }
        return Date().timeIntervalSince(lastChecked) >= UpdateSource.checkInterval
    }

    // MARK: Check

    func check(userInitiated: Bool) async {
        if case .installing = state { return }
        state = .checking
        do {
            var request = URLRequest(url: UpdateSource.latestReleaseAPI, timeoutInterval: 20)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("CSwapBar/\(Self.currentVersionString)", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await Self.session.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status == 404 {   // no releases yet
                lastChecked = Date()
                state = .upToDate
                return
            }
            guard status == 200 else { throw UpdateError.http(status) }
            let release = try GitHubRelease.decode(data)
            lastChecked = Date()

            guard let update = AvailableUpdate.from(release, current: Self.currentVersion) else {
                state = .upToDate
                return
            }
            // A skipped version stays quiet unless the user asked.
            if !userInitiated, settings().skippedVersion == update.version.description {
                state = .upToDate
                return
            }
            state = .available(update)
            if !userInitiated {
                if settings().installAutomatically, update.canInstall, Self.canSelfInstall {
                    await install(update)
                } else {
                    onUpdateFound(update)
                }
            }
        } catch {
            state = userInitiated ? .failed(Self.describe(error)) : .idle
        }
    }

    // MARK: Install

    func install(_ update: AvailableUpdate) async {
        guard let archive = update.archive, let checksumAsset = update.checksum else {
            state = .failed("This release has no installable archive. Download it from GitHub instead.")
            return
        }
        guard Self.canSelfInstall else {
            NSWorkspace.shared.open(update.releasePage)
            state = .available(update)
            return
        }
        let appURL = Bundle.main.bundleURL
        do {
            state = .installing("Downloading \(update.version)…")
            // A scratch folder on the same volume, so the final swap is a rename.
            let work = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask,
                                                   appropriateFor: appURL, create: true)
            defer { try? FileManager.default.removeItem(at: work) }

            let zipURL = work.appendingPathComponent(archive.name)
            try await Self.download(archive.browserDownloadURL, to: zipURL)
            let checksumText = try await Self.downloadText(checksumAsset.browserDownloadURL)

            state = .installing("Verifying…")
            guard let expected = Checksum.sha256(fromChecksumFile: checksumText, fileName: archive.name) else {
                throw UpdateError.verification("The checksum file is unreadable.")
            }
            let actual = try Self.sha256(of: zipURL)
            guard actual == expected else { throw UpdateError.verification("The download doesn't match its checksum.") }

            let unpacked = work.appendingPathComponent("unpacked", isDirectory: true)
            try Self.run("/usr/bin/ditto", ["-x", "-k", zipURL.path, unpacked.path])
            let newApp = unpacked.appendingPathComponent("CSwapBar.app")
            try Self.validate(newApp, expectedVersion: update.version)
            // Downloads made by URLSession aren't quarantined, but be sure.
            try? Self.run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", newApp.path])

            state = .installing("Installing…")
            _ = try FileManager.default.replaceItemAt(appURL, withItemAt: newApp)

            relaunch(appURL)
        } catch {
            state = .failed(Self.describe(error))
        }
    }

    /// Opens the (new) app after this process exits.
    private func relaunch(_ appURL: URL) {
        let script = "while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done; /usr/bin/open \"$0\""
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script, appURL.path]
        try? process.run()
        NSApp.terminate(nil)
    }

    // MARK: Helpers

    private static let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.httpCookieAcceptPolicy = .never
        config.httpShouldSetCookies = false
        config.urlCache = nil
        return URLSession(configuration: config)
    }()

    private static func download(_ url: URL, to destination: URL) async throws {
        let (temp, response) = try await session.download(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw UpdateError.http(status) }
        try FileManager.default.moveItem(at: temp, to: destination)
    }

    private static func downloadText(_ url: URL) async throws -> String {
        let (data, response) = try await session.data(from: url)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw UpdateError.http(status) }
        return String(decoding: data, as: UTF8.self)
    }

    private static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    /// The new bundle must be CSwapBar, at the advertised version, with an intact signature.
    private static func validate(_ app: URL, expectedVersion: AppVersion) throws {
        guard let bundle = Bundle(url: app),
              let id = bundle.bundleIdentifier,
              let raw = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              let version = AppVersion(raw) else {
            throw UpdateError.verification("The download doesn't contain CSwapBar.")
        }
        guard id == Bundle.main.bundleIdentifier else { throw UpdateError.verification("The download is a different app.") }
        guard version == expectedVersion else { throw UpdateError.verification("The download is version \(version), not \(expectedVersion).") }
        do {
            try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        } catch {
            throw UpdateError.verification("The app's signature is broken.")
        }
    }

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw UpdateError.tool(URL(fileURLWithPath: tool).lastPathComponent) }
    }

    enum UpdateError: Error {
        case http(Int)
        case verification(String)
        case tool(String)
    }

    static func describe(_ error: any Error) -> String {
        switch error {
        case UpdateError.http(403), UpdateError.http(429): return "GitHub is rate-limiting requests. Try again later."
        case UpdateError.http(let code): return "GitHub returned an error (\(code))."
        case UpdateError.verification(let message): return message + " Nothing was changed."
        case UpdateError.tool(let name): return "\(name) failed while unpacking the update. Nothing was changed."
        case let error as URLError where error.code == .notConnectedToInternet: return "You're offline."
        case let error as URLError where error.code == .timedOut: return "GitHub didn't respond in time."
        default: return "Couldn't update: \(error.localizedDescription)"
        }
    }
}
