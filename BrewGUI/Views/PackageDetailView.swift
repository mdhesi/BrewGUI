import SwiftUI

/// The detail pane (third NavigationSplitView column): shown when a package is
/// selected in Browse. Header with the real icon + name, description, a link to
/// the original source (homepage), and a stats block — version, license,
/// dependencies, and install counts ("downloads"). See ARCHITECTURE.md §9.
struct PackageDetailView: View {
    let package: PackageSummary
    @State private var model = PackageDetailModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.l) {
                header
                if let desc = model.detail?.desc ?? package.desc {
                    Text(desc)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let homepage = model.detail?.homepage, let url = URL(string: homepage) {
                    sourceLink(url)
                }
                Divider()
                stats
                if let deps = model.detail?.dependencies, !deps.isEmpty {
                    dependencies(deps)
                }
            }
            .padding(Spacing.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .overlay {
            if model.isLoading && model.detail == nil {
                ProgressView().controlSize(.small)
            }
        }
        .navigationTitle(package.displayName)
        .task(id: package.id) {
            await model.load(package)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Spacing.m) {
            PackageIcon(url: package.iconURL, fallbackSymbol: package.kind.symbolName, size: 56)
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(package.displayName)
                    .font(.title2.weight(.bold))
                HStack(spacing: Spacing.s) {
                    Text(package.kind.label)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, 2)
                        .background(BrewColor.amberTint, in: Capsule())
                        .foregroundStyle(BrewColor.amberDeep)
                    if let version = model.detail?.version {
                        Text("v\(version)")
                            .font(.caption)
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Source link

    private func sourceLink(_ url: URL) -> some View {
        Link(destination: url) {
            Label("Visit homepage", systemImage: "arrow.up.right.square")
        }
        .buttonStyle(.glass)
        .controlSize(.large)
        .accessibilityLabel("Visit homepage for \(package.displayName)")
    }

    // MARK: - Stats

    private var stats: some View {
        VStack(spacing: 0) {
            if let count = model.detail?.installCount30d {
                statRow("Installs · 30 days", value: count.formatted(.number))
            }
            if let count = model.detail?.installCount365d {
                statRow("Installs · 1 year", value: count.formatted(.number))
            }
            if let version = model.detail?.version {
                statRow("Version", value: version, mono: true)
            }
            if let license = model.detail?.license {
                statRow("License", value: license)
            }
            statRow("Type", value: package.kind.label)
            statRow("Token", value: package.token, mono: true)
        }
    }

    private func statRow(_ label: String, value: String, mono: Bool = false) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer(minLength: Spacing.m)
            Text(value)
                .font(mono ? .subheadline.monospaced() : .subheadline)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
        .padding(.vertical, Spacing.s)
        .overlay(alignment: .bottom) { Divider() }
    }

    // MARK: - Dependencies

    private func dependencies(_ deps: [String]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.s) {
            Text("Dependencies")
                .font(.headline)
            FlowLayout(spacing: Spacing.s) {
                ForEach(deps, id: \.self) { dep in
                    Text(dep)
                        .font(.caption)
                        .monospaced()
                        .padding(.horizontal, Spacing.s)
                        .padding(.vertical, Spacing.xs)
                        .background(.quaternary, in: Capsule())
                }
            }
        }
    }
}

/// Placeholder shown in the detail column when nothing is selected.
struct PackageDetailPlaceholder: View {
    var body: some View {
        ContentUnavailableView("No package selected",
                               systemImage: "sidebar.right",
                               description: Text("Select a package to see its details, source, and install count."))
    }
}

/// Minimal wrapping layout for dependency chips. Lays children left-to-right,
/// wrapping to the next line when they don't fit.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        var totalHeight: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                totalHeight += rowHeight + spacing
                x = 0
                rowHeight = 0
            }
            rows[rows.count - 1].append(subview)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        totalHeight += rowHeight
        return CGSize(width: maxWidth == .infinity ? x : maxWidth, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX, x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
