import Foundation

/// A live, thread-safe holder for the user's CSwap path override, read by
/// `CSwapBinaryLocator` on every call so a change applies without restarting.
public final class CSwapPathSetting: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: String?

    public init(_ value: String? = nil) { stored = value }

    public var value: String? {
        get { lock.withLock { stored } }
        set { lock.withLock { stored = newValue } }
    }
}

/// CSwap's own menu-bar app (`cswap menubar`), detected passively.
///
/// Deliberately does NOT run `cswap menubar --service-status`: that command
/// runs `sfltool dumpbtm` (about two seconds, system-wide) every time.
/// Instead CSwapBar looks at things it can read without running anything:
/// its LaunchAgent file, and the list of running apps.
public struct CSwapMenubarStatus: Sendable, Equatable {
    public static let launchAgentLabel = "com.cswap.menubar"

    public let isRunning: Bool
    /// Its LaunchAgent is installed, so it starts at login.
    public let startsAtLogin: Bool

    public init(isRunning: Bool, startsAtLogin: Bool) {
        self.isRunning = isRunning
        self.startsAtLogin = startsAtLogin
    }

    /// Worth mentioning in Settings.
    public var isPresent: Bool { isRunning || startsAtLogin }

    /// `~/Library/LaunchAgents/com.cswap.menubar.plist`
    public static func launchAgentPath(home: String = NSHomeDirectory()) -> String {
        "\(home)/Library/LaunchAgents/\(launchAgentLabel).plist"
    }

    /// Whether a running app looks like CSwap's menu bar ("claude-swap Menubar.app").
    public static func isCSwapMenubarApp(bundleName: String?, localizedName: String?) -> Bool {
        let names = [bundleName, localizedName].compactMap { $0?.lowercased() }
        return names.contains { $0.contains("claude-swap") && $0.contains("menubar") }
    }

    /// Plain-language summary for Settings.
    public var explanation: String {
        "Both apps read the same CSwap data, so running both is fine; you'll see two menu bar icons. If its auto-switch is on, it may change your Claude account by itself, and CSwapBar will show (and can notify you about) those changes."
    }

    /// The CSwap command that stops it and removes its login item.
    public static let removeCommand = "cswap menubar --uninstall-service"
}
