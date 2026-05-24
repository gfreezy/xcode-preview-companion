import Foundation

nonisolated struct PreviewProcess: Identifiable, Hashable, Sendable {
    let pid: Int32
    let name: String
    let command: String

    var id: Int32 { pid }
}
