import AppKit
import CSwapBarCore
import SwiftUI

/// Developer tool: renders UI with sample data to a PNG and exits.
///
///     CSwapBar --render-popover out.png [--accounts 6] [--theme paper] [--accent teal]
///              [--layout rings] [--font rounded] [--size large] [--light] [--privacy] [--compact]
///     CSwapBar --render-settings out.png [--pane appearance] [same theme flags]
///
/// For checking layout without clicking the menu bar, and for README screenshots.
@MainActor
enum PopoverRenderer {
    /// Writes an .iconset (for `iconutil`) plus logo PNGs into `directory`.
    static func renderLogo(into directory: URL) {
        let iconset = directory.appendingPathComponent("AppIcon.iconset")
        try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let name = scale == 1 ? "icon_\(points)x\(points).png" : "icon_\(points)x\(points)@2x.png"
                write(AppIconView(size: CGFloat(points)), scale: CGFloat(scale), to: iconset.appendingPathComponent(name))
            }
        }
        write(AppIconView(size: 512), scale: 2, to: directory.appendingPathComponent("logo.png"))
        write(AppIconView(size: 256), scale: 1, to: directory.appendingPathComponent("logo-256.png"))
        print("logo -> \(directory.path)")
    }

    private static func write<V: View>(_ view: V, scale: CGFloat, to url: URL) {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.nsImage, let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    /// Returns true when a render was requested (the app then exits when done).
    @discardableResult
    static func runIfRequested() -> Bool {
        let args = CommandLine.arguments
        if let flag = args.firstIndex(of: "--render-logo"), flag + 1 < args.count {
            renderLogo(into: URL(fileURLWithPath: args[flag + 1]))
            exit(0)
        }
        let popoverFlag = args.firstIndex(of: "--render-popover")
        let settingsFlag = args.firstIndex(of: "--render-settings")
        let widgetFlag = args.firstIndex(of: "--render-widget")
        guard let flag = popoverFlag ?? settingsFlag ?? widgetFlag, flag + 1 < args.count else { return false }
        let output = URL(fileURLWithPath: args[flag + 1])

        func value(_ name: String) -> String? {
            args.firstIndex(of: name).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        }

        // Isolated settings so rendering never touches the user's saved preferences.
        let suite = "CSwapBar.render"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        let store = SettingsStore(defaults: defaults)
        var settings = AppSettings()
        if let v = value("--theme").flatMap(ThemeChoice.init(rawValue:)) { settings.theme = v }
        if let v = value("--accent").flatMap(AccentChoice.init(rawValue:)) { settings.accent = v }
        if let v = value("--layout").flatMap(CardLayout.init(rawValue:)) {
            settings.cardLayout = v
            settings.accountsPerPage = v.suggestedPageSize
        }
        if let v = value("--per-page").flatMap(Int.init) { settings.accountsPerPage = v }
        if let v = value("--font").flatMap(FontChoice.init(rawValue:)) { settings.font = v }
        if let v = value("--size").flatMap(TextSizeChoice.init(rawValue:)) { settings.textSize = v }
        settings.privacy.privacyModeEnabled = args.contains("--privacy")
        settings.compactCards = args.contains("--compact")
        store.save(settings)

        let count = value("--accounts").flatMap(Int.init) ?? 4
        let scheme: ColorScheme = args.contains("--light") ? .light : .dark
        let pane = value("--pane").flatMap(SettingsPane.init(rawValue:)) ?? .appearance

        Task { @MainActor in
            let model = AppModel(client: SampleCSwapClient(count: count), store: store)
            await model.refresh()

            let widgetKind = value("--kind").flatMap(DesktopWidgetKind.init(rawValue:)) ?? .active
            let content: AnyView = if settingsFlag != nil {
                AnyView(SettingsView(model: model, initialPane: pane))
            } else if widgetFlag != nil {
                AnyView(DesktopWidgetView(kind: widgetKind, model: model).padding(20))
            } else {
                AnyView(PopoverView(model: model))
            }
            let fixedHeight = value("--height").flatMap(Double.init).map { CGFloat($0) }
            let renderer = ImageRenderer(content: content
                .environment(\.colorScheme, scheme)
                .environment(\.isSnapshot, true)
                .environment(\.snapshotHeight, fixedHeight))
            renderer.scale = 2
            guard let image = renderer.nsImage,
                  let tiff = image.tiffRepresentation,
                  let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:])
            else {
                FileHandle.standardError.write(Data("render failed\n".utf8))
                exit(1)
            }
            try? png.write(to: output)
            print("rendered \(Int(image.size.width))x\(Int(image.size.height)) pt -> \(output.path)")
            exit(0)
        }
        return true
    }
}
