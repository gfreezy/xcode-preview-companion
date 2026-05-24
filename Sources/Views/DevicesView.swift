import SwiftUI

struct DevicesView: View {
    @Environment(AppState.self) private var appState
    @State private var pendingDelete: String?
    @State private var pendingDeleteAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Preview Devices")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                deleteAllControl
            }

            if appState.devices.isEmpty {
                Text(appState.isLoading ? "Loading…" : "No preview devices.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 2) {
                    ForEach(appState.devices) { device in
                        deviceRow(device)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var deleteAllControl: some View {
        if pendingDeleteAll {
            HStack(spacing: 4) {
                Text("Delete all?").font(.caption)
                Button("Delete", role: .destructive) {
                    pendingDeleteAll = false
                    Task { await appState.deleteAll() }
                }
                .controlSize(.small)
                Button("Cancel") { pendingDeleteAll = false }
                    .controlSize(.small)
            }
        } else {
            Button("Delete All") { pendingDeleteAll = true }
                .controlSize(.small)
                .disabled(appState.devices.isEmpty)
        }
    }

    private func deviceRow(_ device: PreviewDevice) -> some View {
        HStack(spacing: 8) {
            Button {
                appState.selectedDeviceID = device.id
            } label: {
                Image(systemName: appState.selectedDevice?.id == device.id
                      ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(appState.selectedDevice?.id == device.id ? Color.accentColor : .secondary)
            }
            .buttonStyle(.borderless)

            VStack(alignment: .leading, spacing: 1) {
                Text(device.name).font(.callout)
                Text(device.runtimeName).font(.caption2).foregroundStyle(.secondary)
            }

            Spacer()

            if device.isBooted {
                Text("Booted")
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(Color.green.opacity(0.2), in: Capsule())
                    .foregroundStyle(.green)
            }

            rowActions(device)
        }
        .padding(.vertical, 3)
        .padding(.horizontal, 4)
        .background(
            appState.selectedDevice?.id == device.id
            ? Color.accentColor.opacity(0.08) : .clear,
            in: RoundedRectangle(cornerRadius: 6)
        )
    }

    @ViewBuilder
    private func rowActions(_ device: PreviewDevice) -> some View {
        if pendingDelete == device.id {
            Button("Delete", role: .destructive) {
                pendingDelete = nil
                Task { await appState.shutdownAndDelete(device) }
            }
            .controlSize(.small)
            Button("Cancel") { pendingDelete = nil }
                .controlSize(.small)
        } else {
            Menu {
                if device.isBooted {
                    Button("Shutdown") {
                        Task { await appState.shutdown(device) }
                    }
                }
                Button("Delete", role: .destructive) {
                    pendingDelete = device.id
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }
}
