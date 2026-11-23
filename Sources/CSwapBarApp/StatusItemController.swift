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
    private var widgets: DesktopWidgetController?

    init(model: AppModel) {
        self.model = model
        super.init()

        let root = PopoverView(model: model)
            .environment(\.openAppSettings, { [weak self] in self?.openSettings() })
        let host = NSHostingController(rootView: root)
        // The popover tracks the content's ideal size as it changes.
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.behavior = .transient
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
    }

    // MARK: Popover

    @objc private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    func showPopover() {
        guard let button = statusItem.button else { return }
        applyAppearance()
        // Start at the content's ideal size; preferredContentSize tracks it from here on.
        if let view = popover.contentViewController?.view {
            popover.contentSize = view.fittingSize
        }
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
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

    // MARK: Settings window

    func openSettings() {
        popover.performClose(nil)
        if settingsWindow == nil {
            let args = CommandLine.arguments
            let pane = args.firstIndex(of: "--pane").flatMap { $0 + 1 < args.count ? SettingsPane(rawValue: args[$0 + 1]) : nil }
            let host = NSHostingController(rootView: SettingsView(model: model, initialPane: pane ?? .appearance)
                .environment(\.resetWidgetPositions, { [weak self] in self?.widgets?.resetPositions() }))
            let window = NSWindow(contentViewController: host)
            window.styleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.title = "CSwapBar Settings"
            window.isReleasedWhenClosed = false
            window.setContentSize(NSSize(width: SettingsShellMetrics.width, height: 640))
            window.center()
            settingsWindow = window
        }
        applyAppearance()
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
        if let path = ProcessInfo.processInfo.environment["CSWAPBAR_CAPTURE"] {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let view = self?.settingsWindow?.contentView,
                      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path + "-settings.png"))
            }
        }
    }

    // MARK: Menu-bar label

    private func updateStatusItem() {
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
        if model.settings.theme.adaptiveVariants != nil {
            appearance = nil   // follow macOS
        } else {
            let dark = model.settings.theme.palette(systemIsDark: true).isDark
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
            _ = model.settings.theme
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

private struct ResetWidgetPositionsKey: EnvironmentKey {
    static let defaultValue: @MainActor @Sendable () -> Void = {}
}

extension EnvironmentValues {
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
