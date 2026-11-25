import AppKit
import CSwapBarCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var statusController: StatusItemController?

    /// Stop `cswap auto` with the app (its watchdog would also catch this).
    func applicationWillTerminate(_ notification: Notification) {
        model?.autoSwitcher?.stop()
    }

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
        // Developer aid: check now and install a newer release if there is one
        // (the same as Settings → Check Now → Install and Restart).
        if CommandLine.arguments.contains("--install-update-now") {
            Task { @MainActor in
                guard let updater = model.updater else { return }
                await updater.check(userInitiated: true)
                NSLog("CSwapBar update check: %@", String(describing: updater.state))
                if let update = updater.availableUpdate { await updater.install(update) }
                NSLog("CSwapBar update result: %@", String(describing: updater.state))
            }
        }
        // Developer aid: run `cswap auto` in dry-run mode (never switches) without
        // changing saved settings. Ignored unless CSWAPBAR_AUTO_DRY_RUN=1 is set too.
        if CommandLine.arguments.contains("--auto-dry-run"),
           ProcessInfo.processInfo.environment["CSWAPBAR_AUTO_DRY_RUN"] == "1" {
            var prefs = model.settings.autoSwitch
            prefs.enabled = true
            model.autoSwitcher?.apply(prefs)
        }
        if CommandLine.arguments.contains("--open-settings") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { controller.openSettings() }
        }
    }
}
