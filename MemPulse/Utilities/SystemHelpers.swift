import AppKit
import Foundation

enum SystemHelpers {
    static func openMemPulseWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "MemPulse" }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    static func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.openApplication(at: url, configuration: .init())
    }
}
