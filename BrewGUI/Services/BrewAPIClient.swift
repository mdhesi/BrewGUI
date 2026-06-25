import Foundation

/// Async client for the Homebrew JSON API (https://formulae.brew.sh/api/).
/// Every fetch is cache-backed: fresh enough cache is served without a network
/// hit, and on any network failure the last good cache is returned so the UI
/// degrades gracefully offline.
struct BrewAPIClient {
    static let shared = BrewAPIClient()

    private let base = URL(string: "https://formulae.brew.sh/api/")!
    private let session: URLSession = .shared
    private let cache = APICache.shared

    /// Bulk catalogs change slowly; per-item details a little faster.
    private static let bulkMaxAge: TimeInterval = 60 * 60 * 6      // 6 hours
    private static let detailMaxAge: TimeInterval = 60 * 60 * 1    // 1 hour

    // MARK: - Generic cached fetch

    private func cachedFetch<T: Codable>(
        _ type: T.Type,
        path: String,
        cacheKey: String,
        maxAge: TimeInterval,
        forceRefresh: Bool
    ) async -> T? {
        if !forceRefresh,
           let cached = await cache.load(T.self, key: cacheKey),
           Date().timeIntervalSince(cached.date) < maxAge {
            return cached.value
        }
        do {
            let (data, response) = try await session.data(from: base.appendingPathComponent(path))
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let value = try JSONDecoder().decode(T.self, from: data)
            await cache.save(value, key: cacheKey)
            return value
        } catch {
            // Network/decoding failed — fall back to whatever we last cached.
            return await cache.load(T.self, key: cacheKey)?.value
        }
    }

    // MARK: - Catalogs

    func allFormulae(forceRefresh: Bool = false) async -> [APIFormula] {
        await cachedFetch([APIFormula].self,
                          path: "formula.json",
                          cacheKey: "formula",
                          maxAge: Self.bulkMaxAge,
                          forceRefresh: forceRefresh) ?? []
    }

    func allCasks(forceRefresh: Bool = false) async -> [APICask] {
        await cachedFetch([APICask].self,
                          path: "cask.json",
                          cacheKey: "cask",
                          maxAge: Self.bulkMaxAge,
                          forceRefresh: forceRefresh) ?? []
    }

    // MARK: - Analytics (popularity)

    func analytics(kind: PackageKind, period: AnalyticsPeriod, forceRefresh: Bool = false) async -> [AnalyticsResponse.Item] {
        let path = kind == .cask
            ? "analytics/cask-install/\(period.rawValue).json"
            : "analytics/install/\(period.rawValue).json"
        let response = await cachedFetch(AnalyticsResponse.self,
                                         path: path,
                                         cacheKey: "analytics-\(kind.rawValue)-\(period.rawValue)",
                                         maxAge: Self.bulkMaxAge,
                                         forceRefresh: forceRefresh)
        return response?.items ?? []
    }

    // MARK: - Per-item detail

    func formulaDetail(_ name: String, forceRefresh: Bool = false) async -> APIFormula? {
        await cachedFetch(APIFormula.self,
                          path: "formula/\(name).json",
                          cacheKey: "formula-\(name)",
                          maxAge: Self.detailMaxAge,
                          forceRefresh: forceRefresh)
    }

    func caskDetail(_ token: String, forceRefresh: Bool = false) async -> APICask? {
        await cachedFetch(APICask.self,
                          path: "cask/\(token).json",
                          cacheKey: "cask-\(token)",
                          maxAge: Self.detailMaxAge,
                          forceRefresh: forceRefresh)
    }
}
