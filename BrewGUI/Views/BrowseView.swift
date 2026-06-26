import SwiftUI

/// Searchable catalog of every Homebrew formula and cask, sourced from the JSON
/// API via `BrowseModel`. Two-line rows with a hover/keyboard Install action that
/// streams through the shared OperationCenter. See ARCHITECTURE.md §9.
struct BrowseView: View {
    @State private var model = BrowseModel()
    @Environment(OperationCenter.self) private var operations
    @State private var searchText = ""

    private var results: [PackageSummary] { model.results(for: searchText) }

    var body: some View {
        Group {
            if model.isLoading && model.all.isEmpty {
                ProgressView("Loading catalog…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.all.isEmpty {
                ContentUnavailableView("Catalog unavailable",
                                       systemImage: "wifi.slash",
                                       description: Text("Couldn’t load the Homebrew catalog. Check your connection and Refresh."))
            } else {
                list
            }
        }
        .navigationTitle("Browse")
        .searchable(text: $searchText, prompt: "Search formulae and casks")
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
            if model.all.isEmpty { await model.load() }
        }
    }

    private var list: some View {
        List {
            Section(sectionTitle) {
                if results.isEmpty {
                    Text("No matches for “\(searchText)”")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(results) { pkg in
                        BrowseRow(
                            package: pkg,
                            isInstalling: model.installing.contains(pkg.id),
                            onInstall: { Task { await model.install(pkg, using: operations) } }
                        )
                    }
                }
            }
        }
        .listStyle(.inset)
    }

    private var sectionTitle: String {
        if searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            return "Catalog (\(model.all.count))"
        }
        let shown = results.count
        let capped = shown >= BrowseModel.resultLimit ? "\(shown)+" : "\(shown)"
        return "\(capped) result\(shown == 1 ? "" : "s")"
    }
}

/// One catalog row: leading kind glyph, name + description, hover/context-menu
/// Install. Self-contained so it doesn't depend on the in-progress design pass.
struct BrowseRow: View {
    let package: PackageSummary
    var isInstalling: Bool = false
    var onInstall: (() -> Void)? = nil

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: package.kind.symbolName)
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(width: 24)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(package.displayName)
                    .font(.body)
                Text(package.desc ?? package.kind.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            if isInstalling {
                ProgressView()
                    .controlSize(.small)
            } else if let onInstall, isHovering {
                Button(action: onInstall) {
                    Label("Install", systemImage: "arrow.down.circle")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .accessibilityLabel("Install \(package.displayName)")
                .transition(.opacity)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) { isHovering = hovering }
        }
        .contextMenu {
            if let onInstall {
                Button {
                    onInstall()
                } label: {
                    Label("Install \(package.displayName)", systemImage: "arrow.down.circle")
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(package.displayName), \(package.kind.label)")
    }
}
