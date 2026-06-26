import SwiftUI
import Observation

/// State for the Browse screen: the full Homebrew catalog (formulae + casks)
/// fetched from the JSON API via `BrewAPIClient`, searchable, with per-row
/// install driven through the shared `OperationCenter`.
///
/// Mirrors `InstalledModel`'s shape, but the data source is the network
/// (`BrewAPIClient`) instead of the local `brew` binary. See ARCHITECTURE.md §9.
@MainActor
@Observable
final class BrowseModel {
    /// The whole catalog, sorted by display name. ~tens of thousands of items.
    private(set) var all: [PackageSummary] = []
    var isLoading = false
    var errorMessage: String?
    /// Tokens currently installing (per-row spinner).
    var installing: Set<String> = []

    /// How many matches to render at once. The catalog is huge; showing every
    /// match would make the list sluggish and isn't useful — you refine instead.
    static let resultLimit = 200

    /// Load the catalog from the API (cache-backed, so this is instant on the
    /// second launch and works offline once cached).
    func load(forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let formulaeResult = BrewAPIClient.shared.allFormulae(forceRefresh: forceRefresh)
        async let casksResult = BrewAPIClient.shared.allCasks(forceRefresh: forceRefresh)
        let (formulae, casks) = await (formulaeResult, casksResult)

        if formulae.isEmpty && casks.isEmpty {
            errorMessage = "Couldn’t load the Homebrew catalog. Check your connection and try Refresh."
        }

        let summaries = formulae.map(\.summary) + casks.map(\.summary)
        all = summaries.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Search results for `query`, capped at `resultLimit`. Name/token matches
    /// rank above description-only matches so the obvious hit is at the top.
    func results(for query: String) -> [PackageSummary] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return Array(all.prefix(Self.resultLimit)) }

        var nameMatches: [PackageSummary] = []
        var descMatches: [PackageSummary] = []
        for pkg in all {
            if pkg.token.localizedCaseInsensitiveContains(trimmed)
                || pkg.displayName.localizedCaseInsensitiveContains(trimmed) {
                nameMatches.append(pkg)
            } else if pkg.desc?.localizedCaseInsensitiveContains(trimmed) == true {
                descMatches.append(pkg)
            }
            if nameMatches.count >= Self.resultLimit { break }
        }
        return Array((nameMatches + descMatches).prefix(Self.resultLimit))
    }

    /// Install a package through the operation center (live log + Trust & Retry).
    func install(_ package: PackageSummary, using operations: OperationCenter) async {
        guard !installing.contains(package.id) else { return }
        installing.insert(package.id)
        defer { installing.remove(package.id) }

        let kindFlag = package.kind == .cask ? "--cask" : "--formula"
        let ok = await operations.run(title: "Installing \(package.displayName)",
                                      arguments: ["install", kindFlag, package.token])
        if !ok {
            errorMessage = "Failed to install \(package.displayName). See the log for details."
        }
    }
}
