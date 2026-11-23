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
        }
    }

    let thresholds = UsageThresholds.default
    var refreshInterval: Duration { .seconds(settings.refreshIntervalSeconds) }

    private let client: any CSwapClient
    private let switcher: SwitchCoordinator
    @ObservationIgnored private let store: SettingsStore
    @ObservationIgnored private var refreshLoop: Task<Void, Never>?

    init(client: any CSwapClient = CSwapCLIClient(), store: SettingsStore = SettingsStore()) {
        self.client = client
        self.store = store
        self.settings = store.load()
        self.switcher = SwitchCoordinator(client: client)
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
            snapshot = try await client.listAccounts()
            lastSuccessfulRefresh = Date()
            lastRefreshError = nil
        } catch CSwapError.notInstalled {
            connection = .notInstalled
        } catch {
            // Keep the last good snapshot on screen, labelled stale.
            lastRefreshError = Self.describe(error)
        }
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

        let outcome = await switcher.switchTo(account.id)
        switch outcome {
        case .switched, .alreadyActive:
            switchState = .succeeded(account.id)
        case .failed(let failure):
            switchState = .failed(account.id, Self.describe(failure))
        }
        await refresh()

        // Let the success/failure state show briefly, then return to idle.
        let shown = switchState
        try? await Task.sleep(for: .seconds(4))
        if switchState == shown { switchState = .idle }
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
            case .notInstalled: return "CSwap isn't installed."
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
