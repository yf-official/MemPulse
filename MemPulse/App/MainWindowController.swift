import AppKit
import SwiftUI

final class MainWindowController: NSWindowController, NSWindowDelegate {
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MemPulse"
        window.minSize = NSSize(width: 760, height: 560)
        // The content already carries the MemPulse identity, so a duplicate
        // title in the title bar would add visual noise.
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: MainWindowView(model: model))
        super.init(window: window)
        window.center()
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { nil }

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Closing the dashboard only returns MemPulse to menu-bar mode. The
        // explicit Quit actions remain the only way to terminate the app.
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }

}
