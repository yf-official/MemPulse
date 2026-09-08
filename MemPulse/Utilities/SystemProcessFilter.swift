import AppKit
import Foundation

enum SystemProcessFilter {
    private static let protectedBundleIdentifiers: Set<String> = [
        "com.apple.finder",
        "com.apple.dock",
        "com.apple.SystemUIServer",
        "com.apple.loginwindow"
    ]

    private static let protectedNames: Set<String> = [
        "MemPulse", "Finder", "Dock", "WindowServer", "SystemUIServer",
        "launchd", "loginwindow", "kernel_task"
    ]

    static func isSafeReleaseCandidate(
        _ application: NSRunningApplication,
        frontmostPID: pid_t?,
        ownPID: pid_t = ProcessInfo.processInfo.processIdentifier
    ) -> Bool {
        guard !application.isTerminated else { return false }
        return isSafeReleaseCandidate(
            name: application.localizedName,
            bundleIdentifier: application.bundleIdentifier,
            executablePath: application.executableURL?.path,
            activationPolicy: application.activationPolicy,
            pid: application.processIdentifier,
            frontmostPID: frontmostPID,
            ownPID: ownPID
        )
    }

    /// Pure policy entry point. Keeping the safety decision independent from
    /// `NSRunningApplication` lets us exhaustively unit-test protected cases.
    static func isSafeReleaseCandidate(
        name: String?,
        bundleIdentifier: String?,
        executablePath: String?,
        activationPolicy: NSApplication.ActivationPolicy,
        pid: pid_t,
        frontmostPID: pid_t?,
        ownPID: pid_t
    ) -> Bool {
        guard activationPolicy == .regular,
              pid != ownPID,
              pid != frontmostPID,
              let name,
              !name.isEmpty,
              !protectedNames.contains(name) else { return false }

        if let bundleIdentifier,
           protectedBundleIdentifiers.contains(bundleIdentifier) {
            return false
        }

        if let executablePath,
           executablePath.hasPrefix("/System/Library/CoreServices/") {
            return false
        }
        return true
    }
}
