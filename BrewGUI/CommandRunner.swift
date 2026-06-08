/*
 1. Create Process - Tell the OS "I want to spawn a subprocess"
 2. Configure it - "Run this executable (brew), with these arguments (list --formula)"
 3. Set up communication - "Capture the output so I can read it" (that's what Pipe does-it's inter-process communication)
 4. Execute & wait - "Run it, and don't proceed until it's done"
 5. Parse output - "Convert the raw bytes the subprocess produced into text my app understands"
 6. Return result - "Give this data back to ContentView so it can render it"
 */

import Foundation

class CommandRunner {
    static func runBrew() -> String {
        
        // TODO: Create a Process object
        let brewList = Process()
        
        // TODO: Set the executable path to /usr/local/bin/brew
        brewList.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/brew")
        
        // TODO: Set the arguments
        let arguments = ["list"]
        brewList.arguments = arguments
        
        // TODO: Create a Pipe to capture output
        // Pipe so we can caputure the output of the process and redirect it to a buffer that the app can read from
        let pipe = Pipe()
        
        // TODO: Assign the pipe to process.standardOutput
        brewList.standardOutput = pipe
        do {
            // TODO: Run the process and wait for it to finish
            try brewList.run()
            brewList.waitUntilExit()
            
            // TODO: Read data from the pipe
            let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            return output

        } catch {
            return "Error: \(error)"
        }
    }
}
