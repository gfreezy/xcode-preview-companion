import Foundation

nonisolated struct PreviewDevice: Identifiable, Hashable, Sendable {
    let udid: String
    let name: String
    let runtimeIdentifier: String
    let state: String
    let isAvailable: Bool

    var id: String { udid }
    var isBooted: Bool { state == "Booted" }

    /// "com.apple.CoreSimulator.SimRuntime.iOS-26-5" -> "iOS 26.5"
    var runtimeName: String {
        guard let range = runtimeIdentifier.range(of: ".SimRuntime.") else {
            return runtimeIdentifier
        }
        let suffix = runtimeIdentifier[range.upperBound...]
        let parts = suffix.split(separator: "-").map(String.init)
        guard let platform = parts.first else { return String(suffix) }
        let version = parts.dropFirst().joined(separator: ".")
        return version.isEmpty ? platform : "\(platform) \(version)"
    }
}
