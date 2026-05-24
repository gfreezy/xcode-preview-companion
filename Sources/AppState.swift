import Foundation
import Observation

@Observable
final class AppState {
    var devices: [PreviewDevice] = []
    var selectedDeviceID: String?
    var isLoading = false
    var errorMessage: String?

    // Permissions
    var apps: [InstalledApp] = []
    var selectedAppID: String?
    var applyToPreviewShell = false
    var actionMessage: String?

    // Rescue
    var processes: [PreviewProcess] = []
    var rescueOptions = RescueService.Options()
    var rescueLog: [String] = []

    // Files
    var previewsCacheSize: Int64 = 0
    var derivedDataSize: Int64 = 0

    // Profiles / auto-reapply
    var profiles: [String: PermissionProfile] = [:]
    var autoReapplyEnabled = false
    private var autoGrantTask: Task<Void, Never>?
    private var appliedDeviceIDs: Set<String> = []

    init() {
        profiles = ProfileStore.load()
    }

    var selectedDevice: PreviewDevice? {
        if let id = selectedDeviceID, let match = devices.first(where: { $0.id == id }) {
            return match
        }
        return devices.first
    }

    var selectedApp: InstalledApp? {
        if let id = selectedAppID, let match = apps.first(where: { $0.id == id }) {
            return match
        }
        return apps.first(where: { $0.type == .user }) ?? apps.first
    }

    func refresh() async {
        isLoading = true
        errorMessage = nil
        do {
            let list = try await SimctlClient.listDevices()
            devices = list
            if selectedDeviceID == nil || !list.contains(where: { $0.id == selectedDeviceID }) {
                selectedDeviceID = list.first(where: \.isBooted)?.id ?? list.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func shutdownAndDelete(_ device: PreviewDevice) async {
        await perform {
            try? await SimctlClient.shutdown(device.udid)
            try await SimctlClient.delete([device.udid])
        }
    }

    func shutdown(_ device: PreviewDevice) async {
        await perform {
            try await SimctlClient.shutdown(device.udid)
        }
    }

    func deleteAll() async {
        await perform {
            try? await SimctlClient.shutdownAll()
            try await SimctlClient.deleteAll()
        }
    }

    func loadApps() async {
        guard let device = selectedDevice else {
            apps = []
            selectedAppID = nil
            return
        }
        do {
            let list = try await SimctlClient.listApps(device.udid)
            apps = list
            if selectedAppID == nil || !list.contains(where: { $0.id == selectedAppID }) {
                selectedAppID = list.first(where: { $0.type == .user })?.id ?? list.first?.id
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func applyPrivacy(_ action: PrivacyAction, _ service: PrivacyService) async {
        guard let device = selectedDevice, let app = selectedApp else { return }
        var targets = [app.bundleID]
        if applyToPreviewShell {
            targets.append(SimctlClient.previewShellBundleID)
        }

        isLoading = true
        errorMessage = nil
        actionMessage = nil
        do {
            for bundleID in targets {
                try await SimctlClient.setPrivacy(
                    udid: device.udid, action: action, service: service, bundleID: bundleID
                )
            }
            actionMessage = "\(action.label) \(service.displayName) for \(targets.joined(separator: ", "))"
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadProcesses() async {
        do {
            processes = try await ProcessManager.runningPreviewProcesses()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func killProcesses(_ pids: [Int32]) async {
        ProcessManager.kill(pids)
        await loadProcesses()
    }

    func runRescue() async {
        isLoading = true
        errorMessage = nil
        rescueLog = []
        do {
            rescueLog = try await RescueService.fixPreviews(rescueOptions)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
        await refresh()
        await loadProcesses()
    }

    func profile(for bundleID: String) -> PermissionProfile {
        profiles[bundleID] ?? PermissionProfile()
    }

    func isInProfile(_ service: PrivacyService) -> Bool {
        guard let app = selectedApp else { return false }
        return profile(for: app.bundleID).services.contains(service.rawValue)
    }

    func toggleProfile(_ service: PrivacyService) {
        guard let app = selectedApp else { return }
        var entry = profile(for: app.bundleID)
        if entry.services.contains(service.rawValue) {
            entry.services.remove(service.rawValue)
        } else {
            entry.services.insert(service.rawValue)
        }
        entry.includePreviewShell = applyToPreviewShell
        profiles[app.bundleID] = entry
        ProfileStore.save(profiles)
    }

    func setAutoReapply(_ enabled: Bool) {
        autoReapplyEnabled = enabled
        autoGrantTask?.cancel()
        appliedDeviceIDs = []
        guard enabled else { return }
        autoGrantTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.reapplyProfiles()
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }

    /// Grants each app's profiled services only when a *new* booted device shows
    /// up — re-granting an already-set permission would terminate the live preview.
    private func reapplyProfiles() async {
        guard !profiles.isEmpty else { return }
        if let list = try? await SimctlClient.listDevices() {
            devices = list
        }
        let booted = devices.filter(\.isBooted)
        appliedDeviceIDs.formIntersection(Set(booted.map(\.udid)))

        for device in booted where !appliedDeviceIDs.contains(device.udid) {
            for (bundleID, entry) in profiles where !entry.services.isEmpty {
                var targets = [bundleID]
                if entry.includePreviewShell {
                    targets.append(SimctlClient.previewShellBundleID)
                }
                for raw in entry.services {
                    guard let service = PrivacyService(rawValue: raw) else { continue }
                    for target in targets {
                        try? await SimctlClient.setPrivacy(
                            udid: device.udid, action: .grant, service: service, bundleID: target
                        )
                    }
                }
            }
            appliedDeviceIDs.insert(device.udid)
        }
    }

    func computeSizes() async {
        previewsCacheSize = await PreviewPaths.directorySize(PreviewPaths.previewsRoot)
        derivedDataSize = await PreviewPaths.directorySize(PreviewPaths.derivedData)
    }

    func injectFile(_ source: URL) async {
        guard let app = selectedApp, let container = app.dataContainerURL else {
            errorMessage = "Selected app has no data container yet — run its preview once."
            return
        }
        actionMessage = nil
        errorMessage = nil
        do {
            let destination = try await PreviewPaths.inject(fileAt: source, intoSandbox: container)
            actionMessage = "Injected → \(destination.path)"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func perform(_ operation: () async throws -> Void) async {
        isLoading = true
        errorMessage = nil
        do {
            try await operation()
        } catch {
            errorMessage = error.localizedDescription
        }
        await refresh()
    }
}
