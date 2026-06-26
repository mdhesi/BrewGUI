import SwiftUI
import Observation

/// State for the Browse screen: the full Homebrew catalog (formulae + casks)
/// fetched from the JSON API via `BrewAPIClient`, searchable and paginated, with
/// per-row install driven through the shared `OperationCenter`.
///
/// Performance: the catalog is ~16k items, so we (1) build a lowercased search
/// index once, off the main thread, (2) filter once per query change (not per
/// render), and (3) only render a page at a time — `visible` grows as you scroll.
/// See ARCHITECTURE.md §9.
@MainActor
@Observable
final class BrowseModel {
    /// What the list renders right now (a prefix of the current matches).
    private(set) var visible: [PackageSummary] = []
    /// Total number of matches for the current query (for the result count).
    private(set) var matchCount = 0
    var isLoading = false
    var errorMessage: String?
    /// Tokens currently installing (per-row spinner).
    var installing: Set<String> = []
    /// `PackageSummary.id`s already installed, so rows can show "Installed"
    /// instead of an Install action.
    private(set) var installedIDs: Set<String> = []

    /// How many more rows to reveal each time you reach the bottom.
    static let pageSize = 20

    // Internal index + current query/limit state.
    private var index: [IndexedPackage] = []
    private var matches: [PackageSummary] = []
    private var query = ""
    private var limit = pageSize

    /// A package plus the lowercased strings we match against, computed once so
    /// search doesn't re-lowercase 16k descriptions on every keystroke.
    private struct IndexedPackage {
        let summary: PackageSummary
        let nameKey: String   // token + display name, lowercased
        let descKey: String   // description, lowercased
    }

    var canLoadMore: Bool { visible.count < matchCount }

    /// Load the catalog from the API (cache-backed; instant on second launch and
    /// works offline once cached), then build the search index off-thread.
    func load(forceRefresh: Bool = false) async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        await loadInstalled()

        async let formulaeResult = BrewAPIClient.shared.allFormulae(forceRefresh: forceRefresh)
        async let casksResult = BrewAPIClient.shared.allCasks(forceRefresh: forceRefresh)
        let (formulae, casks) = await (formulaeResult, casksResult)

        if formulae.isEmpty && casks.isEmpty {
            errorMessage = "Couldn’t load the Homebrew catalog. Check your connection and try Refresh."
            return
        }

        let summaries = formulae.map(\.summary) + casks.map(\.summary)
        // Sorting + lowercasing 16k items is CPU work; keep it off the main actor
        // so the UI doesn't hitch while the catalog is prepared.
        index = await Task.detached(priority: .userInitiated) {
            summaries
                .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                .map { IndexedPackage(summary: $0,
                                      nameKey: ($0.token + " " + $0.displayName).lowercased(),
                                      descKey: ($0.desc ?? "").lowercased()) }
        }.value

        applyQuery()
    }

    /// Load the set of currently-installed formulae + casks (names/tokens only)
    /// so Browse can mark what's already on the machine.
    func loadInstalled() async {
        async let formulaeResult = BrewProcess.run(["list", "--formula"])
        async let casksResult = BrewProcess.run(["list", "--cask"])
        let (formulae, casks) = await (formulaeResult, casksResult)

        var ids = Set<String>()
        for name in Self.tokens(formulae.stdout) { ids.insert("formula/\(name)") }
        for token in Self.tokens(casks.stdout) { ids.insert("cask/\(token)") }
        installedIDs = ids
    }

    /// Parse one-token-per-line `brew list` output, skipping warnings/errors.
    private static func tokens(_ output: String) -> [String] {
        output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Warning:") && !$0.hasPrefix("Error:") }
    }

    /// Set the search query and recompute matches (resets pagination).
    func search(_ text: String) {
        query = text.trimmingCharacters(in: .whitespaces).lowercased()
        limit = Self.pageSize
        applyQuery()
    }

    /// Reveal the next page of the current matches.
    func loadMore() {
        guard canLoadMore else { return }
        limit += Self.pageSize
        visible = Array(matches.prefix(limit))
    }

    /// Filter the index for the current query, ranking name/token matches above
    /// description-only matches, then slice the first page.
    private func applyQuery() {
        if query.isEmpty {
            matches = index.map(\.summary)
        } else {
            var nameMatches: [PackageSummary] = []
            var descMatches: [PackageSummary] = []
            for item in index {
                if item.nameKey.contains(query) {
                    nameMatches.append(item.summary)
                } else if item.descKey.contains(query) {
                    descMatches.append(item.summary)
                }
            }
            matches = nameMatches + descMatches
        }
        matchCount = matches.count
        visible = Array(matches.prefix(limit))
    }

    /// Install a package through the operation center (live log + Trust & Retry).
    func install(_ package: PackageSummary, using operations: OperationCenter) async {
        guard !installing.contains(package.id) else { return }
        installing.insert(package.id)
        defer { installing.remove(package.id) }

        let kindFlag = package.kind == .cask ? "--cask" : "--formula"
        let ok = await operations.run(title: "Installing \(package.displayName)",
                                      arguments: ["install", kindFlag, package.token])
        if ok {
            installedIDs.insert(package.id)
        } else {
            errorMessage = "Failed to install \(package.displayName). See the log for details."
        }
    }
}
