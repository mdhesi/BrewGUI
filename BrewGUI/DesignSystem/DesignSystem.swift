import SwiftUI

/// 8pt spacing grid. Use these everywhere instead of magic numbers so layout
/// stays consistent across screens.
enum Spacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
}

/// Shared visual constants.
enum Theme {
    static let cornerRadius: CGFloat = 12
    static let rowVerticalPadding: CGFloat = 6

    /// Standard spring used for install/remove and other content transitions.
    static let springAnimation: Animation = .spring(response: 0.35, dampingFraction: 0.8)
}

/// Homebrew-amber brand palette, mirrored from the marketing site so the app
/// and landing page read as one product. `accent` comes from the asset catalog
/// so it follows light/dark automatically.
enum BrewColor {
    static let accent = Color.accentColor
    static let amber = Color(red: 0.961, green: 0.651, blue: 0.137)       // #f5a623
    static let amberDeep = Color(red: 0.784, green: 0.471, blue: 0.039)   // #c8780a

    /// Soft amber-tinted fill used behind icon tiles and badges.
    static let amberTint = amber.opacity(0.16)
    static let amberBorder = amber.opacity(0.30)
}

/// Rounded, amber-tinted icon tile — the app equivalent of the landing page's
/// `.glyph` / package-icon squares. Use for the leading glyph on list rows.
struct IconTile: View {
    let systemName: String
    var size: CGFloat = 32
    var tint: Color = BrewColor.amberDeep

    var body: some View {
        let corner = size * 0.28
        Image(systemName: systemName)
            .font(.system(size: size * 0.5, weight: .medium))
            .foregroundStyle(tint)
            .frame(width: size, height: size)
            .background(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .fill(LinearGradient(
                        colors: [BrewColor.amber.opacity(0.20), BrewColor.amberDeep.opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing))
            )
            .overlay(
                RoundedRectangle(cornerRadius: corner, style: .continuous)
                    .strokeBorder(BrewColor.amberBorder, lineWidth: 0.75)
            )
            .accessibilityHidden(true)
    }
}

extension View {
    /// Wraps a floating control cluster (toolbar / search / action bar) in
    /// Liquid Glass so it reads as a hovering glass surface over content.
    func glassActionBar() -> some View {
        self
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .glassEffect(.regular, in: .capsule)
    }

    /// A panel/card surface backed by translucent material (sidebars, detail
    /// panes, log panels).
    func materialPanel(_ material: Material = .regularMaterial) -> some View {
        self
            .background(material, in: RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
    }
}

/// Byte-size formatting shared by the detail pane and Cleanup view.
enum SizeFormatter {
    static func string(_ bytes: Int64?) -> String {
        guard let bytes, bytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
