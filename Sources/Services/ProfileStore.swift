import Foundation

/// Persists permission profiles as JSON in Application Support, keyed by bundle id.
nonisolated enum ProfileStore {
    static var fileURL: URL {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "XcodePreviewCompanion")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appending(path: "profiles.json")
    }

    static func load() -> [String: PermissionProfile] {
        guard let data = try? Data(contentsOf: fileURL),
              let profiles = try? JSONDecoder().decode([String: PermissionProfile].self, from: data)
        else {
            return [:]
        }
        return profiles
    }

    static func save(_ profiles: [String: PermissionProfile]) {
        guard let data = try? JSONEncoder().encode(profiles) else { return }
        try? data.write(to: fileURL)
    }
}
