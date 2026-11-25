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
    public var notifications = NotificationPreferences()
    /// System-wide shortcut that toggles Privacy Mode from any app.
    public var privacyShortcutEnabled: Bool = true
    public var privacyShortcut: KeyShortcut = .defaultPrivacyToggle
    /// System-wide shortcut that opens or closes the popover.
    public var openShortcutEnabled: Bool = true
    public var openShortcut: KeyShortcut = .defaultOpenPopover
    /// Corners, borders, bar thickness and control shape, on top of any theme.
    public var design = DesignOptions()
    /// Themes the user made or imported.
    public var customThemes: [CustomTheme] = []
    /// When set (and found in `customThemes`), overrides `theme`.
    public var customThemeID: UUID?
    public var updates = UpdatePreferences()
    /// Where the usage colors change (yellow, orange, red).
    public var usageThresholds: UsageThresholds = .default
    /// Path to `cswap` chosen in Settings; nil finds it automatically.
    public var cswapPath: String?
    /// Keep 30 days of usage history on this Mac (for the dashboard).
    public var historyEnabled: Bool = true
    /// Run `cswap auto` from CSwapBar. Off by default.
    public var autoSwitch = AutoSwitchPreferences()
    /// Show the "best next account" hint in the popover.
    public var showRecommendation: Bool = true
    /// The notch-style usage bar at the top of the screen.
    public var usageIsland = UsageIslandPreferences()

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
        notifications = (try? c.decodeIfPresent(NotificationPreferences.self, forKey: .notifications)) ?? defaults.notifications
        privacyShortcutEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .privacyShortcutEnabled)) ?? defaults.privacyShortcutEnabled
        let shortcut = (try? c.decodeIfPresent(KeyShortcut.self, forKey: .privacyShortcut)) ?? defaults.privacyShortcut
        privacyShortcut = shortcut.isValidGlobalShortcut ? shortcut : defaults.privacyShortcut
        openShortcutEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .openShortcutEnabled)) ?? defaults.openShortcutEnabled
        let open = (try? c.decodeIfPresent(KeyShortcut.self, forKey: .openShortcut)) ?? defaults.openShortcut
        openShortcut = open.isValidGlobalShortcut ? open : defaults.openShortcut
        design = (try? c.decodeIfPresent(DesignOptions.self, forKey: .design)) ?? defaults.design
        // One unreadable theme doesn't drop the others.
        let lossy = (try? c.decodeIfPresent([Lossy<CustomTheme>].self, forKey: .customThemes)) ?? []
        customThemes = Array(lossy.compactMap(\.value).prefix(CustomTheme.maxCount))
        customThemeID = (try? c.decodeIfPresent(UUID.self, forKey: .customThemeID)) ?? nil
        updates = (try? c.decodeIfPresent(UpdatePreferences.self, forKey: .updates)) ?? defaults.updates
        usageThresholds = ((try? c.decodeIfPresent(UsageThresholds.self, forKey: .usageThresholds)) ?? defaults.usageThresholds).normalized
        let path = (try? c.decodeIfPresent(String.self, forKey: .cswapPath)) ?? nil
        cswapPath = path?.trimmingCharacters(in: .whitespaces).isEmpty == false ? path : nil
        historyEnabled = (try? c.decodeIfPresent(Bool.self, forKey: .historyEnabled)) ?? defaults.historyEnabled
        autoSwitch = (try? c.decodeIfPresent(AutoSwitchPreferences.self, forKey: .autoSwitch)) ?? defaults.autoSwitch
        showRecommendation = (try? c.decodeIfPresent(Bool.self, forKey: .showRecommendation)) ?? defaults.showRecommendation
        usageIsland = (try? c.decodeIfPresent(UsageIslandPreferences.self, forKey: .usageIsland)) ?? defaults.usageIsland
    }

    /// The custom theme in use, if any.
    public var activeCustomTheme: CustomTheme? {
        guard let customThemeID else { return nil }
        return customThemes.first { $0.id == customThemeID }
    }

    /// The palette to paint with: the active custom theme, or the built-in theme.
    public func activePalette(systemIsDark: Bool) -> ThemePalette {
        activeCustomTheme?.palette ?? theme.palette(systemIsDark: systemIsDark)
    }

    /// True when the palette follows macOS light/dark.
    public var followsSystemAppearance: Bool {
        activeCustomTheme == nil && theme.adaptiveVariants != nil
    }

    public mutating func selectBuiltInTheme(_ choice: ThemeChoice) {
        theme = choice
        customThemeID = nil
    }

    /// Adds a custom theme and switches to it. Returns false when the limit is reached.
    @discardableResult
    public mutating func addCustomTheme(_ custom: CustomTheme) -> Bool {
        guard customThemes.count < CustomTheme.maxCount else { return false }
        customThemes.append(custom)
        customThemeID = custom.id
        return true
    }

    public mutating func deleteCustomTheme(id: UUID) {
        customThemes.removeAll { $0.id == id }
        if customThemeID == id { customThemeID = nil }
    }
}

/// Decodes an element if it can, or yields `nil` instead of failing the whole array.
struct Lossy<T: Decodable>: Decodable {
    let value: T?
    init(from decoder: any Decoder) throws {
        value = try? T(from: decoder)
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
