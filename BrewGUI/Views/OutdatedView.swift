import SwiftUI

/// Packages with available upgrades. Per-row upgrade + bulk "Upgrade All",
/// both streamed through the OperationCenter log.
struct OutdatedView: View {
    @State private var model = OutdatedModel()
    @Environment(OperationCenter.self) private var operations

    var body: some View {
        Group {
            if model.isChecking {
                VStack(spacing: Spacing.m) {
                    Text("Checking for updates…").foregroundStyle(.secondary)
                    CheckingProgressBar().frame(width: 240)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.outdated.isEmpty {
                ContentUnavailableView("All up to date",
                                       systemImage: "checkmark.seal",
                                       description: Text("Every installed package is on its latest version."))
            } else {
                list
            }
        }
        .navigationTitle("Outdated")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    Task { await model.refresh() }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(model.isChecking)
                .accessibilityLabel("Check for updates")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button {
                    Task { await model.upgradeAll(using: operations) }
                } label: {
                    Label("Upgrade All", systemImage: "arrow.up.circle.fill")
                }
                .disabled(model.outdated.isEmpty || operations.isRunning)
                .accessibilityLabel("Upgrade all packages")
            }
        }
        .alert("Upgrade failed",
               isPresented: Binding(get: { model.errorMessage != nil },
                                    set: { if !$0 { model.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
        .task {
            if model.outdated.isEmpty && !model.isChecking { await model.refresh() }
        }
    }

    private var list: some View {
        List {
            Section("Outdated (\(model.outdated.count))") {
                ForEach(model.outdated, id: \.self) { name in
                    HStack(spacing: Spacing.m) {
                        IconTile(systemName: "arrow.up.circle")

                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.body.weight(.semibold))
                            Text("Update available")
                                .font(.caption)
                                .foregroundStyle(BrewColor.amberDeep)
                        }
                        Spacer()
                        if model.upgrading.contains(name) {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Upgrade") {
                                Task { await model.upgrade(name, using: operations) }
                            }
                            .buttonStyle(.glass)
                            .controlSize(.small)
                            .disabled(operations.isRunning)
                            .accessibilityLabel("Upgrade \(name)")
                        }
                    }
                    .padding(.vertical, Theme.rowVerticalPadding)
                }
            }
        }
        .listStyle(.inset)
    }
}
