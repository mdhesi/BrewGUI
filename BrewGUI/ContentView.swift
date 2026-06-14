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
    private var output = CommandRunner.runBrew()
    @State private var selection: SidebarItem? = .allPackages
    @State private var isUpdating = false
    @State private var outdatedPackages: [String] = []
    private var packages: [String] { // computed property, runs everytime packages is used
        output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines)} // $0 means current elements
            .filter { !$0.isEmpty }
    }
    
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

    var body: some View {
        NavigationSplitView {
            List (selection: $selection) { // $ is for state vars, it is so that List can READ and WRITE, no dollar sign means just READ
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
                Text("All Packages")

            case .installed, .none:
                
                List(packages, id: \.self) { pkg in
                    HStack {
                        Image(systemName: "shippingbox")
                            .foregroundStyle(.secondary)
                        Text(pkg)
                    }
                }

            case .updates:
                VStack(alignment: .leading) {
                    HStack {
                        Text("Updates")
                            .font(.title)
                        Spacer()
                        Button(action: { refreshUpdates() }) {
                            if isUpdating {
                                ProgressView()
                            } else {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isUpdating)
                    }
                    .padding([.top, .horizontal])

                    if isUpdating {
                        Text("Checking for updates…")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else if outdatedPackages.isEmpty {
                        Text("All up to date")
                            .foregroundStyle(.secondary)
                            .padding()
                    } else {
                        List(outdatedPackages, id: \.self) { pkg in
                            HStack {
                                Image(systemName: "arrow.trianglehead.2.clockwise")
                                    .foregroundStyle(.secondary)
                                Text(pkg)
                                Spacer()
                                Button("Upgrade") {
                                    DispatchQueue.global(qos: .userInitiated).async {
                                        _ = CommandRunner.runBrew(arguments: ["upgrade", pkg])
                                        let outdatedOutput = CommandRunner.runBrew(arguments: ["outdated", "--verbose"]) 
                                        let parsed = parseOutdated(from: outdatedOutput)
                                        DispatchQueue.main.async {
                                            self.outdatedPackages = parsed
                                        }
                                    }
                                }
                                .buttonStyle(.borderedProminent)
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
    }
}



#Preview {
    ContentView()
}

