import SwiftUI

@main
struct PreviewCompanionApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Preview Companion", image: "MenuBarIcon") {
            MenuBarPopover()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)

        Window("Xcode Preview Companion", id: AppWindow.main) {
            MainWindowView()
                .environment(appState)
                .frame(minWidth: 660, minHeight: 480)
        }
        .windowResizability(.contentMinSize)
    }
}

enum AppWindow {
    static let main = "main"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        // Start menu-bar-only: close any window auto-opened/restored at launch.
        // The main window opens on demand from the popover's "Open Companion".
        DispatchQueue.main.async {
            for window in NSApp.windows where window.canBecomeMain {
                window.close()
            }
        }
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: nil
        )
    }

    /// When the main window closes, drop back to menu-bar-only (no Dock icon).
    @objc private func windowWillClose(_ notification: Notification) {
        guard let closing = notification.object as? NSWindow, closing.canBecomeMain else { return }
        DispatchQueue.main.async {
            let stillOpen = NSApp.windows.contains { $0 != closing && $0.canBecomeMain && $0.isVisible }
            if !stillOpen {
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }
}
