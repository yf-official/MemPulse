import XCTest
@testable import MemPulse

final class SustainedThresholdTrackerTests: XCTestCase {
    func testDwellHysteresisAndRecovery() {
        let start = Date(timeIntervalSince1970: 1_000)
        var tracker = SustainedThresholdTracker(
            threshold: 85,
            dwell: 30,
            hysteresis: 5,
            recoveryDwell: 60,
            cooldown: 600
        )

        XCTAssertFalse(tracker.evaluate(value: 86, now: start))
        XCTAssertFalse(tracker.evaluate(value: 87, now: start.addingTimeInterval(29)))
        XCTAssertTrue(tracker.evaluate(value: 87, now: start.addingTimeInterval(30)))
        XCTAssertFalse(tracker.evaluate(value: 90, now: start.addingTimeInterval(50)))

        XCTAssertFalse(tracker.evaluate(value: 79, now: start.addingTimeInterval(60)))
        XCTAssertFalse(tracker.evaluate(value: 79, now: start.addingTimeInterval(119)))
        XCTAssertFalse(tracker.evaluate(value: 79, now: start.addingTimeInterval(120)))
        XCTAssertTrue(tracker.isArmed)
    }
}
