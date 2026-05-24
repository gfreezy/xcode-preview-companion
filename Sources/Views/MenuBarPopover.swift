import AppKit
import SwiftUI

struct MenuBarPopover: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Preview Companion", systemImage: "rectangle.on.rectangle.angled")
                    .font(.headline)
                Spacer()
                if appState.isLoading {
                    ProgressView().controlSize(.small)
                }
            }

            Divider()

            if let device = appState.selectedDevice {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: "iphone")
                        Text(device.name).font(.callout.weight(.medium))
                    }
                    Text(device.runtimeName).font(.caption).foregroundStyle(.secondary)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(device.isBooted ? Color.green : Color.secondary)
                            .frame(width: 7, height: 7)
                        Text(device.isBooted ? "Booted" : device.state)
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No preview device").font(.caption).foregroundStyle(.secondary)
            }

            Text("\(appState.devices.count) preview device(s)")
                .font(.caption2).foregroundStyle(.secondary)

            Divider()

            Button {
                NSApp.setActivationPolicy(.regular)
                NSApp.activate(ignoringOtherApps: true)
                openWindow(id: AppWindow.main)
            } label: {
                Label("Open Companion", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)

            HStack {
                Button("Refresh") { Task { await appState.refresh() } }
                    .controlSize(.small)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .controlSize(.small)
            }
        }
        .padding(12)
        .frame(width: 270)
        .task { await appState.refresh() }
    }
}
