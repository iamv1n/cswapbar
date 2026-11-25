import Foundation

/// Shape and weight choices that apply on top of any theme.
public struct DesignOptions: Codable, Sendable, Equatable {
    public var corners: CornerStyle = .themeDefault
    public var borders: BorderWeight = .themeDefault
    public var bars: BarThickness = .regular
    public var controls: ControlShape = .pill

    public init() {}

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = DesignOptions()
        corners = (try? c.decodeIfPresent(CornerStyle.self, forKey: .corners)) ?? d.corners
        borders = (try? c.decodeIfPresent(BorderWeight.self, forKey: .borders)) ?? d.borders
        bars = (try? c.decodeIfPresent(BarThickness.self, forKey: .bars)) ?? d.bars
        controls = (try? c.decodeIfPresent(ControlShape.self, forKey: .controls)) ?? d.controls
    }
}

/// How round cards, tiles and widgets are.
public enum CornerStyle: String, CaseIterable, Codable, Sendable {
    case themeDefault
    case boxy
    case soft
    case rounded
    case round

    public var title: String {
        switch self {
        case .themeDefault: "Theme"
        case .boxy: "Boxy"
        case .soft: "Soft"
        case .rounded: "Rounded"
        case .round: "Round"
        }
    }

    /// Card radius in points. `themeDefault` keeps the theme's own radius.
    public func cardRadius(themeDefault: Double) -> Double {
        switch self {
        case .themeDefault: themeDefault
        case .boxy: 3
        case .soft: 8
        case .rounded: 14
        case .round: 22
        }
    }

    /// Desktop widget radius (macOS widgets are rounder than cards).
    public func widgetRadius(themeDefault: Double) -> Double {
        switch self {
        case .themeDefault: themeDefault
        case .boxy: 5
        case .soft: 12
        case .rounded: 18
        case .round: 28
        }
    }

    /// Squared-off styles also square off bars and ring ends.
    public var isSquare: Bool { self == .boxy }
}

/// Card outline weight.
public enum BorderWeight: String, CaseIterable, Codable, Sendable {
    case themeDefault
    case none
    case thin
    case bold

    public var title: String {
        switch self {
        case .themeDefault: "Theme"
        case .none: "None"
        case .thin: "Thin"
        case .bold: "Bold"
        }
    }

    /// Line width in points, or `nil` to keep the theme's.
    public var lineWidth: Double? {
        switch self {
        case .themeDefault: nil
        case .none: 0
        case .thin: 1
        case .bold: 2
        }
    }
}

/// Thickness of usage bars and rings.
public enum BarThickness: String, CaseIterable, Codable, Sendable {
    case thin
    case regular
    case thick

    public var title: String {
        switch self {
        case .thin: "Thin"
        case .regular: "Regular"
        case .thick: "Thick"
        }
    }

    public var scale: Double {
        switch self {
        case .thin: 0.6
        case .regular: 1
        case .thick: 1.6
        }
    }
}

/// Shape of buttons, chips and badges.
public enum ControlShape: String, CaseIterable, Codable, Sendable {
    /// Fully rounded capsules.
    case pill
    /// Rounded rectangles that follow the corner style.
    case matchCorners

    public var title: String {
        switch self {
        case .pill: "Pill"
        case .matchCorners: "Match corners"
        }
    }
}
