import Foundation

/// Everything the user can configure. Persisted as one JSON blob in UserDefaults.
/// Never holds credentials or account identities.
public struct AppSettings: Codable, Sendable, Equatable {
    public var privacy = PrivacyPreferences()
    public var theme: ThemeChoice = .system
    public var accent: AccentChoice = .themeDefault
    public var font: FontChoice = .system
    public var textSize: TextSizeChoice = .standard
    public var menuBarDisplay: MenuBarDisplay = .fiveHourUsage
    public var refreshIntervalSeconds: Int = 60
    public var compactCards: Bool = false
    public var cardLayout: CardLayout = .meters
    /// Desktop widgets that are switched on, in display order.
    public var desktopWidgets: [DesktopWidgetKind] = []
    /// Keep desktop widgets above other windows instead of on the desktop.
    public var widgetsFloatOnTop: Bool = false
    /// Accounts per popover page.
    public var accountsPerPage: Int = AccountPaging.defaultPageSize

    public static let refreshIntervalOptions = [30, 60, 120, 300]

    public init() {}

    // Lenient: an unknown enum value or missing key falls back to its default
    // instead of discarding every other setting.
    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = AppSettings()
        privacy = (try? c.decodeIfPresent(PrivacyPreferences.self, forKey: .privacy)) ?? defaults.privacy
        theme = (try? c.decodeIfPresent(ThemeChoice.self, forKey: .theme)) ?? defaults.theme
        accent = (try? c.decodeIfPresent(AccentChoice.self, forKey: .accent)) ?? defaults.accent
        font = (try? c.decodeIfPresent(FontChoice.self, forKey: .font)) ?? defaults.font
        textSize = (try? c.decodeIfPresent(TextSizeChoice.self, forKey: .textSize)) ?? defaults.textSize
        menuBarDisplay = (try? c.decodeIfPresent(MenuBarDisplay.self, forKey: .menuBarDisplay)) ?? defaults.menuBarDisplay
        let interval = (try? c.decodeIfPresent(Int.self, forKey: .refreshIntervalSeconds)) ?? defaults.refreshIntervalSeconds
        refreshIntervalSeconds = min(max(interval, 15), 3_600)
        compactCards = (try? c.decodeIfPresent(Bool.self, forKey: .compactCards)) ?? defaults.compactCards
        cardLayout = (try? c.decodeIfPresent(CardLayout.self, forKey: .cardLayout)) ?? defaults.cardLayout
        // Unknown kinds (from a newer version) are dropped, not fatal.
        let rawWidgets = (try? c.decodeIfPresent([String].self, forKey: .desktopWidgets)) ?? []
        var seen = Set<DesktopWidgetKind>()
        desktopWidgets = rawWidgets.compactMap(DesktopWidgetKind.init(rawValue:)).filter { seen.insert($0).inserted }
        widgetsFloatOnTop = (try? c.decodeIfPresent(Bool.self, forKey: .widgetsFloatOnTop)) ?? defaults.widgetsFloatOnTop
        let perPage = (try? c.decodeIfPresent(Int.self, forKey: .accountsPerPage)) ?? defaults.accountsPerPage
        accountsPerPage = min(max(perPage, 2), 8)
    }
}

/// How each account card is drawn in the popover.
public enum CardLayout: String, CaseIterable, Codable, Sendable {
    /// Side-by-side meters with big percentages.
    case meters
    /// Stacked bars with the percentage at the end of each row.
    case classic
    /// Two circular gauges per account.
    case rings
    /// One dense row per account — fits the most on screen.
    case list

    public var title: String {
        switch self {
        case .meters: "Meters"
        case .classic: "Classic"
        case .rings: "Rings"
        case .list: "List"
        }
    }

    public var summary: String {
        switch self {
        case .meters: "Big numbers, side by side"
        case .classic: "Stacked bars with resets"
        case .rings: "Circular gauges"
        case .list: "One compact row each"
        }
    }

    /// Suggested accounts per page so the popover stays a comfortable height.
    public var suggestedPageSize: Int {
        switch self {
        case .meters, .classic, .rings: 4
        case .list: 8
        }
    }
}

/// Compact desktop widgets the app can show (in-app panels, not WidgetKit).
public enum DesktopWidgetKind: String, CaseIterable, Codable, Sendable {
    /// Small square: the active account's 5-hour usage as one big ring.
    case gauge
    /// Wide: the active account with 5-hour and 7-day rings.
    case active
    /// Tall: every account as a compact row.
    case accounts

    public var title: String {
        switch self {
        case .gauge: "Gauge"
        case .active: "Active Account"
        case .accounts: "All Accounts"
        }
    }

    public var summary: String {
        switch self {
        case .gauge: "Small · 5-hour usage ring"
        case .active: "Wide · both windows for the active account"
        case .accounts: "Tall · every account at a glance"
        }
    }

    /// Accounts the "All Accounts" widget lists before summarizing the rest.
    public static let maxRows = 5
}

/// Loads and saves `AppSettings`.
public final class SettingsStore {
    public static let key = "CSwapBar.settings.v1"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func load() -> AppSettings {
        guard let data = defaults.data(forKey: Self.key),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else { return AppSettings() }
        return settings
    }

    public func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else { return }
        defaults.set(data, forKey: Self.key)
    }

    public func reset() {
        defaults.removeObject(forKey: Self.key)
    }
}
