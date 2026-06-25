import Foundation

class CommandRunner {
    // Backward-compatible: default behavior is to run `brew list`.
    static func runBrew() -> String {
        return runBrew(arguments: ["list"]) 
    }
}

extension CommandRunner {
    /// Generic process runner that executes an arbitrary executable with arguments and returns combined stdout/stderr as String.
    @discardableResult
    static func run(_ executablePath: String, _ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe /// capture stderr as well for easier debugging

        do {
            try process.run()
            process.waitUntilExit()
            let data = try pipe.fileHandleForReading.readToEnd() ?? Data()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return "Error: \(error)"
        }
    }

    /// Resolves the brew binary path for Apple Silicon and Intel macOS installs.
    static var brewPath: String {
        if FileManager.default.fileExists(atPath: "/opt/homebrew/bin/brew") {
            return "/opt/homebrew/bin/brew"
        } else {
            return "/usr/local/bin/brew"
        }
    }

    /// Convenience runner for Homebrew commands. Pass arguments like ["outdated", "--verbose"].
    @discardableResult
    static func runBrew(arguments: [String]) -> String {
        return run(brewPath, arguments)
    }
}
