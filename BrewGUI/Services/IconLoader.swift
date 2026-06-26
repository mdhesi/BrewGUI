import AppKit

/// Loads and caches small package icons (homepage favicons). Kept in memory via
/// NSCache and de-duplicated per URL so a scrolling list doesn't refetch the same
/// icon repeatedly. Favicons are tiny (~1–5 KB), so an in-memory cache is plenty.
@MainActor
final class IconLoader {
    static let shared = IconLoader()

    private let cache = NSCache<NSURL, NSImage>()
    private var inFlight: [URL: Task<NSImage?, Never>] = [:]

    /// The icon for `url`, from cache if present, otherwise fetched once and
    /// cached. Returns nil if the fetch fails or the data isn't an image, so the
    /// caller can fall back to a placeholder.
    func image(for url: URL) async -> NSImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let existing = inFlight[url] { return await existing.value }

        let task = Task<NSImage?, Never> { [cache] in
            defer { inFlight[url] = nil }
            guard let (data, response) = try? await URLSession.shared.data(from: url),
                  (response as? HTTPURLResponse)?.statusCode == 200,
                  let image = NSImage(data: data) else { return nil }
            cache.setObject(image, forKey: url as NSURL)
            return image
        }
        inFlight[url] = task
        return await task.value
    }
}
