import Foundation

nonisolated struct ShellResult: Sendable {
    let stdout: String
    let stderr: String
    let exitCode: Int32

    var ok: Bool { exitCode == 0 }
}

nonisolated enum ShellError: Error, LocalizedError {
    case launchFailed(String)
    case nonZero(code: Int32, stderr: String)

    var errorDescription: String? {
        switch self {
        case .launchFailed(let message):
            "Failed to launch process: \(message)"
        case .nonZero(_, let stderr):
            stderr.isEmpty ? "Command failed." : stderr.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}

/// Runs subprocesses off the main actor. `@concurrent` forces execution on the
/// concurrent executor so the blocking `Process` calls never stall the UI.
enum Shell {
    @concurrent
    static func run(_ launchPath: String, _ arguments: [String]) async throws -> ShellResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            throw ShellError.launchFailed(error.localizedDescription)
        }

        // Drain both pipes concurrently to avoid a full-buffer deadlock.
        async let outData = readToEnd(outPipe.fileHandleForReading)
        async let errData = readToEnd(errPipe.fileHandleForReading)
        let (out, err) = await (outData, errData)
        process.waitUntilExit()

        return ShellResult(
            stdout: String(decoding: out, as: UTF8.self),
            stderr: String(decoding: err, as: UTF8.self),
            exitCode: process.terminationStatus
        )
    }

    @concurrent
    static func xcrun(_ arguments: [String]) async throws -> ShellResult {
        try await run("/usr/bin/xcrun", arguments)
    }

    @concurrent
    private static func readToEnd(_ handle: FileHandle) async -> Data {
        handle.readDataToEndOfFile()
    }
}
