import Foundation

nonisolated enum PreviewPaths {
    static var home: URL { FileManager.default.homeDirectoryForCurrentUser }

    static var previewsRoot: URL {
        home.appending(path: "Library/Developer/Xcode/UserData/Previews")
    }

    static var deviceSet: URL {
        previewsRoot.appending(path: "Simulator Devices")
    }

    static var derivedData: URL {
        home.appending(path: "Library/Developer/Xcode/DerivedData")
    }

    static func deviceDataDir(_ udid: String) -> URL {
        deviceSet.appending(path: udid).appending(path: "data")
    }

    static func tccDir(_ udid: String) -> URL {
        deviceDataDir(udid).appending(path: "Library/TCC")
    }

    /// Removes everything inside `UserData/Previews` but keeps the folder itself.
    /// Run only after `simctl delete all` so simctl-managed devices are gone first.
    @concurrent
    static func clearPreviewsUserData() async throws -> Int {
        try clearContents(of: previewsRoot)
    }

    /// Removes DerivedData subfolders whose name starts with `prefix` (the project
    /// name). Empty prefix is a no-op so we never wipe unrelated projects.
    @concurrent
    static func clearDerivedData(matching prefix: String) async throws -> Int {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(at: derivedData, includingPropertiesForKeys: nil) else {
            return 0
        }
        var removed = 0
        for entry in entries where entry.lastPathComponent.hasPrefix(trimmed) {
            try fm.removeItem(at: entry)
            removed += 1
        }
        return removed
    }

    /// Copies a file into the app sandbox's Documents folder, creating it if needed.
    @concurrent
    static func inject(fileAt source: URL, intoSandbox dataContainer: URL) async throws -> URL {
        let documents = dataContainer.appending(path: "Documents")
        let fm = FileManager.default
        try fm.createDirectory(at: documents, withIntermediateDirectories: true)
        let destination = documents.appending(path: source.lastPathComponent)
        if fm.fileExists(atPath: destination.path) {
            try fm.removeItem(at: destination)
        }
        try fm.copyItem(at: source, to: destination)
        return destination
    }

    @concurrent
    static func directorySize(_ url: URL) async -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey]
        ) else { return 0 }

        var total: Int64 = 0
        while let fileURL = enumerator.nextObject() as? URL {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }

    private static func clearContents(of directory: URL) throws -> Int {
        let fm = FileManager.default
        guard fm.fileExists(atPath: directory.path) else { return 0 }
        let entries = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        var removed = 0
        for entry in entries {
            try fm.removeItem(at: entry)
            removed += 1
        }
        return removed
    }
}
