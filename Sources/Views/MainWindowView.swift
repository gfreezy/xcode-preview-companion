import SwiftUI

struct MainWindowView: View {
    @Environment(AppState.self) private var appState
    @State private var section: Section? = .devices

    enum Section: String, CaseIterable, Identifiable {
        case devices = "Devices"
        case permissions = "Permissions"
        case rescue = "Rescue"
        case files = "Files"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .devices: "iphone"
            case .permissions: "lock.shield"
            case .rescue: "wrench.and.screwdriver"
            case .files: "folder"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $section) {
                ForEach(Section.allCases) { item in
                    Label(item.rawValue, systemImage: item.symbol).tag(item)
                }
            }
            .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            VStack(alignment: .leading, spacing: 10) {
                deviceBar
                Divider()
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        switch section ?? .devices {
                        case .devices: DevicesView()
                        case .permissions: PermissionsView()
                        case .rescue: RescueView()
                        case .files: FilesView()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 4)
                }

                if let error = appState.errorMessage {
                    Text(error)
                        .font(.caption).foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .navigationTitle(section?.rawValue ?? "Devices")
        }
        .task { await appState.refresh() }
    }

    private var deviceBar: some View {
        @Bindable var appState = appState

        return HStack {
            Menu {
                ForEach(appState.devices) { device in
                    Button {
                        appState.selectedDeviceID = device.id
                    } label: {
                        Text("\(device.name) — \(device.runtimeName)\(device.isBooted ? " (Booted)" : "")")
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "iphone")
                    Text(appState.selectedDevice.map { "\($0.name) · \($0.runtimeName)" } ?? "No preview device")
                }
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(appState.devices.isEmpty)

            Spacer()

            if appState.isLoading {
                ProgressView().controlSize(.small)
            }
            Button {
                Task { await appState.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")
        }
    }
}
