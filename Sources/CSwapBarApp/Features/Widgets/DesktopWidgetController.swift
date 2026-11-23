import AppKit
import CSwapBarCore
import Observation
import SwiftUI

/// Shows the enabled desktop widgets as borderless panels that sit on the
/// desktop (or float on top), can be dragged anywhere, and remember where
/// they were left. In-app panels, so no WidgetKit extension or signing team
/// is needed.
@MainActor
final class DesktopWidgetController {
    private let model: AppModel
    private let openSettings: @MainActor () -> Void
    private var panels: [DesktopWidgetKind: NSPanel] = [:]

    init(model: AppModel, openSettings: @escaping @MainActor () -> Void) {
        self.model = model
        self.openSettings = openSettings
        sync()
        observe()
    }

    /// Show/hide panels to match settings and fit each to its content.
    private func sync() {
        let wanted = model.settings.desktopWidgets
        for (kind, panel) in panels where !wanted.contains(kind) {
            panel.orderOut(nil)
            panels[kind] = nil
        }
        for (index, kind) in wanted.enumerated() where panels[kind] == nil {
            panels[kind] = makePanel(kind, index: index)
        }
        let level = model.settings.widgetsFloatOnTop
            ? NSWindow.Level.floating
            : NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        for panel in panels.values {
            panel.level = level
            fit(panel)
        }
    }

    func resetPositions() {
        for (index, kind) in model.settings.desktopWidgets.enumerated() {
            guard let panel = panels[kind] else { continue }
            panel.setFrameOrigin(defaultOrigin(for: panel.frame.size, index: index))
        }
    }

    private func makePanel(_ kind: DesktopWidgetKind, index: Int) -> NSPanel {
        let root = DesktopWidgetView(kind: kind, model: model)
            .contextMenu {
                Button("Open CSwapBar Settings…") { [openSettings] in openSettings() }
                Button("Hide This Widget") { [weak self] in self?.hide(kind) }
            }
        let host = DraggableHostingView(rootView: root)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: kind.size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = host
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        panel.setAccessibilityLabel("CSwapBar \(kind.title) widget")

        fit(panel)
        let autosave = "CSwapBar.widget.\(kind.rawValue)"
        if !panel.setFrameUsingName(autosave) {
            panel.setFrameOrigin(defaultOrigin(for: panel.frame.size, index: index))
        }
        panel.setFrameAutosaveName(autosave)
        panel.orderFrontRegardless()
        return panel
    }

    /// Resize to the SwiftUI content, keeping the top-left corner in place.
    private func fit(_ panel: NSPanel) {
        guard let view = panel.contentView else { return }
        let size = view.fittingSize
        guard size.width > 0, size.height > 0, size != panel.frame.size else { return }
        var frame = panel.frame
        frame.origin.y += frame.height - size.height
        frame.size = size
        panel.setFrame(frame, display: true)
    }

    /// Stack widgets down the top-right of the main screen.
    private func defaultOrigin(for size: CGSize, index: Int) -> CGPoint {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin: CGFloat = 24
        let above = model.settings.desktopWidgets.prefix(index).reduce(CGFloat(0)) { $0 + $1.size.height + 16 }
        return CGPoint(x: visible.maxX - size.width - margin, y: visible.maxY - margin - above - size.height)
    }

    private func hide(_ kind: DesktopWidgetKind) {
        model.settings.desktopWidgets.removeAll { $0 == kind }
    }

    private func observe() {
        withObservationTracking {
            _ = model.settings
            _ = model.accounts
            _ = model.connection
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.sync()
                self?.observe()
            }
        }
    }
}

/// Lets a drag anywhere on the widget move its window.
///
/// `isMovableByWindowBackground` alone is unreliable here: SwiftUI (and the
/// `.contextMenu` modifier in particular) claims the left mouse-down, so the
/// window server never starts a background drag. Widgets have no clickable
/// controls, so hand every plain left-click straight to the window drag.
private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        // Control-click is a right-click: let SwiftUI show the context menu.
        if event.modifierFlags.contains(.control) {
            super.mouseDown(with: event)
            return
        }
        window?.performDrag(with: event)
    }
}
