import Darwin
import Foundation

/// Finds and terminates preview-specific processes. Deliberately scoped to the
/// preview host/daemon — NOT SimRenderServer / launchd_sim / simdiskimaged, which
/// back the whole simulator subsystem and shouldn't be killed casually.
enum ProcessManager {
    nonisolated static let knownNames = ["XCPreviewAgent", "PreviewShell", "previewsd"]

    nonisolated static func runningPreviewProcesses() async throws -> [PreviewProcess] {
        let result = try await Shell.run("/bin/ps", ["-axo", "pid=,command="])
        guard result.ok else {
            throw ShellError.nonZero(code: result.exitCode, stderr: result.stderr)
        }
        return parse(result.stdout)
    }

    nonisolated static func parse(_ output: String) -> [PreviewProcess] {
        var processes: [PreviewProcess] = []
        for line in output.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let spaceIndex = trimmed.firstIndex(of: " "),
                  let pid = Int32(trimmed[..<spaceIndex])
            else { continue }
            let command = String(trimmed[trimmed.index(after: spaceIndex)...]).trimmingCharacters(in: .whitespaces)
            if let name = knownNames.first(where: { command.contains($0) }) {
                processes.append(PreviewProcess(pid: pid, name: name, command: command))
            }
        }
        return processes.sorted { $0.pid < $1.pid }
    }

    nonisolated static func kill(_ pids: [Int32]) {
        for pid in pids {
            Darwin.kill(pid, SIGKILL)
        }
    }
}
