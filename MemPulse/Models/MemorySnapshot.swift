import Foundation

struct ProcessMemorySnapshot: Codable, Equatable, Sendable {
    let identity: ProcessIdentity
    let memoryBytes: UInt64
    let timestamp: Date
}

struct ProbeReport: Codable {
    let memory: MemoryStats
    let topProcesses: [ProcessMemoryInfo]
}
