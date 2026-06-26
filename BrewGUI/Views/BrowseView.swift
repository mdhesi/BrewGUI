import SwiftUI

/// Searchable, paginated catalog of every Homebrew formula and cask, sourced from
/// the JSON API via `BrowseModel`. Two-line rows with a real package icon and a
/// hover/context-menu Install that streams through the shared OperationCenter.
/// See ARCHITECTURE.md §9.
struct BrowseView: View {
    @Binding var selection: PackageSummary?
    @State private var model = BrowseModel()
    @Environment(OperationCenter.self) private var operations
    @State private var searchText = ""

    var body: some View {
        Group {
            if model.isLoading && model.visible.isEmpty {
                ProgressView("Loading catalog…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.matchCount == 0 && model.errorMessage != nil {
                ContentUnavailableView("Catalog unavailable",
                                       systemImage: "wifi.slash",
                                       description: Text("Couldn’t load the Homebrew catalog. Check your connection and Refresh."))
            } else {
                list
            }
        }
        .navigationTitle("Browse")
        .searchable(text: $searchText, prompt: "Search formulae and casks")
        .onChange(of: searchText) { _, newValue in
            model.search(newValue)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.load(forceRefresh: true) }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .accessibilityLabel("Refresh catalog")
            }
        }
        .alert("Couldn’t install package",
               isPresented: Binding(get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task {
            if model.visible.isEmpty { await model.load() }
        }
    }

    private var list: some View {
        List(selection: $selection) {
            Section(sectionTitle) {
                if model.visible.isEmpty {
                    Text("No matches for “\(searchText)”")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(model.visible) { pkg in
                        BrowseRow(
                            package: pkg,
                            isInstalling: model.installing.contains(pkg.id),
                            isInstalled: model.installedIDs.contains(pkg.id),
                            onInstall: { Task { await model.install(pkg, using: operations) } }
                        )
                        .tag(pkg)
                        .onAppear {
                            // Infinite scroll: reveal the next page when the last
                            // row shows up.
                            if pkg.id == model.visible.last?.id { model.loadMore() }
                        }
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var sectionTitle: String {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Catalog (\(model.matchCount))"
        }
        return "\(model.matchCount) result\(model.matchCount == 1 ? "" : "s")"
    }
}

/// One catalog row: real package icon (favicon, with amber-tile fallback), name +
/// description, hover/context-menu Install.
struct BrowseRow: View {
    let package: PackageSummary
    var isInstalling: Bool = false
    var isInstalled: Bool = false
    var onInstall: (() -> Void)? = nil

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: Spacing.m) {
            PackageIcon(url: package.iconURL, fallbackSymbol: package.kind.symbolName)

            VStack(alignment: .leading, spacing: 2) {
                Text(package.displayName)
                    .font(.body.weight(.semibold))
                Text(package.desc ?? package.kind.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            trailing
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
        .contextMenu {
            if let onInstall, !isInstalled {
                Button {
                    onInstall()
                } label: {
                    Label("Install \(package.displayName)", systemImage: "arrow.down.circle")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(package.displayName), \(package.kind.label)\(isInstalled ? ", installed" : "")")
    }

    /// Trailing affordance, in priority order: busy spinner → "Installed" badge →
    /// hover Install button → the brew token (so same-named packages, e.g. the
    /// four ".NET SDK" casks, stay distinguishable).
    @ViewBuilder private var trailing: some View {
        if isInstalling {
            ProgressView()
                .controlSize(.small)
        } else if isInstalled {
            Label("Installed", systemImage: "checkmark.circle.fill")
                .font(.caption.weight(.medium))
                .labelStyle(.titleAndIcon)
                .foregroundStyle(.green)
                .accessibilityLabel("\(package.displayName) is installed")
        } else if let onInstall, isHovering {
            Button(action: onInstall) {
                Label("Install", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.glass)
            .controlSize(.small)
            .accessibilityLabel("Install \(package.displayName)")
            .transition(.opacity)
        } else {
            Text(package.token)
                .font(.caption)
                .monospaced()
                .foregroundStyle(.tertiary)
                .lineLimit(1)
                .accessibilityHidden(true)
        }
    }
}
