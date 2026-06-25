import SwiftUI

/// Recently removed packages with one-click reinstall, backed by the persisted
/// RemovalHistoryStore. Reinstalls stream through the OperationCenter.
struct HistoryView: View {
    @EnvironmentObject private var history: RemovalHistoryStore
    @Environment(OperationCenter.self) private var operations
    @State private var reinstalling: Set<String> = []

    var body: some View {
        Group {
            if history.items.isEmpty {
                ContentUnavailableView("No removal history",
                                       systemImage: "clock.arrow.circlepath",
                                       description: Text("Packages you remove will appear here so you can reinstall them."))
            } else {
                list
            }
        }
        .navigationTitle("History")
    }

    private var list: some View {
        List {
            Section("Recently Removed") {
                ForEach(history.items) { item in
                    HStack(spacing: Spacing.m) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            Text(item.name).font(.body)
                            Text("Removed \(item.removedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: Spacing.m)
                        if reinstalling.contains(item.name) {
                            ProgressView().controlSize(.small)
                        } else {
                            Button {
                                reinstall(item.name)
                            } label: {
                                Label("Reinstall", systemImage: "arrow.down.circle")
                            }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                            .disabled(operations.isRunning)
                            .accessibilityLabel("Reinstall \(item.name)")
                        }
                    }
                    .padding(.vertical, Theme.rowVerticalPadding)
                }
            }
        }
        .listStyle(.inset)
    }

    private func reinstall(_ name: String) {
        guard !reinstalling.contains(name) else { return }
        reinstalling.insert(name)
        Task {
            let ok = await operations.run(title: "Reinstalling \(name)", arguments: ["install", name])
            if ok { history.clear(name) }
            reinstalling.remove(name)
        }
    }
}
