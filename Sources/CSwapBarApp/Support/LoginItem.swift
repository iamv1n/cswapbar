import Observation
import ServiceManagement

/// "Open at login", backed by `SMAppService.mainApp`. macOS owns the state
/// (and shows it in System Settings → General → Login Items), so nothing is
/// stored in CSwapBar's own settings.
@MainActor
@Observable
final class LoginItem {
    enum State: Equatable {
        case on
        case off
        /// Registered, but the user must allow it in System Settings.
        case needsApproval
        /// Running outside an app bundle (e.g. `swift run`).
        case unavailable
    }

    private(set) var state: State = .off
    private(set) var lastError: String?

    init() { refresh() }

    func refresh() {
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            state = .unavailable
            return
        }
        state = switch SMAppService.mainApp.status {
        case .enabled: .on
        case .requiresApproval: .needsApproval
        case .notRegistered, .notFound: .off
        @unknown default: .off
        }
    }

    func set(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
