import Foundation

/// On-disk JSON cache for Homebrew API responses, under
/// `~/Library/Application Support/BrewGUI/cache/`. Each entry is a plain JSON
/// file; its modification date is the cache timestamp. An `actor` so concurrent
/// fetches can read/write safely.
actor APICache {
    static let shared = APICache()

    private let directory: URL

    init() {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrewGUI/cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        directory = base
    }

    private func url(for key: String) -> URL {
        // Keep keys filesystem-safe (analytics keys contain slashes).
        let safe = key.replacingOccurrences(of: "/", with: "-")
        return directory.appendingPathComponent("\(safe).json")
    }

    /// Decoded cached value plus the time it was written, if present and valid.
    func load<T: Decodable>(_ type: T.Type, key: String) -> (value: T, date: Date)? {
        let fileURL = url(for: key)
        guard let data = try? Data(contentsOf: fileURL),
              let value = try? JSONDecoder().decode(T.self, from: data) else { return nil }
        let date = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.modificationDate] as? Date) ?? nil
        return (value, date ?? .distantPast)
    }

    /// Persist a value; failures are non-fatal (the network result is still used).
    func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: url(for: key), options: .atomic)
    }
}
