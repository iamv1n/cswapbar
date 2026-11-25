import AppKit
import CSwapBarCore
import Observation
import SwiftUI

/// Owns the Usage Island window: a borderless, non-activating panel at the
/// top-center of the main screen. It never takes focus from the app you're in.
@MainActor
final class UsageIslandController {
    private let model: AppModel
    private let onOpen: () -> Void
    private let state = UsageIslandState()
    private var panel: NSPanel?
    private var geometry: IslandGeometry?
    private var collapseTask: Task<Void, Never>?
    private var screenObserver: NSObjectProtocol?
    /// True while the popover is open; the island then stays collapsed under it.
    var isPopoverShown: () -> Bool = { false }

    init(model: AppModel, onOpen: @escaping () -> Void) {
        self.model = model
        self.onOpen = onOpen
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.rebuild() }
        }
        update()
        observe()
    }

    /// Whether the chosen style could hug a notch on the current main screen.
    static var mainScreenHasNotch: Bool {
        (NSScreen.screens.first?.safeAreaInsets.top ?? 0) > 0
    }

    // MARK: Visibility

    /// When on, the island replaces the menu bar icon, so it always shows (even
    /// while CSwap is disconnected) as the way into CSwapBar.
    private var shouldShow: Bool { model.settings.usageIsland.enabled }

    /// Where the popover hangs from while the island is CSwapBar's home.
    var anchorView: NSView? {
        guard let panel, panel.isVisible else { return nil }
        return panel.contentView
    }

    /// Shrinks to the collapsed size right away (before the popover opens below it).
    func collapseNow() {
        collapseTask?.cancel()
        state.expanded = false
        if let geometry { panel?.setFrame(geometry.collapsed, display: true) }
    }

    private func observe() {
        withObservationTracking {
            _ = model.settings.usageIsland
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.update()
                self?.observe()
            }
        }
    }

    private func update() {
        if shouldShow {
            if panel == nil || geometry != currentGeometry() { rebuild() }
            panel?.orderFrontRegardless()
        } else {
            panel?.orderOut(nil)
        }
    }

    // MARK: Window

    private func currentGeometry() -> IslandGeometry? {
        // The first screen holds the menu bar.
        guard let screen = NSScreen.screens.first else { return nil }
        let notchTop = screen.safeAreaInsets.top
        let notchWidth: CGFloat? = notchTop > 0
            ? screen.frame.width - (screen.auxiliaryTopLeftArea?.width ?? 0) - (screen.auxiliaryTopRightArea?.width ?? 0)
            : nil
        let menuBar = notchTop > 0 ? notchTop : max(screen.frame.maxY - screen.visibleFrame.maxY, NSStatusBar.system.thickness)
        return IslandGeometry(screen: screen.frame, menuBarHeight: menuBar, notchWidth: notchWidth,
                              style: model.settings.usageIsland.style)
    }

    private func rebuild() {
        panel?.orderOut(nil)
        panel = nil
        guard shouldShow, let geometry = currentGeometry() else { return }
        self.geometry = geometry
        state.expanded = false

        let root = UsageIslandView(model: model, state: state, geometry: geometry) { [weak self] in
            self?.collapseNow()
            self?.onOpen()
        }
        let host = IslandHostingView(rootView: root)
        host.onHover = { [weak self] inside in self?.hover(inside) }

        let panel = NSPanel(contentRect: geometry.collapsed, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.contentView = host
        panel.setAccessibilityLabel("CSwapBar Usage Island")
        self.panel = panel
        panel.orderFrontRegardless()
    }

    // MARK: Hover

    private func hover(_ inside: Bool) {
        guard let panel, let geometry else { return }
        collapseTask?.cancel()
        if inside {
            guard !state.expanded, !isPopoverShown() else { return }
            // Grow the window first (transparent), then let SwiftUI animate the shape.
            panel.setFrame(geometry.expanded, display: true)
            state.expanded = true
        } else {
            collapseTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(250))
                guard !Task.isCancelled, let self else { return }
                self.state.expanded = false
                try? await Task.sleep(for: .milliseconds(350))   // let the shape shrink first
                guard !Task.isCancelled, !self.state.expanded else { return }
                self.panel?.setFrame(geometry.collapsed, display: true)
            }
        }
    }
}

/// Hosting view that reports hover even though the panel is never key, and
/// takes the first click (so buttons work without focusing the panel first).
private final class IslandHostingView<Content: View>: NSHostingView<Content> {
    var onHover: (Bool) -> Void = { _ in }
    private var area: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        self.area = area
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        onHover(true)
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        onHover(false)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
