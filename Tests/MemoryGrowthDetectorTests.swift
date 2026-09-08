import XCTest
@testable import MemPulse

final class MemoryGrowthDetectorTests: XCTestCase {
    func testDetectsSustainedFiveMinuteGrowth() {
        var configuration = MemoryGrowthDetector.Configuration()
        configuration.minimumSamples = 10
        let detector = MemoryGrowthDetector(configuration: configuration)
        let start = Date(timeIntervalSince1970: 10_000)
        var findings: [ProcessGrowthFinding] = []

        for index in 0...10 {
            let process = makeProcess(memory: UInt64(300 + index * 65) * 1024 * 1024)
            findings = detector.update(
                processes: [process],
                now: start.addingTimeInterval(Double(index) * 30)
            )
        }

        XCTAssertEqual(findings.count, 1)
        XCTAssertGreaterThan(findings[0].growthBytes, 500 * 1024 * 1024)
    }

    func testIgnoresOneOffSpikeWithoutConsistentGrowth() {
        var configuration = MemoryGrowthDetector.Configuration()
        configuration.minimumSamples = 10
        let detector = MemoryGrowthDetector(configuration: configuration)
        let start = Date(timeIntervalSince1970: 20_000)
        var findings: [ProcessGrowthFinding] = []

        for index in 0...10 {
            let mb = index == 5 ? 1_500 : 300
            findings = detector.update(
                processes: [makeProcess(memory: UInt64(mb) * 1024 * 1024)],
                now: start.addingTimeInterval(Double(index) * 30)
            )
        }

        XCTAssertTrue(findings.isEmpty)
    }

    func testHistoryRemainsBoundedWhenManyLiveProcessesRotate() {
        var configuration = MemoryGrowthDetector.Configuration()
        configuration.trackedProcessLimit = 3
        configuration.retention = 60
        let detector = MemoryGrowthDetector(configuration: configuration)
        let start = Date(timeIntervalSince1970: 30_000)

        for round in 0..<20 {
            var processes: [ProcessMemoryInfo] = []
            for index in 0..<12 {
                let rotatedIndex = (index + round) % 12
                let megabytes = UInt64(500 - rotatedIndex * 10)
                processes.append(makeProcess(
                    pid: Int32(index + 10),
                    memory: megabytes * 1024 * 1024
                ))
            }
            processes.sort { $0.memoryBytes > $1.memoryBytes }
            _ = detector.update(processes: processes, now: start.addingTimeInterval(Double(round) * 5))
            XCTAssertLessThanOrEqual(detector.trackedProcessCountForTesting, 3)
            XCTAssertLessThanOrEqual(detector.retainedSnapshotCountForTesting, 39)
        }

        _ = detector.update(processes: [], now: start.addingTimeInterval(120))
        XCTAssertEqual(detector.trackedProcessCountForTesting, 0)
        XCTAssertEqual(detector.retainedSnapshotCountForTesting, 0)
    }

    private func makeProcess(pid: Int32 = 42, memory: UInt64) -> ProcessMemoryInfo {
        ProcessMemoryInfo(
            pid: pid,
            parentPID: 1,
            uid: 501,
            startTimeMicroseconds: UInt64(pid),
            processName: "GrowingTest",
            applicationName: "GrowingTest",
            bundleIdentifier: nil,
            executablePath: nil,
            applicationBundlePath: nil,
            memoryBytes: memory,
            residentBytes: memory,
            footprintIsEstimated: false
        )
    }
}
