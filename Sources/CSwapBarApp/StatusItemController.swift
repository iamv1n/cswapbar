import AppKit
import CSwapBarCore
import Observation
import SwiftUI

/// Owns the menu-bar item, its popover, and the Settings window.
///
/// Uses NSStatusItem + NSPopover instead of SwiftUI's MenuBarExtra: the popover
/// follows the SwiftUI content's size in both directions (MenuBarExtra windows
/// grow but don't shrink), so the height always matches the visible accounts.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    private let model: AppModel
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var settingsWindow: NSWindow?
    private var dashboardWindow: NSWindow?
    private var outsideClickMonitor: Any?
    private var resignObserver: NSObjectProtocol?
    private var widgets: DesktopWidgetController?
    private var island: UsageIslandController?
    private var privacyHotKey: GlobalHotKey?
    private var openHotKey: GlobalHotKey?
    private var registeredPrivacy: KeyShortcut?
    private var registeredOpen: KeyShortcut?

    init(model: AppModel) {
        self.model = model
        super.init()

        let root = PopoverView(model: model)
            .environment(\.openAppSettings, { [weak self] in self?.openSettings() })
            .environment(\.closePopover, { [weak self] in self?.closePopover() })
            .environment(\.openDashboard, { [weak self] in self?.openDashboard() })
        let host = NSHostingController(rootView: root)
        // The popover tracks the content's ideal size as it changes.
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        // Closed by CSwapBar itself (see `installDismissMonitors`) so the popover can
        // stay open while you use the Settings window, but still closes on clicks in
        // other apps, app switches, and Esc.
        popover.behavior = .applicationDefined
        popover.animates = true
        popover.delegate = self

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
            button.imagePosition = .imageLeading
        }
        updateStatusItem()
        observeModel()
        widgets = DesktopWidgetController(model: model) { [weak self] in self?.openSettings() }

        // Clicking a notification opens the popover.
        model.notifier.onOpen = { [weak self] in self?.showPopover() }

        model.startUpdates()
        island = UsageIslandController(model: model) { [weak self] in self?.togglePopover() }
        island?.isPopoverShown = { [weak self] in self?.popover.isShown ?? false }
        model.startHistory()
        model.startAutoSwitch()

        privacyHotKey = GlobalHotKey { [weak model] in model?.togglePrivacyMode() }
        openHotKey = GlobalHotKey { [weak self] in self?.togglePopover() }
        updateHotKeys()
        observeHotKeySettings()
    }

    // MARK: Global shortcuts

    private func updateHotKeys() {
        let settings = model.settings
        let recording = model.isRecordingShortcut
        if let status = register(privacyHotKey, settings.privacyShortcutEnabled && !recording ? settings.privacyShortcut : nil,
                                 last: &registeredPrivacy), !recording {
            model.privacyShortcutStatus = status
        }
        if let status = register(openHotKey, settings.openShortcutEnabled && !recording ? settings.openShortcut : nil,
                                 last: &registeredOpen), !recording {
            model.openShortcutStatus = status
        }
    }

    /// Re-registers only when the shortcut changed. Returns the new status, or nil if unchanged.
    private func register(_ hotKey: GlobalHotKey?, _ wanted: KeyShortcut?, last: inout KeyShortcut?) -> GlobalHotKey.Status? {
        guard let hotKey else { return nil }
        guard wanted != last || (hotKey.status == .off && wanted != nil) else { return nil }
        last = wanted
        return hotKey.set(wanted)
    }

    private func observeHotKeySettings() {
        withObservationTracking {
            _ = model.settings.privacyShortcutEnabled
            _ = model.settings.privacyShortcut
            _ = model.settings.openShortcutEnabled
            _ = model.settings.openShortcut
            _ = model.isRecordingShortcut
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateHotKeys()
                self?.observeHotKeySettings()
            }
        }
    }

    // MARK: Popover

    @objc func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    func showPopover() {
        // The island is CSwapBar's home when it's on; otherwise the menu bar icon.
        let anchor: NSView
        if model.settings.usageIsland.enabled, let islandView = island?.anchorView {
            island?.collapseNow()
            anchor = islandView
        } else if let button = statusItem.button {
            anchor = button
        } else {
            return
        }
        applyAppearance()
        // Start at the content's ideal size; preferredContentSize tracks it from here on.
        if let view = popover.contentViewController?.view {
            popover.contentSize = view.fittingSize
        }
        NSApp.activate()
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        installDismissMonitors()
        if CommandLine.arguments.contains("--debug-layout") { logSize("shown") }
    }

    /// Developer aid (`--debug-layout`): log the popover size now and shortly after.
    private func logSize(_ label: String) {
        NSLog("CSwapBar layout [%@]: popover %@", label, NSStringFromSize(popover.contentSize))
        if let path = ProcessInfo.processInfo.environment["CSWAPBAR_CAPTURE"],
           let view = popover.contentViewController?.view,
           let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path + "-\(label).png"))
        }
        if label == "shown" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.logSize("settled") }
        }
        // `CSWAPBAR_TEST_RESIZE=1`: switch layout while open to verify the popover shrinks and grows.
        if ProcessInfo.processInfo.environment["CSWAPBAR_TEST_RESIZE"] == "1" {
            if label == "settled" {
                model.settings.cardLayout = .list
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.logSize("after-list") }
            } else if label == "after-list" {
                model.settings.cardLayout = .meters
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.logSize("after-meters") }
            }
        }
    }

    func closePopover() {
        if popover.isShown { popover.performClose(nil) }
    }

    /// Closes the popover on clicks in other apps (a global monitor sees only
    /// those, and needs no permissions) and when another app becomes active.
    /// Clicks in CSwapBar's own windows, like Settings, leave it open.
    private func installDismissMonitors() {
        removeDismissMonitors()
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePopover() }
        }
        resignObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closePopover() }
        }
    }

    private func removeDismissMonitors() {
        if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
        if let resignObserver { NotificationCenter.default.removeObserver(resignObserver) }
        outsideClickMonitor = nil
        resignObserver = nil
    }

    func popoverDidClose(_ notification: Notification) {
        removeDismissMonitors()
    }

    // MARK: Settings window

    /// Opens Settings next to the popover; both stay visible so changes show live.
    func openSettings() {
        if settingsWindow == nil {
            let args = CommandLine.arguments
            let pane = args.firstIndex(of: "--pane").flatMap { $0 + 1 < args.count ? SettingsPane(rawValue: args[$0 + 1]) : nil }
            let host = NSHostingController(rootView: SettingsView(model: model, initialPane: pane)
                .environment(\.resetWidgetPositions, { [weak self] in self?.widgets?.resetPositions() })
                .environment(\.openDashboard, { [weak self] in self?.openDashboard() }))
            // Only the minimum size comes from SwiftUI, so the user can resize freely above it.
            host.sizingOptions = [.minSize]
            let window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = "CSwapBar Settings"
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            // Open on the current desktop (Space) instead of jumping back to where it was last.
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.contentMinSize = NSSize(width: SettingsShellMetrics.width, height: SettingsShellMetrics.minHeight)
            window.setContentSize(NSSize(width: SettingsShellMetrics.width, height: SettingsShellMetrics.defaultHeight))
            // Remember the size and position the user picks.
            let autosaveName = "CSwapBarSettingsWindow"
            if !window.setFrameUsingName(autosaveName) { window.center() }
            window.setFrameAutosaveName(autosaveName)
            settingsWindow = window
        }
        applyAppearance()
        bringSettingsToFront()
        if let path = ProcessInfo.processInfo.environment["CSWAPBAR_CAPTURE"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let view = self?.settingsWindow?.contentView,
                      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path + "-settings.png"))
            }
        }
    }

    // MARK: Dashboard window

    func openDashboard() {
        if dashboardWindow == nil {
            let host = NSHostingController(rootView: DashboardView(model: model))
            host.sizingOptions = [.minSize]
            let window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = "CSwapBar Usage History"
            window.isReleasedWhenClosed = false
            window.hidesOnDeactivate = false
            window.collectionBehavior.insert(.moveToActiveSpace)
            window.setContentSize(NSSize(width: 900, height: 720))
            let autosaveName = "CSwapBarDashboardWindow"
            if !window.setFrameUsingName(autosaveName) { window.center() }
            window.setFrameAutosaveName(autosaveName)
            dashboardWindow = window
        }
        dashboardWindow?.appearance = settingsWindow?.appearance ?? popover.appearance
        NSApp.activate(ignoringOtherApps: true)
        dashboardWindow?.makeKeyAndOrderFront(nil)
        dashboardWindow?.orderFrontRegardless()
    }

    /// An accessory app (no Dock icon) must ask harder to come forward: on macOS 14+
    /// plain `activate()` is only a request, and macOS may keep the previous app in front.
    private func bringSettingsToFront() {
        guard let window = settingsWindow else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    // MARK: Menu-bar label

    private var islandWasOn: Bool?

    private func updateStatusItem() {
        // Either the menu bar icon or the Usage Island, never both.
        let islandOn = model.settings.usageIsland.enabled
        if let islandWasOn, islandWasOn != islandOn { closePopover() }   // its anchor just went away
        islandWasOn = islandOn
        statusItem.isVisible = !islandOn
        guard let button = statusItem.button else { return }
        let privacy = MenuBarText.showsPrivacyIndicator(model.privacy)
        button.image = Self.statusImage(privacy: privacy)
        let text = model.menuBarText ?? ""
        button.title = text.isEmpty ? "" : " \(text)"
        button.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        button.setAccessibilityLabel(privacy ? "CSwapBar, Privacy Mode on" : "CSwapBar")
    }

    /// CSwapBar's arrows, plus an eye-slash while Privacy Mode is on. Template, so it tints like other menu-bar icons.
    private static func statusImage(privacy: Bool) -> NSImage? {
        let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
        guard let swap = LogoImages.statusItemTemplate() else { return nil }
        guard privacy, let eye = NSImage(systemSymbolName: "eye.slash", accessibilityDescription: "Privacy Mode")?
            .withSymbolConfiguration(config) else {
            swap.isTemplate = true
            return swap
        }
        let gap: CGFloat = 3
        let size = NSSize(width: swap.size.width + gap + eye.size.width, height: max(swap.size.height, eye.size.height))
        let image = NSImage(size: size, flipped: false) { _ in
            swap.draw(in: NSRect(x: 0, y: (size.height - swap.size.height) / 2, width: swap.size.width, height: swap.size.height))
            eye.draw(in: NSRect(x: swap.size.width + gap, y: (size.height - eye.size.height) / 2, width: eye.size.width, height: eye.size.height))
            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: Appearance

    /// Popover and Settings chrome follow the theme's light/dark base.
    private func applyAppearance() {
        let appearance: NSAppearance?
        if model.settings.followsSystemAppearance {
            appearance = nil   // follow macOS
        } else {
            let dark = model.settings.activePalette(systemIsDark: true).isDark
            appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        }
        popover.appearance = appearance
        settingsWindow?.appearance = appearance
    }

    /// Re-run when anything shown in the menu bar or chrome changes.
    private func observeModel() {
        withObservationTracking {
            _ = model.menuBarText
            _ = model.privacy.privacyModeEnabled
            _ = model.settings.usageIsland.enabled
            _ = model.settings.theme
            _ = model.settings.customThemeID
            _ = model.settings.customThemes
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.updateStatusItem()
                self?.applyAppearance()
                self?.observeModel()
            }
        }
    }
}

// MARK: - Environment

private struct OpenAppSettingsKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

private struct OpenDashboardKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

private struct ClosePopoverKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

private struct ResetWidgetPositionsKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
    /// Opens the usage history dashboard.
    var openDashboard: @MainActor @Sendable () -> Void {
        get { self[OpenDashboardKey.self] }
        set { self[OpenDashboardKey.self] = newValue }
    }

    /// Closes the menu-bar popover (Esc).
    var closePopover: @MainActor @Sendable () -> Void {
        get { self[ClosePopoverKey.self] }
        set { self[ClosePopoverKey.self] = newValue }
    }

    /// Moves desktop widgets back to their default spots.
    var resetWidgetPositions: @MainActor @Sendable () -> Void {
        get { self[ResetWidgetPositionsKey.self] }
        set { self[ResetWidgetPositionsKey.self] = newValue }
    }

    /// Opens the Settings window (provided by StatusItemController).
    var openAppSettings: @MainActor @Sendable () -> Void {
        get { self[OpenAppSettingsKey.self] }
        set { self[OpenAppSettingsKey.self] = newValue }
    }
}
