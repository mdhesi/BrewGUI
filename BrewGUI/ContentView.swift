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
    private var packages: [String] { // computed property, runs everytime packages is used
        output
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines)} // $0 means current elements
            .filter { !$0.isEmpty }
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
                Text("Updates")
                    .font(.title)
                    .padding()
            }
        }
    }
}



#Preview {
    ContentView()
}
