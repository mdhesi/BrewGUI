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
