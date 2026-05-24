import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct FilesView: View {
    @Environment(AppState.self) private var appState
    @State private var importing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            diskUsage

            Divider()

            Text("Open in Finder").font(.caption.weight(.semibold))
            revealButton("Previews Cache", PreviewPaths.previewsRoot)
            if let udid = appState.selectedDevice?.udid {
                revealButton("Device Data", PreviewPaths.deviceDataDir(udid))
                revealButton("TCC (permissions) Folder", PreviewPaths.tccDir(udid))
            }
            if let container = appState.selectedApp?.dataContainerURL {
                revealButton("App Sandbox", container)
            }

            Divider()

            Button {
                importing = true
            } label: {
                Label("Inject File into App Sandbox…", systemImage: "tray.and.arrow.down")
            }
            .controlSize(.small)
            .disabled(appState.selectedApp?.dataContainerURL == nil)
            .fileImporter(isPresented: $importing, allowedContentTypes: [.item]) { result in
                if case .success(let url) = result {
                    Task { await appState.injectFile(url) }
                }
            }

            if let message = appState.actionMessage {
                Text(message)
                    .font(.caption2).foregroundStyle(.secondary)
                    .lineLimit(2).textSelection(.enabled)
            }
        }
        .task { await appState.computeSizes() }
    }

    private var diskUsage: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Previews cache: \(format(appState.previewsCacheSize))")
                Text("DerivedData: \(format(appState.derivedDataSize))")
            }
            .font(.caption)
            Spacer()
            Button {
                Task { await appState.computeSizes() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .help("Recompute sizes")
        }
    }

    private func revealButton(_ title: String, _ url: URL) -> some View {
        Button {
            open(url)
        } label: {
            HStack {
                Image(systemName: "folder")
                Text(title).font(.caption)
                Spacer()
                Image(systemName: "arrow.up.forward.app").foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.borderless)
    }

    private func open(_ url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
    }

    private func format(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}
