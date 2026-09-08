import Foundation

struct SustainedThresholdTracker {
    var threshold: Double
    var dwell: TimeInterval
    var hysteresis: Double
    var recoveryDwell: TimeInterval
    var cooldown: TimeInterval

    private(set) var isArmed = true
    private var aboveSince: Date?
    private var belowSince: Date?
    private var lastFiredAt: Date?

    init(
        threshold: Double,
        dwell: TimeInterval,
        hysteresis: Double,
        recoveryDwell: TimeInterval,
        cooldown: TimeInterval
    ) {
        self.threshold = threshold
        self.dwell = dwell
        self.hysteresis = hysteresis
        self.recoveryDwell = recoveryDwell
        self.cooldown = cooldown
    }

    mutating func reset(threshold newThreshold: Double? = nil) {
        if let newThreshold { threshold = newThreshold }
        isArmed = true
        aboveSince = nil
        belowSince = nil
        lastFiredAt = nil
    }

    mutating func evaluate(value: Double, now: Date) -> Bool {
        if value >= threshold {
            belowSince = nil
            if aboveSince == nil { aboveSince = now }
            guard isArmed,
                  now.timeIntervalSince(aboveSince ?? now) >= dwell else { return false }
            if let lastFiredAt, now.timeIntervalSince(lastFiredAt) < cooldown { return false }
            isArmed = false
            lastFiredAt = now
            return true
        }

        aboveSince = nil
        if value <= threshold - hysteresis {
            if belowSince == nil { belowSince = now }
            if !isArmed, now.timeIntervalSince(belowSince ?? now) >= recoveryDwell {
                isArmed = true
            }
        } else {
            belowSince = nil
        }
        return false
    }
}
