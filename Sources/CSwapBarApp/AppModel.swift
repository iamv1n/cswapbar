import AppKit
import CSwapBarCore
import Foundation
import Observation

/// App-wide state: CSwap connection, latest accounts, refresh loop, switching.
@MainActor
@Observable
final class AppModel {
    enum Connection: Equatable {
        case connecting
        case connected(CSwapInstallation)
        case notInstalled
        case unsupported(String)
        case failed(String)
    }

    /// How current the shown usage is.
    enum Freshness: Equatable {
        case fresh
        case updating
        case stale
        case unavailable
    }

    enum SwitchState: Equatable {
        case idle
        case switching(AccountID)
        case succeeded(AccountID)
        case failed(AccountID, String)
    }

    private(set) var connection: Connection = .connecting
    private(set) var snapshot: AccountSnapshot?
    private(set) var lastRefreshError: String?
    private(set) var lastSuccessfulRefresh: Date?
    private(set) var isRefreshing = false
    private(set) var switchState: SwitchState = .idle

    /// Saved on every change; privacy changes apply immediately.
    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            store.save(settings)
            if settings.refreshIntervalSeconds != oldValue.refreshIntervalSeconds {
                startRefreshLoop()
            }
            // Older notifications may name accounts; clear them when going private.
            if settings.privacy.privacyModeEnabled, !oldValue.privacy.privacyModeEnabled {
                notifier.clearDelivered()
            }
            if settings.notifications.enabled, !oldValue.notifications.enabled {
                Task { await notifier.requestPermission() }
            }
            if settings.cswapPath != oldValue.cswapPath {
                cswapPath.value = settings.cswapPath
                Task { await reconnect() }
            }
            if settings.autoSwitch != oldValue.autoSwitch {
                autoSwitcher?.apply(settings.autoSwitch)
            }
        }
    }

    /// Where usage colors change; set in Settings → Layout.
    var thresholds: UsageThresholds { settings.usageThresholds }
    var refreshInterval: Duration { .seconds(settings.refreshIntervalSeconds) }

    private let client: any CSwapClient
    /// The CSwap path override, read live by the client's locator.
    @ObservationIgnored let cswapPath: CSwapPathSetting
    /// CSwap's own menu-bar app, checked now and then (nil when unknown).
    private(set) var cswapMenubar: CSwapMenubarStatus?
    @ObservationIgnored private var lastMenubarCheck: Date?
    private let switcher: SwitchCoordinator
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private var refreshLoop: Task<Void, Never>?

    let notifier: Notifier
    @ObservationIgnored private var planner = NotificationPlanner()
    /// The account a switch started in CSwapBar is heading to; its arrival isn't announced.
    @ObservationIgnored private var inAppSwitchTarget: AccountID?

    /// State of the global Privacy Mode shortcut (set by the hot-key owner).
    var privacyShortcutStatus: GlobalHotKey.Status = .off
    /// State of the global "open CSwapBar" shortcut.
    var openShortcutStatus: GlobalHotKey.Status = .off
    /// True while Settings records a new shortcut, so pressing the old one records instead of toggling.
    var isRecordingShortcut = false

    /// The page the Settings window shows. Set it before opening Settings to jump to a page.
    var settingsPane: SettingsPane = .appearance
    /// Set up by the app (nil in snapshot renders).
    var updater: Updater?
    /// "Open at login" (macOS keeps this state, not CSwapBar's settings).
    let loginItem = LoginItem()

    /// Local usage history (nil when it couldn't be opened, or in snapshot renders).
    @ObservationIgnored private(set) var history: HistoryStore?
    @ObservationIgnored let hasher: AccountHasher = {
        let key = "CSwapBar.history.salt"
        if let salt = UserDefaults.standard.string(forKey: key) { return AccountHasher(salt: salt) }
        let salt = AccountHasher.makeSalt()
        UserDefaults.standard.set(salt, forKey: key)
        return AccountHasher(salt: salt)
    }()
    @ObservationIgnored private var sampler = HistorySampler()
    @ObservationIgnored private var lastPrune: Date?
    @ObservationIgnored private var lastActiveKey: String?
    /// Bumped whenever history is written, so the dashboard can reload.
    private(set) var historyRevision = 0
    /// Runs `cswap auto` when Auto-switch is on (set up by the app).
    var autoSwitcher: AutoSwitchRunner?

    init(client: (any CSwapClient)? = nil, store: SettingsStore = SettingsStore(), notifier: Notifier = Notifier()) {
        let settings = store.load()
        let pathSetting = CSwapPathSetting(settings.cswapPath)
        let client = client ?? CSwapCLIClient(locator: CSwapBinaryLocator(configuredPathProvider: { pathSetting.value }))
        self.client = client
        self.cswapPath = pathSetting
        self.store = store
        self.notifier = notifier
        self.settings = settings
        self.switcher = SwitchCoordinator(client: client)
        if settings.notifications.enabled {
            Task { await notifier.requestPermission() }
        }
        startRefreshLoop()
    }

    private func startRefreshLoop() {
        refreshLoop?.cancel()
        refreshLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()
                guard let interval = self?.refreshInterval else { return }
                try? await Task.sleep(for: interval)
            }
        }
    }

    var accounts: [Account] { snapshot?.accounts ?? [] }
    var activeAccount: Account? { snapshot?.activeAccount }

    // MARK: - Privacy

    var privacy: PrivacyPreferences { settings.privacy }

    func togglePrivacyMode() {
        settings.privacy.privacyModeEnabled.toggle()
    }

    func presentation(for account: Account) -> AccountPresentation {
        AccountPresenter.present(account, preferences: settings.privacy)
    }

    var menuBarText: String? {
        MenuBarText.text(display: settings.menuBarDisplay, activeAccount: activeAccount, preferences: settings.privacy)
    }

    /// Re-detect CSwap (e.g. after installing or upgrading it).
    func reconnect() async {
        connection = .connecting
        await refresh()
    }

    var freshness: Freshness {
        if isRefreshing { return .updating }
        guard let lastSuccessfulRefresh else { return .unavailable }
        if lastRefreshError != nil { return .stale }
        let staleAfter = Double(refreshInterval.components.seconds) * 2.5
        return Date().timeIntervalSince(lastSuccessfulRefresh) > staleAfter ? .stale : .fresh
    }

    var isSwitching: Bool {
        if case .switching = switchState { return true }
        return false
    }

    // MARK: - Refresh

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        if case .connected = connection {} else {
            guard await connect() else { return }
        }

        do {
            let fresh = try await client.listAccounts()
            snapshot = fresh
            lastSuccessfulRefresh = Date()
            lastRefreshError = nil
            notify(about: fresh)
            recordHistory(fresh)
            await checkCSwapMenubarIfDue()
        } catch CSwapError.notInstalled {
            connection = .notInstalled
        } catch {
            // Keep the last good snapshot on screen, labelled stale.
            lastRefreshError = Self.describe(error)
        }
    }

    /// Looks for CSwap's own menu bar without running anything: its LaunchAgent
    /// file and the running-apps list. (Never `cswap menubar --service-status`,
    /// which runs `sfltool` system-wide.) Cheap, but still limited to every 10 minutes.
    func checkCSwapMenubarIfDue(force: Bool = false) async {
        if !force, let last = lastMenubarCheck, Date().timeIntervalSince(last) < 600 { return }
        lastMenubarCheck = Date()
        let installed = FileManager.default.fileExists(atPath: CSwapMenubarStatus.launchAgentPath())
        let running = NSWorkspace.shared.runningApplications.contains {
            CSwapMenubarStatus.isCSwapMenubarApp(bundleName: $0.bundleURL?.lastPathComponent, localizedName: $0.localizedName)
        }
        cswapMenubar = CSwapMenubarStatus(isRunning: running, startsAtLogin: installed)
    }

    private func connect() async -> Bool {
        do {
            connection = .connected(try await client.detect())
            return true
        } catch CSwapError.notInstalled {
            connection = .notInstalled
        } catch CSwapError.unsupportedVersion(let version) {
            connection = .unsupported(version)
        } catch {
            connection = .failed(Self.describe(error))
        }
        return false
    }

    // MARK: - Switching

    func switchTo(_ account: Account) async {
        guard !isSwitching else { return }
        switchState = .switching(account.id)
        inAppSwitchTarget = account.id
        pendingSwitchSource = .cswapbar

        let outcome = await switcher.switchTo(account.id)
        switch outcome {
        case .switched, .alreadyActive:
            switchState = .succeeded(account.id)
        case .failed(let failure):
            switchState = .failed(account.id, Self.describe(failure))
            inAppSwitchTarget = nil
            if let note = planner.switchFailed(to: account, preferences: settings.notifications, privacy: settings.privacy) {
                notifier.post(note, sound: settings.notifications.playSound)
            }
        }
        await refresh()

        // Let the success/failure state show briefly, then return to idle.
        let shown = switchState
        try? await Task.sleep(for: .seconds(4))
        if switchState == shown { switchState = .idle }
    }

    // MARK: - History

    /// Where the next observed account change came from (CSwapBar, or `cswap auto`).
    @ObservationIgnored var pendingSwitchSource: SwitchRecord.Source?

    /// Opens the history database. Called once by the app at launch.
    func startHistory(path: String = HistoryStore.defaultPath) {
        history = try? HistoryStore(path: path)
    }

    private func recordHistory(_ snapshot: AccountSnapshot) {
        let activeKey = snapshot.activeAccount.map { hasher.key(for: $0.id) }
        defer { lastActiveKey = activeKey ?? lastActiveKey }
        guard settings.historyEnabled, let history else { return }

        var wrote = false
        let samples = sampler.samples(from: snapshot, hasher: hasher)
        if (try? history.record(samples)) != nil, !samples.isEmpty { wrote = true }
        if let activeKey, let previous = lastActiveKey, activeKey != previous {
            let source = pendingSwitchSource ?? .external
            pendingSwitchSource = nil
            if (try? history.record(SwitchRecord(date: snapshot.capturedAt, from: previous, to: activeKey, source: source))) != nil {
                wrote = true
            }
        }
        if lastPrune.map({ Date().timeIntervalSince($0) > 3_600 }) ?? true {
            lastPrune = Date()
            try? history.prune(before: Date().addingTimeInterval(-HistoryStore.retention))
        }
        if wrote { historyRevision &+= 1 }
    }

    func clearHistory() {
        try? history?.clear()
        historyRevision &+= 1
    }

    /// Current names for stored keys, following the privacy settings. Accounts
    /// removed from CSwap since then show as "Removed account".
    func historyNames() -> [String: String] {
        var names: [String: String] = [:]
        for account in accounts {
            names[hasher.key(for: account.id)] = presentation(for: account).title
        }
        return names
    }

    /// CSV of the last 30 days for "Export History…".
    func historyCSV() -> String? {
        guard let history else { return nil }
        let since = Date().addingTimeInterval(-HistoryStore.retention)
        guard let samples = try? history.samples(since: since), let switches = try? history.switches(since: since) else { return nil }
        let names = historyNames()
        return HistoryCSV.make(samples: samples, switches: switches) { names[$0] ?? "Removed account" }
    }

    // MARK: - Auto-switch (cswap auto)

    @ObservationIgnored private var lastBlockedNotice: Date?

    /// Creates the runner and starts it if Auto-switch is on. Called once by the app.
    func startAutoSwitch() {
        let path = cswapPath
        let runner = AutoSwitchRunner(locate: { CSwapBinaryLocator(configuredPathProvider: { path.value }).locate() }) { [weak self] event in
            self?.handleAutoEvent(event)
        }
        runner.currentPreferences = { [weak self] in self?.settings.autoSwitch ?? AutoSwitchPreferences() }
        autoSwitcher = runner
        runner.apply(settings.autoSwitch)
    }

    private func handleAutoEvent(_ event: CSwapAutoEvent) {
        switch event.kind {
        case .switched:
            pendingSwitchSource = .auto
            Task { await refresh() }
        case .blocked:
            // At most once an hour.
            guard lastBlockedNotice.map({ Date().timeIntervalSince($0) > 3_600 }) ?? true,
                  settings.notifications.enabled, settings.notifications.switchAlerts else { return }
            lastBlockedNotice = Date()
            notifier.post(PlannedNotification(kind: .switched, title: "No account to switch to",
                                              body: "CSwap's auto-switch wanted to switch, but every account is near its limit."),
                          sound: settings.notifications.playSound)
        default:
            break
        }
    }

    // MARK: - Recommendation

    /// The "best next account" hint, when it's worth showing.
    var recommendation: AccountRecommendation? {
        guard settings.showRecommendation,
              let best = AccountRecommendation.best(in: accounts),
              best.isWorthShowing(thresholds: thresholds) else { return nil }
        return best
    }

    // MARK: - Notifications

    private func notify(about snapshot: AccountSnapshot) {
        let notes = planner.process(snapshot, preferences: settings.notifications,
                                    privacy: settings.privacy, inAppSwitchTarget: inAppSwitchTarget)
        if let target = inAppSwitchTarget, snapshot.activeAccount?.id == target {
            inAppSwitchTarget = nil
        }
        for note in notes {
            notifier.post(note, sound: settings.notifications.playSound)
        }
    }

    /// Settings → Notifications → "Send a test notification".
    func sendTestNotification() {
        let text = settings.privacy.shouldMask(.notificationDetails)
            ? "Notifications are working. Details are hidden while Privacy Mode is on."
            : "Notifications are working. You'll hear from CSwapBar when usage crosses your levels."
        notifier.post(PlannedNotification(kind: .usage, title: "CSwapBar", body: text),
                      sound: settings.notifications.playSound)
    }

    // MARK: - Updates

    /// Starts update checks. Called once by the app at launch.
    func startUpdates() {
        let updater = Updater(settings: { [weak self] in self?.settings.updates ?? UpdatePreferences() }) { [weak self] update in
            self?.announce(update)
        }
        self.updater = updater
        updater.startAutomaticChecks()
    }

    private func announce(_ update: AvailableUpdate) {
        guard settings.notifications.enabled else { return }
        notifier.post(PlannedNotification(kind: .update, title: "CSwapBar \(update.version) is available",
                                          body: "Open CSwapBar to install it. You're on \(Updater.currentVersionString)."),
                      sound: false)
    }

    // MARK: - Messages

    static func describe(_ error: any Error) -> String {
        switch error {
        case let failure as SwitchFailure:
            switch failure {
            case .busy: return "Another switch is in progress."
            case .accountNotFound: return "That account is no longer in CSwap."
            case .verificationFailed: return "CSwap didn't confirm the switch. The active account is unchanged."
            case .timedOut: return "CSwap took too long to switch."
            case .cswap(let error): return describe(error)
            }
        case let error as CSwapError:
            switch error {
            case .notInstalled: return "CSwap isn't installed, or isn't at the path chosen in Settings."
            case .unsupportedVersion(let version): return "CSwap \(version) is too old. CSwapBar needs \(CSwapVersion.minimumSupported) or newer."
            case .unsupportedSchema(let schema): return "This CSwap uses JSON schema v\(schema). Update CSwapBar."
            case .cliError(_, let message): return message
            case .commandFailed(_, let message): return message
            case .invalidOutput: return "CSwap returned output CSwapBar couldn't read."
            case .timedOut: return "CSwap didn't respond in time."
            }
        default:
            return error.localizedDescription
        }
    }
}
