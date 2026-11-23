import AppKit
import CSwapBarCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var statusController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar only: no Dock icon, even when run via `swift run` without Info.plist.
        NSApp.setActivationPolicy(.accessory)

        // Developer snapshot mode renders an image and exits; don't touch CSwap.
        if PopoverRenderer.runIfRequested() { return }

        let model = AppModel()
        self.model = model
        let controller = StatusItemController(model: model)
        statusController = controller

        // Developer aid: open the popover or Settings right away (layout checks).
        if CommandLine.arguments.contains("--open-popover") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { controller.showPopover() }
        }
        if CommandLine.arguments.contains("--open-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { controller.openSettings() }
        }
    }
}
