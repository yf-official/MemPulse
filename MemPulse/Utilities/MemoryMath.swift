import Foundation

enum MemoryMath {
    struct Breakdown: Equatable {
        let appMemory: UInt64
        let cachedFiles: UInt64
        let usedMemory: UInt64
        let availableMemory: UInt64
    }

    static func breakdown(
        total: UInt64,
        freePages: UInt64,
        internalPages: UInt64,
        externalPages: UInt64,
        purgeablePages: UInt64,
        wiredPages: UInt64,
        compressedPages: UInt64,
        pageSize: UInt64
    ) -> Breakdown {
        let appPages = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        let app = multipliedClamped(appPages, pageSize)
        let cached = multipliedClamped(addingClamped(externalPages, purgeablePages), pageSize)
        // Activity Monitor's headline "Memory Used" is best matched by the
        // physical-memory residual. On Apple silicon, GPU/system-reserved
        // pages aren't necessarily represented by app + wired + compressor,
        // so summing only those buckets can under-report the total.
        let free = multipliedClamped(freePages, pageSize)
        let available = min(addingClamped(free, cached), total)
        let used = total - available
        return Breakdown(
            appMemory: app,
            cachedFiles: cached,
            usedMemory: used,
            availableMemory: available
        )
    }

    static func multipliedClamped(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.multipliedReportingOverflow(by: rhs)
        return overflow ? .max : value
    }

    static func addingClamped(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let (value, overflow) = lhs.addingReportingOverflow(rhs)
        return overflow ? .max : value
    }
}
