import Foundation

/// Wraps `xcrun simctl --set previews ...`. The `previews` device set is the
/// isolated set Xcode uses for SwiftUI previews; keeping every call here means a
/// future change to that (undocumented) behavior is a one-file fix.
enum SimctlClient {
    static let deviceSet = "previews"
    static let previewShellBundleID = "com.apple.PreviewShell"

    private static func base(_ args: [String]) -> [String] {
        ["simctl", "--set", deviceSet] + args
    }

    nonisolated static func listDevices() async throws -> [PreviewDevice] {
        let result = try await Shell.xcrun(base(["list", "-j", "devices"]))
        guard result.ok else {
            throw ShellError.nonZero(code: result.exitCode, stderr: result.stderr)
        }
        return parseDevices(result.stdout)
    }

    nonisolated static func listApps(_ udid: String) async throws -> [InstalledApp] {
        let result = try await Shell.xcrun(base(["listapps", udid]))
        guard result.ok else {
            throw ShellError.nonZero(code: result.exitCode, stderr: result.stderr)
        }
        return parseApps(result.stdout)
    }

    nonisolated static func setPrivacy(
        udid: String,
        action: PrivacyAction,
        service: PrivacyService,
        bundleID: String
    ) async throws {
        try await runChecked(base(["privacy", udid, action.rawValue, service.argument, bundleID]))
    }

    nonisolated static func shutdown(_ udid: String) async throws {
        try await runChecked(base(["shutdown", udid]))
    }

    nonisolated static func shutdownAll() async throws {
        try await runChecked(base(["shutdown", "all"]))
    }

    nonisolated static func delete(_ udids: [String]) async throws {
        guard !udids.isEmpty else { return }
        try await runChecked(base(["delete"] + udids))
    }

    nonisolated static func deleteAll() async throws {
        try await runChecked(base(["delete", "all"]))
    }

    @discardableResult
    private nonisolated static func runChecked(_ args: [String]) async throws -> ShellResult {
        let result = try await Shell.xcrun(args)
        guard result.ok else {
            throw ShellError.nonZero(code: result.exitCode, stderr: result.stderr)
        }
        return result
    }

    nonisolated static func parseDevices(_ json: String) -> [PreviewDevice] {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let byRuntime = root["devices"] as? [String: [[String: Any]]]
        else {
            return []
        }

        var devices: [PreviewDevice] = []
        for (runtimeID, entries) in byRuntime {
            for entry in entries {
                guard let udid = entry["udid"] as? String,
                      let name = entry["name"] as? String
                else { continue }
                devices.append(
                    PreviewDevice(
                        udid: udid,
                        name: name,
                        runtimeIdentifier: runtimeID,
                        state: entry["state"] as? String ?? "Unknown",
                        isAvailable: entry["isAvailable"] as? Bool ?? false
                    )
                )
            }
        }

        return devices.sorted {
            ($0.isBooted ? 0 : 1, $0.runtimeName, $0.name)
                < ($1.isBooted ? 0 : 1, $1.runtimeName, $1.name)
        }
    }

    /// `listapps` emits an OpenStep-format plist, which PropertyListSerialization
    /// reads directly — no need to shell out to `plutil`.
    nonisolated static func parseApps(_ output: String) -> [InstalledApp] {
        guard let data = output.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let byBundle = plist as? [String: [String: Any]]
        else {
            return []
        }

        var apps: [InstalledApp] = []
        for (bundleID, info) in byBundle {
            let name = (info["CFBundleDisplayName"] as? String)
                ?? (info["CFBundleName"] as? String)
                ?? bundleID
            let type = InstalledApp.AppType(rawValue: info["ApplicationType"] as? String ?? "") ?? .other
            apps.append(
                InstalledApp(
                    bundleID: bundleID,
                    displayName: name,
                    type: type,
                    dataContainer: info["DataContainer"] as? String
                )
            )
        }

        return apps.sorted {
            (($0.type == .user ? 0 : 1), $0.displayName.lowercased())
                < (($1.type == .user ? 0 : 1), $1.displayName.lowercased())
        }
    }
}
