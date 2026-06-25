/*
 A single installed Homebrew package — either a formula or a cask.

 Populated from `brew list --versions` (formulae) and
 `brew list --cask --versions` (casks), both of which emit "name version".
 */

import Foundation

struct InstalledPackage: Identifiable, Hashable {
    var id: String { name } // names are unique within an install
    let name: String
    let version: String
    let isCask: Bool

    /// What the secondary (grey) line shows: the version, or a type fallback if brew gave none.
    var subtitle: String {
        version.isEmpty ? (isCask ? "Cask" : "Formula") : version
    }
}
