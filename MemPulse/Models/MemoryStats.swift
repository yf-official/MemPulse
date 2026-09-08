import Foundation

enum MemoryPressureLevel: Int, Codable, CaseIterable, Sendable {
    case unknown = 0
    case normal = 1
    case warning = 2
    case critical = 4

    var title: String {
        switch self {
        case .unknown: return "Unknown"
        case .normal: return "Normal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}

struct MemoryStats: Codable, Equatable, Sendable {
    let totalMemory: UInt64
    let usedMemory: UInt64
    let availableMemory: UInt64
    let freeMemory: UInt64
    let activeMemory: UInt64
    let inactiveMemory: UInt64
    let wiredMemory: UInt64
    let compressedMemory: UInt64
    let appMemory: UInt64
    let cachedFiles: UInt64
    let purgeableMemory: UInt64
    let swapTotal: UInt64
    let swapUsed: UInt64
    let swapInBytesPerSecond: Double
    let swapOutBytesPerSecond: Double
    let pressure: MemoryPressureLevel
    let timestamp: Date

    var usageFraction: Double {
        guard totalMemory > 0 else { return 0 }
        return min(max(Double(usedMemory) / Double(totalMemory), 0), 1)
    }

    var usagePercentage: Double { usageFraction * 100 }

    static let empty = MemoryStats(
        totalMemory: ProcessInfo.processInfo.physicalMemory,
        usedMemory: 0,
        availableMemory: ProcessInfo.processInfo.physicalMemory,
        freeMemory: 0,
        activeMemory: 0,
        inactiveMemory: 0,
        wiredMemory: 0,
        compressedMemory: 0,
        appMemory: 0,
        cachedFiles: 0,
        purgeableMemory: 0,
        swapTotal: 0,
        swapUsed: 0,
        swapInBytesPerSecond: 0,
        swapOutBytesPerSecond: 0,
        pressure: .unknown,
        timestamp: .distantPast
    )
}
