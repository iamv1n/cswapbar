import AppKit
import CSwapBarCore
import Observation
import UserNotifications

/// Posts CSwapBar's notifications through the macOS notification center.
///
/// Notifications need a real app bundle: under `swift run` there's no bundle
/// identifier and `UNUserNotificationCenter` would crash, so everything is a
/// no-op there and Settings explains why.
@MainActor
@Observable
final class Notifier: NSObject {
    enum Permission: Equatable {
        case unknown
        case allowed
        case denied
        /// Running outside an app bundle (e.g. `swift run`).
        case unsupported
    }

    private(set) var permission: Permission = .unknown
    /// Called when the user clicks a notification.
    @ObservationIgnored var onOpen: () -> Void = {}

    static var isSupported: Bool {
        Bundle.main.bundleURL.pathExtension == "app" && Bundle.main.bundleIdentifier != nil
    }

    private let live: Bool

    private var center: UNUserNotificationCenter? {
        live && Self.isSupported ? UNUserNotificationCenter.current() : nil
    }

    /// - Parameter live: `false` for snapshot renders, which must never prompt or post.
    init(live: Bool = true) {
        self.live = live
        super.init()
        if let center {
            center.delegate = self
        } else {
            // Snapshot renders show Settings as a real user would see it.
            permission = live ? .unsupported : .allowed
        }
    }

    /// Asks once; macOS remembers the answer and won't show the prompt again.
    func requestPermission() async {
        guard let center else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
        await refreshPermission()
    }

    func refreshPermission() async {
        guard let center else { return }
        let status = await center.notificationSettings().authorizationStatus
        switch status {
        case .authorized, .provisional, .ephemeral: permission = .allowed
        case .denied: permission = .denied
        default: permission = .unknown
        }
    }

    func post(_ notification: PlannedNotification, sound: Bool) {
        guard let center else { return }
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.threadIdentifier = notification.kind.rawValue
        if sound { content.sound = .default }
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request)
    }

    /// Removes delivered notifications from Notification Center. Used when
    /// Privacy Mode turns on, since older ones may name accounts.
    func clearDelivered() {
        center?.removeAllDeliveredNotifications()
    }

    /// Opens CSwapBar's page in System Settings → Notifications.
    func openSystemSettings() {
        let id = Bundle.main.bundleIdentifier ?? ""
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(id)")
            ?? URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")!
        NSWorkspace.shared.open(url)
    }
}

extension Notifier: UNUserNotificationCenterDelegate {
    /// Show banners even while CSwapBar is the active app (it usually is right
    /// after using the popover).
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        await MainActor.run { onOpen() }
    }
}
