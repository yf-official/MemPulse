import AppKit
import XCTest
@testable import MemPulse

final class SystemProcessFilterTests: XCTestCase {
    private func isSafe(
        name: String = "Preview",
        bundleIdentifier: String? = "com.apple.Preview",
        path: String? = "/System/Applications/Preview.app/Contents/MacOS/Preview",
        policy: NSApplication.ActivationPolicy = .regular,
        pid: pid_t = 200,
        frontmostPID: pid_t? = 100,
        ownPID: pid_t = 101
    ) -> Bool {
        SystemProcessFilter.isSafeReleaseCandidate(
            name: name,
            bundleIdentifier: bundleIdentifier,
            executablePath: path,
            activationPolicy: policy,
            pid: pid,
            frontmostPID: frontmostPID,
            ownPID: ownPID
        )
    }

    func testRegularBackgroundUserApplicationIsEligible() {
        XCTAssertTrue(isSafe())
    }

    func testFrontmostAndOwnApplicationsAreExcluded() {
        XCTAssertFalse(isSafe(pid: 100))
        XCTAssertFalse(isSafe(pid: 101))
    }

    func testNonRegularApplicationIsExcluded() {
        XCTAssertFalse(isSafe(policy: .accessory))
        XCTAssertFalse(isSafe(policy: .prohibited))
    }

    func testProtectedNamesAreExcluded() {
        for name in ["MemPulse", "Finder", "Dock", "WindowServer", "SystemUIServer", "launchd", "loginwindow", "kernel_task"] {
            XCTAssertFalse(isSafe(name: name), "Expected \(name) to be protected")
        }
    }

    func testProtectedBundleIdentifiersAreExcluded() {
        for identifier in ["com.apple.finder", "com.apple.dock", "com.apple.SystemUIServer", "com.apple.loginwindow"] {
            XCTAssertFalse(isSafe(bundleIdentifier: identifier), "Expected \(identifier) to be protected")
        }
    }

    func testCoreServicesExecutablesAreExcluded() {
        XCTAssertFalse(isSafe(path: "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"))
    }
}
