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

    /// Set when a brew op fails because the package lives in an untrusted
    /// third-party tap. Homebrew refuses to load such casks/formulae unless they
    /// are trusted, but it tells us the exact `brew trust …` command to run — so
    /// rather than dead-ending on the error we offer to trust it and retry.
    private(set) var trustPrompt: TrustPrompt?

    /// A parsed "untrusted tap" failure: the tap, the `brew trust …` arguments
    /// Homebrew suggested, and the original command to retry once trusted.
    struct TrustPrompt: Identifiable {
        let id = UUID()
        let tap: String
        let trustArguments: [String]
        let retryTitle: String
        let retryArguments: [String]
    }

    var isRunning: Bool { current?.isRunning ?? false }

    /// Run a brew command, streaming output into `current`. Returns whether it
    /// exited cleanly so callers can refresh state / show an alert.
    @discardableResult
    func run(title: String, arguments: [String]) async -> Bool {
        current = Operation(title: title)
        trustPrompt = nil
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

        let ok = current?.succeeded ?? false
        if !ok {
            trustPrompt = Self.parseUntrustedTap(in: current?.lines ?? [],
                                                 retryTitle: title,
                                                 retryArguments: arguments)
        }
        return ok
    }

    /// Run the `brew trust …` command Homebrew suggested, then retry the original
    /// operation. Surfaced from the log panel when an op hit an untrusted tap.
    @discardableResult
    func trustAndRetry() async -> Bool {
        guard let prompt = trustPrompt else { return false }
        trustPrompt = nil

        let trusted = await run(title: "Trusting \(prompt.tap)", arguments: prompt.trustArguments)
        guard trusted else { return false }
        return await run(title: prompt.retryTitle, arguments: prompt.retryArguments)
    }

    func dismissLog() {
        isLogPresented = false
    }

    /// Detect Homebrew's "Refusing to load … from untrusted tap" failure and pull
    /// out the `brew trust …` command it recommends, e.g.:
    ///
    ///   Error: Refusing to load cask matheuzgomes/snip/snip-notes from untrusted
    ///   tap matheuzgomes/snip.
    ///   Run 'brew trust --cask matheuzgomes/snip/snip-notes' or 'brew trust
    ///   matheuzgomes/snip' to trust it.
    ///
    /// We prefer the first suggested form (it scopes the trust to the single
    /// cask/formula rather than the whole tap).
    static func parseUntrustedTap(in lines: [BrewLogLine],
                                  retryTitle: String,
                                  retryArguments: [String]) -> TrustPrompt? {
        // brew can wrap the message across lines, so match against the joined text.
        let text = lines.map(\.text).joined(separator: " ")
        guard text.contains("untrusted tap") else { return nil }

        guard let suggested = firstMatch(#"brew trust ([^'\n]+)"#, in: text) else { return nil }
        let trustArguments = ["trust"] + suggested
            .split(whereSeparator: { $0 == " " })
            .map(String.init)
        guard trustArguments.count > 1 else { return nil }

        let tap = firstMatch(#"untrusted tap\s+([^\s.]+)"#, in: text) ?? "this tap"
        return TrustPrompt(tap: tap,
                           trustArguments: trustArguments,
                           retryTitle: retryTitle,
                           retryArguments: retryArguments)
    }

    /// First capture group of `pattern` in `text`, trimmed, or nil.
    private static func firstMatch(_ pattern: String, in text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captured = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[captured]).trimmingCharacters(in: .whitespaces)
    }
}
