import Foundation
import Testing
@testable import CSwapBarCore

@Suite("Version")
struct VersionTests {
    @Test(arguments: [
        ("cswap 1.1.0", "1.1.0"),
        ("cswap 1.2.3\n", "1.2.3"),
        ("cswap 2.0", "2.0.0"),
        ("cswap 1.1.0rc1", "1.1.0"),
    ])
    func parses(output: String, expected: String) throws {
        #expect(try #require(CSwapVersion(versionOutput: output)).description == expected)
    }

    @Test func rejectsGarbage() {
        #expect(CSwapVersion(versionOutput: "cswap") == nil)
        #expect(CSwapVersion(versionOutput: "") == nil)
    }

    @Test func comparesAgainstMinimum() throws {
        #expect(try #require(CSwapVersion(versionOutput: "cswap 1.0.9")) < .minimumSupported)
        #expect(try #require(CSwapVersion(versionOutput: "cswap 1.1.0")) >= .minimumSupported)
        #expect(try #require(CSwapVersion(versionOutput: "cswap 1.10.0")) > .minimumSupported)
    }
}

@Suite("Binary discovery")
struct BinaryLocatorTests {
    @Test func checksKnownLocationsBeforePATH() {
        let locator = CSwapBinaryLocator(homeDirectory: "/Users/test", pathEnvironment: "/usr/bin:/opt/homebrew/bin")
        #expect(locator.candidates == [
            "/Users/test/.local/bin/cswap",
            "/opt/homebrew/bin/cswap",
            "/usr/local/bin/cswap",
            "/usr/bin/cswap",
        ])
    }

    @Test func configuredPathWins() {
        let locator = CSwapBinaryLocator(
            configuredPath: "/custom/cswap",
            homeDirectory: "/Users/test",
            pathEnvironment: "",
            isExecutable: { _ in true }
        )
        #expect(locator.locate()?.path == "/custom/cswap")
    }

    @Test func overrideIsStrictAndLive() {
        let box = CSwapPathSetting()
        let locator = CSwapBinaryLocator(configuredPathProvider: { box.value }, homeDirectory: "/Users/test",
                                         pathEnvironment: "/usr/bin", isExecutable: { $0 == "/usr/bin/cswap" })
        #expect(locator.locate()?.path == "/usr/bin/cswap")      // automatic
        box.value = "~/tools/cswap"
        #expect(locator.candidates == [NSString("~/tools/cswap").expandingTildeInPath])
        #expect(locator.locate() == nil)                          // no silent fallback
        box.value = "  "
        #expect(locator.locate()?.path == "/usr/bin/cswap")      // blank means automatic again
    }

    @Test func returnsNilWhenNothingIsExecutable() {
        let locator = CSwapBinaryLocator(homeDirectory: "/nowhere", pathEnvironment: "", isExecutable: { _ in false })
        #expect(locator.locate() == nil)
    }
}

@Suite("Usage levels")
struct UsageLevelTests {
    static let bands: [(Double, UsageLevel)] = [
        (0, .healthy), (59.9, .healthy), (60, .warning), (79.9, .warning),
        (80, .high), (94.9, .high), (95, .critical), (100, .critical),
    ]

    @Test(arguments: bands)
    func defaultBands(percent: Double, expected: UsageLevel) {
        #expect(UsageThresholds.default.level(for: percent) == expected)
    }

    @Test func missingPercentIsUnknown() {
        #expect(UsageThresholds.default.level(for: nil) == .unknown)
    }
}

@Suite("Countdowns")
struct CountdownTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    static let cases: [(Int, String)] = [
        (9_300, "2h 35m"),
        (302_400, "3d 12h"),
        (172_800, "2d"),
        (3_600, "1h"),
        (750, "12m"),
        (30, "<1m"),
        (0, "now"),
        (-100, "now"),
    ]

    @Test(arguments: cases)
    func formats(offset: Int, expected: String) {
        #expect(CountdownFormatter.string(until: now.addingTimeInterval(Double(offset)), now: now) == expected)
    }

    @Test func missingTimestampIsNeverInvented() {
        #expect(CountdownFormatter.string(until: nil, now: now) == nil)
    }

    @Test func ages() {
        #expect(CountdownFormatter.age(since: now.addingTimeInterval(-10), now: now) == "just now")
        #expect(CountdownFormatter.age(since: now.addingTimeInterval(-300), now: now) == "5m ago")
        #expect(CountdownFormatter.age(since: now.addingTimeInterval(-7200), now: now) == "2h ago")
    }
}

