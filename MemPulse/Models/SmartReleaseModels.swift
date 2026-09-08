import Foundation

struct SmartReleaseCandidate: Identifiable, Equatable {
    let pid: Int32
    let name: String
    let bundleIdentifier: String?
    let estimatedBytes: UInt64

    var id: Int32 { pid }
}

struct SmartReleaseResult: Equatable {
    let estimatedBytes: UInt64
    let measuredUsedMemoryDelta: Int64
    let requestedCount: Int
    let acceptedCount: Int
    let pressureBefore: MemoryPressureLevel
    let pressureAfter: MemoryPressureLevel
}
