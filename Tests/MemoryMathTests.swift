import XCTest
@testable import MemPulse

final class MemoryMathTests: XCTestCase {
    func testActivityMonitorStyleBreakdown() {
        let page: UInt64 = 16 * 1024
        let result = MemoryMath.breakdown(
            total: 16 * 1024 * 1024 * 1024,
            freePages: 10_000,
            internalPages: 400_000,
            externalPages: 100_000,
            purgeablePages: 20_000,
            wiredPages: 80_000,
            compressedPages: 40_000,
            pageSize: page
        )

        XCTAssertEqual(result.appMemory, 380_000 * page)
        XCTAssertEqual(result.cachedFiles, 120_000 * page)
        XCTAssertEqual(result.availableMemory, (10_000 + 120_000) * page)
        XCTAssertEqual(result.usedMemory, 16 * 1024 * 1024 * 1024 - result.availableMemory)
    }

    func testUsedMemoryClampsToPhysicalTotal() {
        let result = MemoryMath.breakdown(
            total: 100,
            freePages: 0,
            internalPages: 100,
            externalPages: 0,
            purgeablePages: 0,
            wiredPages: 100,
            compressedPages: 100,
            pageSize: 1
        )
        XCTAssertEqual(result.usedMemory, 100)
        XCTAssertEqual(result.availableMemory, 0)
    }
}
