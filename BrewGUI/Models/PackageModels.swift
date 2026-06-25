import Foundation

// MARK: - Domain kind

enum PackageKind: String, Codable, Hashable {
    case formula
    case cask

    var symbolName: String { self == .cask ? "app.dashed" : "shippingbox" }
    var label: String { self == .cask ? "Cask" : "Formula" }
}

// MARK: - Browse summary

/// Lightweight row model for the Browse list, built from the bulk API plus
/// analytics. `installCount` is filled in for the Popular ranking.
struct PackageSummary: Identifiable, Hashable {
    let token: String       // formula name or cask token
    let displayName: String // human-facing name
    let kind: PackageKind
    let desc: String?
    var installCount: Int?

    var id: String { kind.rawValue + "/" + token }
}

// MARK: - Detail

/// Everything the detail pane shows. Assembled from the per-item API response
/// and (for installed packages) `brew info` for on-disk size.
struct PackageDetail: Identifiable, Hashable {
    let token: String
    let displayName: String
    let kind: PackageKind
    let desc: String?
    let homepage: String?
    let license: String?
    let version: String?
    let dependencies: [String]
    let installCount30d: Int?
    var downloadSize: Int64?    // bytes, best-effort (API artifact)
    var installedSize: Int64?   // bytes, best-effort (parsed from brew info)
    var isInstalled: Bool

    var id: String { kind.rawValue + "/" + token }
}

// MARK: - API decoding: bulk + per-item formula/cask

/// Install analytics embedded in a per-item API response:
/// `install` → period ("30d"/"90d"/"365d") → command string → count.
struct EmbeddedAnalytics: Codable, Hashable {
    let install: [String: [String: Int]]?
}

struct APIFormula: Codable, Hashable {
    let name: String
    let desc: String?
    let homepage: String?
    let license: String?
    let versions: Versions?
    let dependencies: [String]?
    let analytics: EmbeddedAnalytics?

    struct Versions: Codable, Hashable {
        let stable: String?
    }

    var summary: PackageSummary {
        PackageSummary(token: name, displayName: name, kind: .formula, desc: desc, installCount: nil)
    }

    /// Plain install count for this formula over a period (ignores variant
    /// commands like "wget --HEAD"); nil when analytics are absent.
    func installCount(period: AnalyticsPeriod) -> Int? {
        analytics?.install?[period.rawValue]?[name]
    }
}

struct APICask: Codable, Hashable {
    let token: String
    let name: [String]?
    let desc: String?
    let homepage: String?
    let version: String?
    let url: String?
    let analytics: EmbeddedAnalytics?

    var displayName: String { name?.first ?? token }

    var summary: PackageSummary {
        PackageSummary(token: token, displayName: displayName, kind: .cask, desc: desc, installCount: nil)
    }

    func installCount(period: AnalyticsPeriod) -> Int? {
        analytics?.install?[period.rawValue]?[token]
    }
}

// MARK: - Analytics

enum AnalyticsPeriod: String, CaseIterable, Identifiable {
    case month = "30d"
    case quarter = "90d"
    case year = "365d"

    var id: String { rawValue }
    var label: String {
        switch self {
        case .month: return "30 days"
        case .quarter: return "90 days"
        case .year: return "365 days"
        }
    }
}

/// Bulk analytics endpoint (`analytics/install/30d.json`,
/// `analytics/cask-install/30d.json`). Counts arrive as comma-formatted strings.
struct AnalyticsResponse: Codable {
    let items: [Item]

    struct Item: Codable {
        let number: Int
        let formula: String?
        let cask: String?
        let count: String
        let percent: String?

        var token: String? { formula ?? cask }
        var numericCount: Int? {
            Int(count.replacingOccurrences(of: ",", with: ""))
        }
    }
}
