import Foundation
import Combine

/// One entry in the removal history. `name` is the brew package; `removedAt` is when we removed it.
struct RemovedPackage: Identifiable, Codable, Hashable {
    var id: String { name } // a package name is unique enough to act as the identity
    let name: String
    let removedAt: Date
}

/// ObservableObject so SwiftUI views re-render whenever `items` changes.
/// @MainActor keeps all mutation on the main thread (the views read it there).
@MainActor
final class RemovalHistoryStore: ObservableObject {
    @Published private(set) var items: [RemovedPackage] = []

    private let fileURL: URL

    init() {
        let fm = FileManager.default
        let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BrewGUI", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("removal-history.json")
        load()
    }

    /// Record that a package was removed. Newest entry wins if it already exists.
    func record(_ name: String) {
        items.removeAll { $0.name == name }
        items.insert(RemovedPackage(name: name, removedAt: Date()), at: 0)
        save()
    }

    /// Drop a package from history (e.g. after it has been reinstalled).
    func clear(_ name: String) {
        items.removeAll { $0.name == name }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([RemovedPackage].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: fileURL)
    }
}
