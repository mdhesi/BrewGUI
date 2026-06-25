import Foundation

struct InstalledPackage: Identifiable, Hashable {
    // A name can exist as BOTH a formula and a cask (e.g. copilot-cli), so the
    // kind has to be part of the identity or the two collide in a ForEach.
    var id: String { (isCask ? "cask/" : "formula/") + name }
    let name: String
    let version: String
    let isCask: Bool

    /// What the secondary (grey) line shows: the version, or a type fallback if brew gave none.
    var subtitle: String {
        version.isEmpty ? (isCask ? "Cask" : "Formula") : version
    }
}
