import AppKit
import SwiftUI

/// CSwapBar's "Triad" mark: three crescent blades — each a circle minus the
/// next — swirling around a bright core. Accounts rotating and trading places.
/// Original geometry (SF Symbols' license forbids use in logos). Mirrors
/// `docs/brand/*.svg`; keep them in sync.
///
/// On a 100 × 100 grid: blade centers on a circle of radius 12 at −90°, 30°,
/// 150°; blade radius 27; core radius 4.2. The single-color variant leaves a
/// 2.2 gap between blades.
enum TriadGeometry {
    static let count = 3
    static let orbit: CGFloat = 12
    static let radius: CGFloat = 27
    static let core: CGFloat = 4.2
    static let monoGap: CGFloat = 2.2

    /// Blade gradients: terracotta, rose → plum, amber.
    static let colors: [(UInt32, UInt32)] = [(0xFFB38A, 0xE0603F), (0xF48FB1, 0x8E3B8F), (0xFFD08A, 0xD9782F)]

    static func center(_ k: Int, in rect: CGRect) -> CGPoint {
        let unit = rect.width / 100
        let angle = (-90 + Double(k) * 360 / Double(count)) * .pi / 180
        return CGPoint(x: rect.midX + CGFloat(cos(angle)) * orbit * unit,
                       y: rect.midY + CGFloat(sin(angle)) * orbit * unit)
    }

    static func disk(_ k: Int, in rect: CGRect, extra: CGFloat = 0) -> Path {
        let unit = rect.width / 100
        let c = center(k % count, in: rect)
        let r = (radius + extra) * unit
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    static func blade(_ k: Int, in rect: CGRect, gap: CGFloat) -> Path {
        disk(k, in: rect).subtracting(disk(k + 1, in: rect, extra: gap))
    }

    static func coreRect(in rect: CGRect) -> CGRect {
        let r = core * rect.width / 100
        return CGRect(x: rect.midX - r, y: rect.midY - r, width: r * 2, height: r * 2)
    }
}

private struct TriadBlade: Shape {
    let index: Int
    let gap: CGFloat
    func path(in rect: CGRect) -> Path { TriadGeometry.blade(index, in: rect, gap: gap) }
}

private struct TriadCore: Shape {
    func path(in rect: CGRect) -> Path { Path(ellipseIn: TriadGeometry.coreRect(in: rect)) }
}

/// The mark. `color == nil` draws the full-color version.
struct TriadMark: View {
    var color: Color?
    var coreColor: Color = Color(hex: 0xFFF4EC)

    var body: some View {
        ZStack {
            ForEach(0..<TriadGeometry.count, id: \.self) { k in
                if let color {
                    TriadBlade(index: k, gap: TriadGeometry.monoGap).fill(color)
                } else {
                    let (start, end) = TriadGeometry.colors[k]
                    TriadBlade(index: k, gap: 0).fill(LinearGradient(
                        colors: [Color(hex: start), Color(hex: end)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                }
            }
            TriadCore().fill(color ?? coreColor)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// App icon: dark squircle with a warm glow and the full-color mark.
/// Matches `docs/brand/icon.svg`.
struct AppIconView: View {
    var size: CGFloat = 1024

    var body: some View {
        let tile = size * 0.805
        let shape = RoundedRectangle(cornerRadius: tile * 0.225, style: .continuous)
        ZStack {
            shape
                .fill(RadialGradient(colors: [Color(hex: 0x2C2333), Color(hex: 0x0D0A11)],
                                     center: UnitPoint(x: 0.3, y: 0.2), startRadius: 0, endRadius: tile))
                .overlay(
                    Circle()
                        .fill(RadialGradient(colors: [Color(hex: 0xE0603F).opacity(0.35), .clear],
                                             center: .center, startRadius: 0, endRadius: tile * 0.46))
                        .frame(width: tile * 0.92, height: tile * 0.92)
                )
                .overlay(shape.strokeBorder(.white.opacity(0.09), lineWidth: max(1, size / 512)))
                .overlay(TriadMark().frame(width: tile * 0.87))
                .clipShape(shape)
                .frame(width: tile, height: tile)
                .shadow(color: .black.opacity(0.35), radius: size * 0.02, y: size * 0.012)
        }
        .frame(width: size, height: size)
    }
}

enum LogoImages {
    /// Template image for the menu-bar item (single-color mark).
    @MainActor
    static func statusItemTemplate(pointSize: CGFloat = 16) -> NSImage? {
        let renderer = ImageRenderer(content: TriadMark(color: .black).frame(width: pointSize, height: pointSize))
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        guard let image = renderer.nsImage else { return nil }
        image.size = NSSize(width: pointSize, height: pointSize)
        image.isTemplate = true
        return image
    }
}
