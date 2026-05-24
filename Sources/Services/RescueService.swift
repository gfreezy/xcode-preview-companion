import Foundation

enum RescueService {
    struct Options: Sendable {
        var killProcesses = true
        var shutdownDevices = true
        var deleteDevices = true
        var clearPreviewsUserData = true
        var clearDerivedData = false
        var derivedDataProjectName = ""
    }

    /// Runs the selected recovery steps in a safe order: kill stuck processes,
    /// shut down + delete preview devices, then clear cache directories.
    @concurrent
    static func fixPreviews(_ options: Options) async throws -> [String] {
        var log: [String] = []

        if options.killProcesses {
            let processes = (try? await ProcessManager.runningPreviewProcesses()) ?? []
            ProcessManager.kill(processes.map(\.pid))
            log.append("Killed \(processes.count) preview process(es)")
        }

        if options.shutdownDevices {
            try? await SimctlClient.shutdownAll()
            log.append("Shut down preview devices")
        }

        if options.deleteDevices {
            try await SimctlClient.deleteAll()
            log.append("Deleted preview devices")
        }

        if options.clearPreviewsUserData {
            let count = try await PreviewPaths.clearPreviewsUserData()
            log.append("Cleared \(count) item(s) from UserData/Previews")
        }

        if options.clearDerivedData {
            let count = try await PreviewPaths.clearDerivedData(matching: options.derivedDataProjectName)
            log.append("Removed \(count) DerivedData folder(s)")
        }

        return log
    }
}
