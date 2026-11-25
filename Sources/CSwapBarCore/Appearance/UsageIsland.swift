import CoreGraphics
import Foundation

/// The Usage Island: a small black bar at the top-center of the screen that
/// blends with the notch and expands on hover.
///
/// It's an alternative home for CSwapBar, not an extra: when it's on, the menu
/// bar icon is hidden and the popover opens from the island. Off by default.
public struct UsageIslandPreferences: Codable, Sendable, Equatable {
    public enum Style: String, CaseIterable, Codable, Sendable {
        /// Hugs the camera notch at the very top (a floating bar on screens without one).
        case notch
        /// A floating pill just below the menu bar, on any screen.
        case bar

        public var title: String {
            switch self {
            case .notch: "Notch"
            case .bar: "Floating bar"
            }
        }
    }

    /// True: CSwapBar lives in the island, and the menu bar icon is hidden.
    public var enabled: Bool = false
    public var style: Style = .notch

    public init() {}

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = (try? c.decodeIfPresent(Bool.self, forKey: .enabled)) ?? false
        style = (try? c.decodeIfPresent(Style.self, forKey: .style)) ?? .notch
    }

    /// Whether the menu bar icon shows. Exactly one of the icon and the island is visible.
    public var showsMenuBarIcon: Bool { !enabled }
}

/// Where the island sits, in screen coordinates (origin bottom-left, like AppKit).
public struct IslandGeometry: Sendable, Equatable {
    public let collapsed: CGRect
    public let expanded: CGRect
    /// True when the island hugs a camera notch.
    public let hugsNotch: Bool

    public static let wing: CGFloat = 74            // width of each side beside the notch
    public static let pillSize = CGSize(width: 210, height: 30)
    public static let expandedSize = CGSize(width: 400, height: 256)

    /// - Parameters:
    ///   - screen: the screen's full frame.
    ///   - menuBarHeight: height of the menu bar (the notch height on notched screens).
    ///   - notchWidth: width of the camera notch, or nil when there isn't one.
    ///   - style: `.bar` floats below the menu bar even on a notched screen.
    public init(screen: CGRect, menuBarHeight: CGFloat, notchWidth: CGFloat?,
                style: UsageIslandPreferences.Style = .notch) {
        let top = screen.maxY
        if style == .notch, let notchWidth, notchWidth > 0 {
            hugsNotch = true
            let width = notchWidth + 2 * Self.wing
            collapsed = CGRect(x: screen.midX - width / 2, y: top - menuBarHeight, width: width, height: menuBarHeight)
            let expandedWidth = max(Self.expandedSize.width, width)
            let expandedHeight = Self.expandedSize.height + menuBarHeight
            expanded = CGRect(x: screen.midX - expandedWidth / 2, y: top - expandedHeight, width: expandedWidth, height: expandedHeight)
        } else {
            hugsNotch = false
            let gap: CGFloat = 6
            let pillTop = top - menuBarHeight - gap
            collapsed = CGRect(x: screen.midX - Self.pillSize.width / 2, y: pillTop - Self.pillSize.height,
                               width: Self.pillSize.width, height: Self.pillSize.height)
            expanded = CGRect(x: screen.midX - Self.expandedSize.width / 2, y: pillTop - Self.expandedSize.height,
                              width: Self.expandedSize.width, height: Self.expandedSize.height)
        }
    }
}
