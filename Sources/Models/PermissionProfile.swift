import Foundation

/// What a given app wants auto-granted whenever a fresh preview device appears.
nonisolated struct PermissionProfile: Codable, Sendable, Hashable {
    var services: Set<String> = []
    var includePreviewShell: Bool = false
}
