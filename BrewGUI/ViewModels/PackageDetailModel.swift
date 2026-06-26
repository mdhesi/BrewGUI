import SwiftUI
import Observation

/// Loads the full detail for a selected package from the Homebrew JSON API
/// (per-item endpoint), assembling a `PackageDetail` for the detail pane:
/// description, homepage, version, license, dependencies, and install counts
/// ("downloads"). Cache-backed via `BrewAPIClient`. See ARCHITECTURE.md §9.
@MainActor
@Observable
final class PackageDetailModel {
    private(set) var detail: PackageDetail?
    private(set) var isLoading = false
    /// The summary we last loaded for, so the view can avoid redundant fetches.
    private(set) var loadedID: String?

    func load(_ summary: PackageSummary) async {
        guard loadedID != summary.id else { return }
        isLoading = true
        detail = nil
        loadedID = summary.id
        defer { isLoading = false }

        switch summary.kind {
        case .formula:
            guard let f = await BrewAPIClient.shared.formulaDetail(summary.token) else { return }
            detail = PackageDetail(
                token: f.name,
                displayName: f.name,
                kind: .formula,
                desc: f.desc,
                homepage: f.homepage,
                license: f.license,
                version: f.versions?.stable,
                dependencies: f.dependencies ?? [],
                installCount30d: f.installCount(period: .month),
                installCount365d: f.installCount(period: .year),
                downloadSize: nil,
                installedSize: nil,
                isInstalled: false
            )
        case .cask:
            guard let c = await BrewAPIClient.shared.caskDetail(summary.token) else { return }
            detail = PackageDetail(
                token: c.token,
                displayName: c.displayName,
                kind: .cask,
                desc: c.desc,
                homepage: c.homepage,
                license: nil,
                version: c.version,
                dependencies: [],
                installCount30d: c.installCount(period: .month),
                installCount365d: c.installCount(period: .year),
                downloadSize: nil,
                installedSize: nil,
                isInstalled: false
            )
        }
    }
}
