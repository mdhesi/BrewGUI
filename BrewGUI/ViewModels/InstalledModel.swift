import SwiftUI
import Observation

/// State for the Installed screen: the merged list of installed formulae + casks
/// loaded via `brew list --versions`, with per-row busy tracking for removal.
@MainActor
@Observable
final class InstalledModel {
    private(set) var packages: [InstalledPackage] = []
    var isLoading = false
    var busy: Set<String> = []
    var errorMessage: String?

    /// Load installed formulae and casks, merged and sorted by name.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        async let formulaeResult = BrewProcess.run(["list", "--versions"])
        async let casksResult = BrewProcess.run(["list", "--cask", "--versions"])
        let (formulae, casks) = await (formulaeResult, casksResult)

        let parsed = Self.parseVersioned(formulae.stdout, isCask: false)
            + Self.parseVersioned(casks.stdout, isCask: true)
        packages = parsed.sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// Uninstall a package; reloads on success, surfaces brew's error otherwise.
    func uninstall(_ name: String, history: RemovalHistoryStore) async {
        guard !busy.contains(name) else { return }
        busy.insert(name)
        defer { busy.remove(name) }

        let result = await BrewProcess.run(["uninstall", name])
        if result.succeeded {
            history.record(name)
            await load()
        } else {
            errorMessage = result.combined.isEmpty ? "Failed to remove \(name)." : result.combined
        }
    }

    // MARK: - Parsing

    /// Parse `brew list --versions` lines ("name 1.2.3") into packages.
    static func parseVersioned(_ output: String, isCask: Bool) -> [InstalledPackage] {
        output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Warning:") && !$0.hasPrefix("Error:") }
            .compactMap { line in
                let parts = line.split(separator: " ", maxSplits: 1)
                guard let name = parts.first.map(String.init) else { return nil }
                let version = parts.count > 1 ? String(parts[1]) : ""
                return InstalledPackage(name: name, version: version, isCask: isCask)
            }
    }
}
