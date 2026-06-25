import SwiftUI
import Observation

/// Drives long-running brew commands (install / uninstall / upgrade / cleanup)
/// and exposes their live streamed output to the UI. A single shared instance
/// is injected into the environment so any screen can start work and the log
/// panel reflects it.
@MainActor
@Observable
final class OperationCenter {

    /// One streamed brew operation and its accumulated log.
    struct Operation: Identifiable {
        let id = UUID()
        let title: String
        var lines: [BrewLogLine] = []
        var isRunning: Bool = true
        var exitCode: Int32?

        var succeeded: Bool { exitCode == 0 }
    }

    private(set) var current: Operation?
    /// Whether the glass log panel should be presented.
    var isLogPresented = false

    var isRunning: Bool { current?.isRunning ?? false }

    /// Run a brew command, streaming output into `current`. Returns whether it
    /// exited cleanly so callers can refresh state / show an alert.
    @discardableResult
    func run(title: String, arguments: [String]) async -> Bool {
        current = Operation(title: title)
        isLogPresented = true

        for await event in BrewProcess.stream(arguments) {
            switch event {
            case .line(let line):
                current?.lines.append(line)
            case .finished(let code):
                current?.exitCode = code
                current?.isRunning = false
            }
        }
        return current?.succeeded ?? false
    }

    func dismissLog() {
        isLogPresented = false
    }
}
