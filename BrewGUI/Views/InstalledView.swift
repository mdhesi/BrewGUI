import SwiftUI

/// Installed formulae + casks. Live-filterable, two-line rows, hover/context
/// Remove. Toolbar Refresh + searchable field with a result count.
struct InstalledView: View {
    @State private var model = InstalledModel()
    @EnvironmentObject private var history: RemovalHistoryStore
    @State private var searchText = ""

    private var filtered: [InstalledPackage] {
        guard !searchText.isEmpty else { return model.packages }
        return model.packages.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        List {
            Section(sectionTitle) {
                if filtered.isEmpty {
                    Text(emptyMessage)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(filtered) { pkg in
                        PackageRow(
                            package: pkg,
                            isBusy: model.busy.contains(pkg.id),
                            onRemove: { Task { await model.uninstall(pkg, history: history) } }
                        )
                    }
                }
            }
        }
        .listStyle(.inset)
        .animation(Theme.springAnimation, value: filtered)
        .navigationTitle("Installed")
        .searchable(text: $searchText, prompt: "Search installed packages")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.load() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isLoading)
                .accessibilityLabel("Refresh installed packages")
            }
        }
        .overlay {
            if model.isLoading && model.packages.isEmpty {
                ProgressView("Loading…")
            }
        }
        .alert("Couldn’t remove package",
               isPresented: Binding(get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task {
            if model.packages.isEmpty { await model.load() }
        }
    }

    private var sectionTitle: String {
        searchText.isEmpty
            ? "Installed (\(model.packages.count))"
            : "\(filtered.count) of \(model.packages.count)"
    }

    private var emptyMessage: String {
        if model.isLoading { return "Loading…" }
        return searchText.isEmpty ? "No packages found" : "No matches for “\(searchText)”"
    }
}