@Suite("Process runner")
struct ProcessRunnerTests {
    @Test func capturesStdoutStderrAndExitCode() async throws {
        let result = try await ProcessRunner().run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "echo out; echo err >&2; exit 3"],
            timeout: 10
        )
        #expect(String(decoding: result.stdout, as: UTF8.self) == "out\n")
        #expect(result.stderrText == "err")
        #expect(result.exitCode == 3)
    }

    @Test func argumentsAreNotShellInterpreted() async throws {
        let result = try await ProcessRunner().run(
            executable: URL(fileURLWithPath: "/bin/echo"),
            arguments: ["$(whoami)", "; rm -rf /"],
            timeout: 10
        )
        #expect(String(decoding: result.stdout, as: UTF8.self) == "$(whoami) ; rm -rf /\n")
    }

    @Test func handlesLargeOutput() async throws {
        // Larger than a pipe buffer (64 KB) to catch read deadlocks.
        let result = try await ProcessRunner().run(
            executable: URL(fileURLWithPath: "/bin/sh"),
            arguments: ["-c", "head -c 300000 /dev/zero | tr '\\0' 'x'"],
            timeout: 10
        )
        #expect(result.stdout.count == 300_000)
    }

    @Test func timesOut() async {
        await #expect(throws: ProcessRunnerError.timedOut(seconds: 0.3)) {
            try await ProcessRunner().run(executable: URL(fileURLWithPath: "/bin/sleep"), arguments: ["5"], timeout: 0.3)
        }
    }

    @Test func missingExecutableFailsToLaunch() async {
        await #expect(throws: ProcessRunnerError.self) {
            try await ProcessRunner().run(executable: URL(fileURLWithPath: "/nonexistent/cswap"), arguments: [], timeout: 5)
        }
    }
}

@Suite("Configurable thresholds and CSwap's menu bar")
struct ThresholdAndMenubarTests {
    @Test func thresholdsNormalize() {
        #expect(UsageThresholds.default.normalized == .default)
        let messy = UsageThresholds(warning: 90, high: 50, critical: 300).normalized
        #expect(messy == UsageThresholds(warning: 90, high: 91, critical: 100))
        let low = UsageThresholds(warning: -5, high: 0, critical: 0.4).normalized
        #expect(low == UsageThresholds(warning: 1, high: 2, critical: 3))
        #expect(UsageThresholds(warning: 99.6, high: 99.6, critical: 99.6).normalized == UsageThresholds(warning: 98, high: 99, critical: 100))
    }

    @Test func customThresholdsChangeLevels() {
        let t = UsageThresholds(warning: 40, high: 70, critical: 90)
        #expect(t.level(for: 39) == .healthy)
        #expect(t.level(for: 40) == .warning)
        #expect(t.level(for: 75) == .high)
        #expect(t.level(for: 90) == .critical)
    }

    @Test func thresholdsPersistAndRepair() throws {
        var settings = AppSettings()
        settings.usageThresholds = UsageThresholds(warning: 50, high: 75, critical: 90)
        settings.cswapPath = "/opt/tools/cswap"
        let decoded = try JSONDecoder().decode(AppSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
        let broken = #"{"usageThresholds":{"warning":95,"high":10,"critical":20},"cswapPath":"   "}"#
        let repaired = try JSONDecoder().decode(AppSettings.self, from: Data(broken.utf8))
        #expect(repaired.usageThresholds == UsageThresholds(warning: 95, high: 96, critical: 97))
        #expect(repaired.cswapPath == nil)
    }

    @Test func detectsCSwapMenubarPassively() {
        #expect(CSwapMenubarStatus.launchAgentPath(home: "/Users/someone") == "/Users/someone/Library/LaunchAgents/com.cswap.menubar.plist")
        #expect(CSwapMenubarStatus.isCSwapMenubarApp(bundleName: "claude-swap Menubar.app", localizedName: nil))
        #expect(CSwapMenubarStatus.isCSwapMenubarApp(bundleName: nil, localizedName: "claude-swap Menubar"))
        #expect(!CSwapMenubarStatus.isCSwapMenubarApp(bundleName: "CSwapBar.app", localizedName: "CSwapBar"))
        #expect(CSwapMenubarStatus(isRunning: false, startsAtLogin: true).isPresent)
        #expect(!CSwapMenubarStatus(isRunning: false, startsAtLogin: false).isPresent)
    }
}
