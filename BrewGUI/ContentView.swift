import SwiftUI

struct ContentView: View {
    private var output = CommandRunner.runBrew()

    var body: some View {
        ScrollView {
            Text(output)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled)
                .font(.system(.body, design: .monospaced))
        }
            
    }
}
