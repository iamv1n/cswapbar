import AppKit
import CSwapBarCore
import SwiftUI

/// Developer tool: renders UI with sample data to a PNG and exits.
///
///     CSwapBar --render-popover out.png [--accounts 6] [--theme paper] [--accent teal]
///              [--layout rings] [--font rounded] [--size large] [--light] [--privacy] [--compact]
///     CSwapBar --render-settings out.png [--pane appearance] [same theme flags]
///              [--corners boxy] [--borders bold] [--bars thick] [--controls matchCorners] [--custom [--gradient]]
///              (custom themes and shape options are on the Appearance pane)
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
        let dashboardFlag = args.firstIndex(of: "--render-dashboard")
        let islandFlag = args.firstIndex(of: "--render-island")
        guard let flag = popoverFlag ?? settingsFlag ?? widgetFlag ?? dashboardFlag ?? islandFlag, flag + 1 < args.count else { return false }
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
        if let v = value("--corners").flatMap(CornerStyle.init(rawValue:)) { settings.design.corners = v }
        if let v = value("--borders").flatMap(BorderWeight.init(rawValue:)) { settings.design.borders = v }
        if let v = value("--bars").flatMap(BarThickness.init(rawValue:)) { settings.design.bars = v }
        if let v = value("--controls").flatMap(ControlShape.init(rawValue:)) { settings.design.controls = v }
        if args.contains("--custom") {
            // A sample custom theme, as if made in Theme Studio.
            settings.addCustomTheme(CustomTheme(name: "Nightfall", isDark: true, gradient: args.contains("--gradient"),
                                                background: 0x12151C, backgroundEnd: 0x2A1E3D, surface: 0x1D212B,
                                                text: 0xECEEF3, accent: 0x7AA2F7))
        }
        settings.privacy.privacyModeEnabled = args.contains("--privacy")
        settings.compactCards = args.contains("--compact")
        store.save(settings)

        let count = value("--accounts").flatMap(Int.init) ?? 4
        let scheme: ColorScheme = args.contains("--light") ? .light : .dark
        let pane = value("--pane").flatMap(SettingsPane.init(rawValue:)) ?? .appearance

        Task { @MainActor in
            let model = AppModel(client: SampleCSwapClient(count: count), store: store, notifier: Notifier(live: false))
            await model.refresh()

            let widgetKind = value("--kind").flatMap(DesktopWidgetKind.init(rawValue:)) ?? .active
            let content: AnyView = if islandFlag != nil {
                islandPreview(model: model,
                              style: value("--style").flatMap(UsageIslandPreferences.Style.init(rawValue:)) ?? .notch,
                              expanded: args.contains("--expanded"))
            } else if dashboardFlag != nil {
                AnyView(DashboardView(model: model).frame(width: 900))
            } else if settingsFlag != nil {
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

    /// The island on a 1512-pt-wide notched screen (or floating, with `--style bar`),
    /// over a colorful backdrop so its black shape is visible.
    @MainActor
    private static func islandPreview(model: AppModel, style: UsageIslandPreferences.Style, expanded: Bool) -> AnyView {
        let geometry = IslandGeometry(screen: CGRect(x: 0, y: 0, width: 1512, height: 982), menuBarHeight: 38,
                                      notchWidth: 200, style: style)
        let state = UsageIslandState()
        state.expanded = expanded
        let size = geometry.expanded.size
        let height = expanded ? size.height + 50 : geometry.collapsed.height + 64
        return AnyView(UsageIslandView(model: model, state: state, geometry: geometry)
            .frame(width: size.width + 80, height: height, alignment: .top)
            .background(alignment: .top) {
                // A dark-blue desktop with a faint menu bar, like the top of a Mac screen.
                ZStack(alignment: .top) {
                    LinearGradient(colors: [Color(hex: 0x0B1A33), Color(hex: 0x1E3A6E)], startPoint: .top, endPoint: .bottom)
                    Rectangle().fill(Color.black.opacity(0.28)).frame(height: geometry.hugsNotch ? geometry.collapsed.height : 24)
                }
            })
    }
}
