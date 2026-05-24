import SwiftUI

struct PermissionsView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var appState = appState

        VStack(alignment: .leading, spacing: 8) {
            if appState.selectedDevice == nil {
                Text("Select a preview device first.")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Picker("App", selection: $appState.selectedAppID) {
                    let users = appState.apps.filter { $0.type == .user }
                    let system = appState.apps.filter { $0.type != .user }
                    if !users.isEmpty {
                        Section("Previewed Apps") {
                            ForEach(users) { Text($0.displayName).tag(Optional($0.id)) }
                        }
                    }
                    if !system.isEmpty {
                        Section("System") {
                            ForEach(system) { Text("\($0.displayName)").tag(Optional($0.id)) }
                        }
                    }
                }
                .pickerStyle(.menu)

                Toggle(isOn: $appState.applyToPreviewShell) {
                    Text("Also apply to PreviewShell")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
                .help("Some previews are hosted by com.apple.PreviewShell rather than your app's bundle id.")

                Toggle(isOn: Binding(
                    get: { appState.autoReapplyEnabled },
                    set: { appState.setAutoReapply($0) }
                )) {
                    Text("Auto-grant ⭐︎ services on new preview devices")
                        .font(.caption)
                }
                .toggleStyle(.checkbox)
                .help("When Xcode spins up a fresh preview device, re-grant the starred services automatically.")

                Divider()

                servicesList

                Divider()

                HStack {
                    Button("Reset All Permissions") {
                        Task { await appState.applyPrivacy(.reset, .all) }
                    }
                    .controlSize(.small)
                    Spacer()
                }

                if let message = appState.actionMessage {
                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
        .task(id: appState.selectedDevice?.id) {
            await appState.loadApps()
        }
    }

    private var servicesList: some View {
        VStack(spacing: 2) {
            ForEach(PrivacyService.grantable) { service in
                HStack(spacing: 8) {
                        Label(service.displayName, systemImage: service.symbol)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button {
                            appState.toggleProfile(service)
                        } label: {
                            Image(systemName: appState.isInProfile(service) ? "star.fill" : "star")
                                .foregroundStyle(appState.isInProfile(service) ? .yellow : .secondary)
                        }
                        .buttonStyle(.borderless)
                        .controlSize(.small)
                        .help("Add to auto-grant profile")
                        actionButton("checkmark", .green, "Grant") {
                            await appState.applyPrivacy(.grant, service)
                        }
                        actionButton("xmark", .red, "Revoke") {
                            await appState.applyPrivacy(.revoke, service)
                        }
                        actionButton("arrow.counterclockwise", .secondary, "Reset") {
                            await appState.applyPrivacy(.reset, service)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.horizontal, 4)
                }
            }
        .disabled(appState.selectedApp == nil)
    }

    private func actionButton(
        _ symbol: String,
        _ color: Color,
        _ help: String,
        _ action: @escaping () async -> Void
    ) -> some View {
        Button {
            Task { await action() }
        } label: {
            Image(systemName: symbol).foregroundStyle(color)
        }
        .buttonStyle(.borderless)
        .controlSize(.small)
        .help(help)
    }
}
