/*
 Want to use NavigationSplitView

 See Figma Mockup -> https://www.figma.com/make/MoTDZS2nPFs8mblEF3t6mr/MacOS-UI-for-Homebrew-GUI?p=f&t=9XJDRU31YuUXzhOj-0


 */

import SwiftUI

enum SidebarItem: Hashable {
    case allPackages
    case installed
    case updates
}

struct ContentView: View {
    @StateObject private var history = RemovalHistoryStore()
    @State private var selection: SidebarItem? = .allPackages

    // Installed packages are loaded on demand and refreshed after install/uninstall.
    @State private var installedPackages: [InstalledPackage] = []
    @State private var isLoadingPackages = false

    // Per-package work in progress (uninstall / reinstall) so each row can show its own spinner.
    @State private var busyPackages: Set<String> = []

    // Updates state.
    @State private var isUpdating = false
    @State private var outdatedPackages: [String] = []
    @State private var upgradingPackages: Set<String> = []

    // MARK: - Parsing helpers

    /// Parse `brew list --versions` style output ("name 1.2.3") into packages.
    /// `isCask` tags where the line came from so the UI can distinguish the two.
    private func parseVersioned(_ output: String, isCask: Bool) -> [InstalledPackage] {
        output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Warning:") && !$0.hasPrefix("Error:") }
            .compactMap { line in
                let parts = line.split(separator: " ", maxSplits: 1)
                guard let name = parts.first.map(String.init) else { return nil }
                let version = parts.count > 1 ? String(parts[1]) : ""
                return InstalledPackage(name: name, version: version, isCask: isCask)
            }
    }

    /// Load formulae AND casks (each with versions), merged and sorted by name.
    /// Runs synchronously — always call it from a background queue.
    private func fetchInstalled() -> [InstalledPackage] {
        let formulae = parseVersioned(CommandRunner.runBrew(arguments: ["list", "--versions"]), isCask: false)
        let casks = parseVersioned(CommandRunner.runBrew(arguments: ["list", "--cask", "--versions"]), isCask: true)
        return (formulae + casks).sorted { $0.name.lowercased() < $1.name.lowercased() }
    }

    /// `brew outdated --verbose` gives "name (old) < (new)"; we just want the name.
    private func parseOutdated(from output: String) -> [String] {
        output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .map { line in
                if let name = line.split(separator: " ").first { return String(name) }
                return line
            }
    }

    // MARK: - Actions

    private func loadInstalled() {
        guard !isLoadingPackages else { return }
        isLoadingPackages = true
        DispatchQueue.global(qos: .userInitiated).async {
            let parsed = fetchInstalled()
            DispatchQueue.main.async {
                self.installedPackages = parsed
                self.isLoadingPackages = false
            }
        }
    }

    private func uninstall(_ pkg: String) {
        guard !busyPackages.contains(pkg) else { return }
        busyPackages.insert(pkg)
        DispatchQueue.global(qos: .userInitiated).async {
            _ = CommandRunner.runBrew(arguments: ["uninstall", pkg])
            let parsed = fetchInstalled()
            let removed = !parsed.contains { $0.name == pkg } // only log to history if it actually went away
            DispatchQueue.main.async {
                self.installedPackages = parsed
                self.busyPackages.remove(pkg)
                if removed { self.history.record(pkg) }
            }
        }
    }

    private func reinstall(_ pkg: String) {
        guard !busyPackages.contains(pkg) else { return }
        busyPackages.insert(pkg)
        DispatchQueue.global(qos: .userInitiated).async {
            _ = CommandRunner.runBrew(arguments: ["install", pkg])
            let parsed = fetchInstalled()
            let installed = parsed.contains { $0.name == pkg }
            DispatchQueue.main.async {
                self.installedPackages = parsed
                self.busyPackages.remove(pkg)
                if installed { self.history.clear(pkg) } // back to installed, drop from history
            }
        }
    }

    private func refreshUpdates() {
        guard !isUpdating else { return }
        isUpdating = true
        outdatedPackages = []
        DispatchQueue.global(qos: .userInitiated).async {
            _ = CommandRunner.runBrew(arguments: ["update"]) // refresh metadata
            let outdatedOutput = CommandRunner.runBrew(arguments: ["outdated", "--verbose"]) // get outdated list
            let parsed = parseOutdated(from: outdatedOutput)
            DispatchQueue.main.async {
                self.outdatedPackages = parsed
                self.isUpdating = false
            }
        }
    }

