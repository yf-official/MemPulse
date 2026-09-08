import AppKit
import Foundation

final class SmartReleaseManager {
    func candidates(from processes: [ProcessMemoryInfo]) -> [SmartReleaseCandidate] {
        let workspace = NSWorkspace.shared
        let frontmostPID = workspace.frontmostApplication?.processIdentifier

        return workspace.runningApplications.compactMap { application in
            guard SystemProcessFilter.isSafeReleaseCandidate(
                application,
                frontmostPID: frontmostPID
            ) else { return nil }

            let pid = application.processIdentifier
            let bundleIdentifier = application.bundleIdentifier
            let bundlePath = application.bundleURL?.path
            let matching = processes.filter { process in
                if process.pid == pid { return true }
                if let bundlePath, let processPath = process.executablePath,
                   processPath.hasPrefix(bundlePath + "/") {
                    return true
                }
                return false
            }
            let estimated = matching.reduce(UInt64(0)) {
                MemoryMath.addingClamped($0, $1.memoryBytes)
            }
            guard estimated > 0 else { return nil }

            return SmartReleaseCandidate(
                pid: pid,
                name: application.localizedName ?? "PID \(pid)",
                bundleIdentifier: bundleIdentifier,
                estimatedBytes: estimated
            )
        }
        .sorted { $0.estimatedBytes > $1.estimatedBytes }
    }

    func requestNormalTermination(for candidates: [SmartReleaseCandidate]) -> (requested: Int, accepted: Int) {
        let applications = Dictionary(
            uniqueKeysWithValues: NSWorkspace.shared.runningApplications.map {
                ($0.processIdentifier, $0)
            }
        )
        var accepted = 0
        for candidate in candidates {
            guard let application = applications[candidate.pid],
                  SystemProcessFilter.isSafeReleaseCandidate(
                    application,
                    frontmostPID: NSWorkspace.shared.frontmostApplication?.processIdentifier
                  ) else { continue }
            if application.terminate() { accepted += 1 }
        }
        return (candidates.count, accepted)
    }
}
