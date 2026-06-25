import Foundation

/// Result of a one-shot brew invocation: captured output plus the exit code so
/// callers can surface real errors instead of guessing from stderr text.
struct BrewResult {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var succeeded: Bool { exitCode == 0 }

    /// stdout, with stderr appended when present — handy for debugging/logs.
    var combined: String {
        let err = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        if err.isEmpty { return stdout }
        return stdout.isEmpty ? err : stdout + "\n" + err
    }
}

/// A single line of streamed subprocess output.
struct BrewLogLine: Identifiable, Hashable {
    let id = UUID()
    let text: String
    /// True when the line came from stderr (brew uses stderr for progress too,
    /// so this is a source tag, not strictly an error).
    let isError: Bool
}

/// Events emitted while streaming a long-running brew command.
enum BrewEvent {
    case line(BrewLogLine)
    case finished(exitCode: Int32)
}

/// Async wrapper around the `brew` binary. Replaces the old synchronous
/// `CommandRunner`: every call runs off the main thread, captures exit codes,
/// and `stream` yields output line-by-line for live install/upgrade logs.
enum BrewProcess {

    // MARK: - Discovery

    /// brew binary path, covering Apple Silicon (`/opt/homebrew`) and Intel
    /// (`/usr/local`). Falls back to the Apple Silicon path so error messages
    /// stay sensible when brew isn't installed at all.
    static var brewPath: String {
        let candidates = ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) } ?? candidates[0]
    }

    /// Whether a usable brew binary is on disk. Drives the first-launch gate.
    static var isBrewInstalled: Bool {
        FileManager.default.isExecutableFile(atPath: brewPath)
    }

    /// Environment for child processes: prepend brew's bin + standard tool paths
    /// so brew can find `git`, `curl`, etc., and quiet auto-update noise.
    private static var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        let brewBin = (brewPath as NSString).deletingLastPathComponent
        let extraPath = "\(brewBin):/usr/bin:/bin:/usr/sbin:/sbin"
        env["PATH"] = extraPath + ":" + (env["PATH"] ?? "")
        env["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        return env
    }

    // MARK: - One-shot run

    /// Run a brew command to completion and return its captured output.
    /// stdout and stderr are read concurrently to avoid pipe-buffer deadlocks.
    @discardableResult
    static func run(_ arguments: [String]) async -> BrewResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: brewPath)
                process.arguments = arguments
                process.environment = environment

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: BrewResult(
                        stdout: "",
                        stderr: "Failed to launch brew: \(error.localizedDescription)",
                        exitCode: -1
                    ))
                    return
                }

                // Drain both pipes on separate queues; a single sequential
                // readToEnd can deadlock if the other buffer fills first.
                var outData = Data()
                var errData = Data()
                let group = DispatchGroup()
                group.enter()
                DispatchQueue.global().async {
                    outData = (try? outPipe.fileHandleForReading.readToEnd()) ?? Data()
                    group.leave()
                }
                group.enter()
                DispatchQueue.global().async {
                    errData = (try? errPipe.fileHandleForReading.readToEnd()) ?? Data()
                    group.leave()
                }

                process.waitUntilExit()
                group.wait()

                continuation.resume(returning: BrewResult(
                    stdout: String(data: outData, encoding: .utf8) ?? "",
                    stderr: String(data: errData, encoding: .utf8) ?? "",
                    exitCode: process.terminationStatus
                ))
            }
        }
    }

    // MARK: - Streaming run

    /// Run a brew command and stream its output line-by-line, finishing with the
    /// exit code. Used by the operation center for live install/upgrade logs.
    /// Cancelling the consuming task terminates the subprocess.
    static func stream(_ arguments: [String]) -> AsyncStream<BrewEvent> {
        AsyncStream { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brewPath)
            process.arguments = arguments
            process.environment = environment

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            func attach(_ pipe: Pipe, isError: Bool) {
                pipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
                    for raw in chunk.split(separator: "\n", omittingEmptySubsequences: false) {
                        let line = String(raw)
                        guard !line.isEmpty else { continue }
                        continuation.yield(.line(BrewLogLine(text: line, isError: isError)))
                    }
                }
            }
            attach(outPipe, isError: false)
            attach(errPipe, isError: true)

            process.terminationHandler = { proc in
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                continuation.yield(.finished(exitCode: proc.terminationStatus))
                continuation.finish()
            }

            continuation.onTermination = { _ in
                if process.isRunning { process.terminate() }
            }

            do {
                try process.run()
            } catch {
                continuation.yield(.line(BrewLogLine(
                    text: "Failed to launch brew: \(error.localizedDescription)",
                    isError: true
                )))
                continuation.yield(.finished(exitCode: -1))
                continuation.finish()
            }
        }
    }
}