    private func upgrade(_ pkg: String) {
        guard !upgradingPackages.contains(pkg) else { return }
        upgradingPackages.insert(pkg)
        DispatchQueue.global(qos: .userInitiated).async {
            _ = CommandRunner.runBrew(arguments: ["upgrade", pkg])
            let parsed = parseOutdated(from: CommandRunner.runBrew(arguments: ["outdated", "--verbose"]))
            DispatchQueue.main.async {
                self.outdatedPackages = parsed
                self.upgradingPackages.remove(pkg)
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) { // $ is for state vars, it is so that List can READ and WRITE, no dollar sign means just READ
                Section("Browse") {
                    Label("All Packages", systemImage: "shippingbox").tag(SidebarItem.allPackages)
                }
                Section("Manage") {
                    Label("Installed", systemImage: "arrow.down.circle").tag(SidebarItem.installed)
                    Label("Updates", systemImage: "arrow.trianglehead.2.clockwise").tag(SidebarItem.updates)
                }
            }
            .navigationTitle("Homebrew")
        } detail: {
            switch selection {
            case .allPackages:
                allPackagesPage

            case .installed, .none:
                installedPage

            case .updates:
                updatesPage
            }
        }
    }

    // MARK: - All Packages page (manage installed + removal history)

    @ViewBuilder private var allPackagesPage: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("All Packages")
                    .font(.title)
                Spacer()
                if isLoadingPackages { ProgressView().controlSize(.small) }
                Button(action: { loadInstalled() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isLoadingPackages)
            }
            .padding([.top, .horizontal])

            List {
                Section("Installed (\(installedPackages.count))") {
                    if installedPackages.isEmpty {
                        Text(isLoadingPackages ? "Loading…" : "No packages found")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(installedPackages) { pkg in
                            PackageRow(
                                package: pkg,
                                isBusy: busyPackages.contains(pkg.name),
                                onRemove: { uninstall(pkg.name) }
                            )
                        }
                    }
                }

                if !history.items.isEmpty {
                    Section("Recently Removed") {
                        ForEach(history.items) { item in
                            HStack(spacing: 12) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 24)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name)
                                        .font(.body)
                                    Text("Removed \(item.removedAt.formatted(date: .abbreviated, time: .shortened))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 12)
                                if busyPackages.contains(item.name) {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Button(action: { reinstall(item.name) }) {
                                        Label("Reinstall", systemImage: "arrow.down.circle")
                                    }
                                    .buttonStyle(.glassProminent)
                                    .controlSize(.small)
                                    .accessibilityLabel("Reinstall \(item.name)")
                                }
                            }
                            .padding(.vertical, 6)
                        }
                    }
                }
            }
            .listStyle(.inset)
        }
        .onAppear {
            if installedPackages.isEmpty { loadInstalled() }
        }
    }

    // MARK: - Installed page (simple read-only list)

    @ViewBuilder private var installedPage: some View {
        List(installedPackages) { pkg in
            PackageRow(package: pkg)
        }
        .listStyle(.inset)
        .onAppear {
            if installedPackages.isEmpty { loadInstalled() }
        }
    }

    // MARK: - Updates page

    @ViewBuilder private var updatesPage: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Updates")
                    .font(.title)
                Spacer()
                Button(action: { refreshUpdates() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .disabled(isUpdating)
            }
            .padding([.top, .horizontal])

            if isUpdating {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Checking for updates…")
                        .foregroundStyle(.secondary)
                    CheckingProgressBar()
                }
                .padding(.horizontal)
            } else if outdatedPackages.isEmpty {
                Text("All up to date")
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                List(outdatedPackages, id: \.self) { pkg in
                    HStack {
                        Image(systemName: "arrow.trianglehead.2.clockwise")
                            .foregroundStyle(.secondary)
                        Text(pkg)
                        Spacer()
                        if upgradingPackages.contains(pkg) {
                            ProgressView().controlSize(.small)
                        } else {
                            Button("Upgrade") { upgrade(pkg) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        }
        .onAppear {
            if outdatedPackages.isEmpty && !isUpdating {
                refreshUpdates()
            }
        }
    }
}



#Preview {
    ContentView()
}
