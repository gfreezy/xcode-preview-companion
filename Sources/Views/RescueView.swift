import SwiftUI

struct RescueView: View {
    @Environment(AppState.self) private var appState
    @State private var confirming = false

    var body: some View {
        @Bindable var appState = appState

        VStack(alignment: .leading, spacing: 8) {
            Text("Fix Previews")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 3) {
                Toggle("Kill stuck preview processes", isOn: $appState.rescueOptions.killProcesses)
                Toggle("Shut down preview devices", isOn: $appState.rescueOptions.shutdownDevices)
                Toggle("Delete preview devices", isOn: $appState.rescueOptions.deleteDevices)
                Toggle("Clear UserData/Previews cache", isOn: $appState.rescueOptions.clearPreviewsUserData)
                Toggle("Clear DerivedData for project", isOn: $appState.rescueOptions.clearDerivedData)
                if appState.rescueOptions.clearDerivedData {
                    TextField("Project name prefix", text: $appState.rescueOptions.derivedDataProjectName)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.small)
                        .padding(.leading, 18)
                }
            }
            .toggleStyle(.checkbox)
            .font(.caption)

            confirmControl

            if !appState.rescueLog.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(appState.rescueLog, id: \.self) { line in
                        Text("• \(line)").font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
            processSection
        }
    }

    @ViewBuilder
    private var confirmControl: some View {
        if confirming {
            HStack(spacing: 6) {
                Text("This deletes devices & caches. Continue?")
                    .font(.caption)
                Spacer()
                Button("Fix", role: .destructive) {
                    confirming = false
                    Task { await appState.runRescue() }
                }
                .controlSize(.small)
                Button("Cancel") { confirming = false }
                    .controlSize(.small)
            }
        } else {
            Button {
                confirming = true
            } label: {
                Label("Fix Previews", systemImage: "wrench.and.screwdriver")
            }
            .controlSize(.small)
        }
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Preview Processes")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button {
                    Task { await appState.loadProcesses() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .help("Refresh process list")
                if !appState.processes.isEmpty {
                    Button("Kill All", role: .destructive) {
                        Task { await appState.killProcesses(appState.processes.map(\.pid)) }
                    }
                    .controlSize(.small)
                }
            }

            if appState.processes.isEmpty {
                Text("No preview processes running.")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                ForEach(appState.processes) { process in
                    HStack(spacing: 8) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(process.name).font(.caption)
                            Text("pid \(process.pid)").font(.caption2).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            Task { await appState.killProcesses([process.pid]) }
                        } label: {
                            Image(systemName: "xmark.octagon").foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Kill")
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .task { await appState.loadProcesses() }
    }
}
