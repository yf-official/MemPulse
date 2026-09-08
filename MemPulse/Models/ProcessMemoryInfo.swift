import Foundation

struct ProcessIdentity: Hashable, Codable, Sendable {
    let pid: Int32
    let startTimeMicroseconds: UInt64
}

struct ProcessMemoryInfo: Identifiable, Codable, Equatable, Sendable {
    let pid: Int32
    let parentPID: Int32
    let uid: UInt32
    let startTimeMicroseconds: UInt64
    let processName: String
    let applicationName: String
    let bundleIdentifier: String?
    let executablePath: String?
    let applicationBundlePath: String?
    let memoryBytes: UInt64
    let residentBytes: UInt64
    let footprintIsEstimated: Bool

    var id: ProcessIdentity {
        ProcessIdentity(pid: pid, startTimeMicroseconds: startTimeMicroseconds)
    }
}

struct ProcessGrowthFinding: Identifiable, Equatable, Sendable {
    let identity: ProcessIdentity
    let processName: String
    let startBytes: UInt64
    let currentBytes: UInt64
    let growthBytes: UInt64
    let growthRatio: Double
    let duration: TimeInterval

    var id: ProcessIdentity { identity }
}
