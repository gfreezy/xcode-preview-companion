import Foundation

nonisolated struct InstalledApp: Identifiable, Hashable, Sendable {
    let bundleID: String
    let displayName: String
    let type: AppType
    let dataContainer: String?

    var id: String { bundleID }

    var dataContainerURL: URL? {
        guard let dataContainer else { return nil }
        return URL(string: dataContainer)
    }

    enum AppType: String, Sendable {
        case user = "User"
        case system = "System"
        case other = "Other"
    }
}
