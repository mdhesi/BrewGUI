import SwiftUI
import Observation

/// State for the Outdated screen: packages with newer versions available, plus
/// per-row and bulk upgrade driven through the shared OperationCenter.
@MainActor
@Observable
final class OutdatedModel {
    private(set) var outdated: [String] = []
    var isChecking = false
    var upgrading: Set<String> = []
    var errorMessage: String?

    /// Refresh metadata then list outdated packages.
    func refresh() async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        _ = await BrewProcess.run(["update"])
        let result = await BrewProcess.run(["outdated", "--verbose"])
        outdated = Self.parseOutdated(result.stdout)
    }

    /// Upgrade a single package through the operation center (live log).
    func upgrade(_ name: String, using operations: OperationCenter) async {
        guard !upgrading.contains(name) else { return }
        upgrading.insert(name)
        defer { upgrading.remove(name) }

        let ok = await operations.run(title: "Upgrading \(name)", arguments: ["upgrade", name])
        if ok {
            await refresh()
        } else {
            errorMessage = "Failed to upgrade \(name). See the log for details."
        }
    }

    /// Upgrade everything outdated in one streamed run.
    func upgradeAll(using operations: OperationCenter) async {
        guard !outdated.isEmpty else { return }
        let ok = await operations.run(title: "Upgrading all packages", arguments: ["upgrade"])
        if ok {
            await refresh()
        } else {
            errorMessage = "Some packages failed to upgrade. See the log for details."
        }
    }

    // MARK: - Parsing

    /// `brew outdated --verbose` gives "name (old) < (new)"; keep the name.
    static func parseOutdated(_ output: String) -> [String] {
        output
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .compactMap { $0.split(separator: " ").first.map(String.init) }
    }
}
