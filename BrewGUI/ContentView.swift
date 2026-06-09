/*
 Want to use NavigationSplitView
 
 See Figma Mockup -> https://www.figma.com/make/MoTDZS2nPFs8mblEF3t6mr/MacOS-UI-for-Homebrew-GUI?p=f&t=9XJDRU31YuUXzhOj-0
 
 
 */

import SwiftUI

struct ContentView: View {
    private var output = CommandRunner.runBrew()
    
    var body: some View {
        NavigationSplitView {
            List {
                Section("Browse") {
                    Label("All Packages", systemImage: "shippingbox")
                }
                Section("Manage") {
                    Label("Installed", systemImage: "arrow.down.circle")
                    Label("Updates", systemImage: "arrow.trianglehead.2.clockwise")
                }
            }
            .navigationTitle("Homebrew")
        } detail: {
            Text("See Installed Packages")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding()
        }
    }
}



#Preview {
    ContentView()
}
