import AppKit
import Foundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel.shared
    private var menuBarController: MenuBarController?
    private var mainWindowController: MainWindowController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // NSStatusBar must see the final activation policy before application
        // launch finishes. Changing it in didFinishLaunching can leave the
        // status-item window parked off-screen on recent macOS releases.
        NSApp.setActivationPolicy(.regular)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--snapshot-json") {
            NSApp.setActivationPolicy(.accessory)
            runProbeAndExit()
            return
        }

        if let bundleID = Bundle.main.bundleIdentifier {
            let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
            if let other = others.first {
                other.activate()
                NSApp.terminate(nil)
                return
            }
        }

        buildMainMenu()
        menuBarController = MenuBarController(model: model) { [weak self] in
            self?.mainWindowController?.show()
        }
        // Create the status item before any ordinary window. On macOS 26 this
        // lets Control Center adopt and position it before the first window is
        // ordered front.
        mainWindowController = MainWindowController(model: model)
        model.start()
        if CommandLine.arguments.contains("--background") {
            NSApp.setActivationPolicy(.accessory)
        } else {
            mainWindowController?.show()
        }

        if CommandLine.arguments.contains("--diagnose-menu") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let description = self?.menuBarController?.diagnosticDescription else { return }
                FileHandle.standardError.write(Data("MemPulse status item: \(description)\n".utf8))
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { mainWindowController?.show() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func buildMainMenu() {
        let menu = NSMenu()

        let appItem = NSMenuItem()
        menu.addItem(appItem)
        let appMenu = NSMenu(title: "MemPulse")
        let aboutItem = appMenu.addItem(
            withTitle: "关于 MemPulse",
            action: #selector(showAbout),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(.separator())
        let showItem = appMenu.addItem(
            withTitle: "显示 MemPulse",
            action: #selector(showMainWindow),
            keyEquivalent: "1"
        )
        showItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "退出 MemPulse",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu

        let windowItem = NSMenuItem()
        menu.addItem(windowItem)
        let windowMenu = NSMenu(title: "窗口")
        windowMenu.addItem(
            withTitle: "关闭窗口",
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        )
        windowMenu.addItem(
            withTitle: "最小化",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowItem.submenu = windowMenu

        NSApp.mainMenu = menu
        NSApp.windowsMenu = windowMenu
    }

    @objc private func showMainWindow() {
        mainWindowController?.show()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "MemPulse",
            .applicationVersion: "1.0.0",
            .credits: NSAttributedString(string: "Monitor. Detect. Release.\n100% 本地运行。")
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func runProbeAndExit() {
        let monitor = MemoryMonitor()
        let processes = ProcessMonitor()
        guard let memory = monitor.sample() else {
            FileHandle.standardError.write(Data("Unable to read memory statistics.\n".utf8))
            NSApp.terminate(nil)
            return
        }
        let report = ProbeReport(memory: memory, topProcesses: processes.sample(limit: 5))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(report) {
            FileHandle.standardOutput.write(data)
            FileHandle.standardOutput.write(Data("\n".utf8))
        }
        NSApp.terminate(nil)
    }
}
