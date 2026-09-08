import Foundation

final class MemoryGrowthDetector {
    struct Configuration {
        var retention: TimeInterval = 10 * 60
        var analysisWindow: TimeInterval = 5 * 60
        var minimumDuration: TimeInterval = 4.5 * 60
        var minimumSamples = 24
        var minimumAbsoluteGrowth: UInt64 = 500 * 1024 * 1024
        var minimumRelativeGrowth = 1.0
        var relativeGrowthNoiseFloor: UInt64 = 128 * 1024 * 1024
        var minimumCurrentSize: UInt64 = 200 * 1024 * 1024
        var minimumIncreasingFraction = 0.70
        var trackedProcessLimit = 60
    }

    private let configuration: Configuration
    private var history: [ProcessIdentity: [ProcessMemorySnapshot]] = [:]

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    func update(processes: [ProcessMemoryInfo], now: Date = Date()) -> [ProcessGrowthFinding] {
        let live = Set(processes.map(\.id))
        let tracked = Array(processes
            .filter { $0.memoryBytes >= 50 * 1024 * 1024 || history[$0.id] != nil }
            .prefix(configuration.trackedProcessLimit))
        let trackedIdentities = Set(tracked.map(\.id))

        // Bound the store even when many long-lived processes rotate through
        // the top list. Entries that are alive but no longer in the tracked
        // set must not retain their old samples indefinitely.
        history = history.filter {
            live.contains($0.key) && trackedIdentities.contains($0.key)
        }

        let oldestRetained = now.addingTimeInterval(-configuration.retention)
        for process in tracked {
            var samples = history[process.id, default: []]
            samples.append(ProcessMemorySnapshot(
                identity: process.id,
                memoryBytes: process.memoryBytes,
                timestamp: now
            ))
            samples.removeAll { $0.timestamp < oldestRetained }
            history[process.id] = samples
        }

        return tracked.compactMap { process in
            analyze(process: process, now: now)
        }
        .sorted { $0.growthBytes > $1.growthBytes }
    }

    var trackedProcessCountForTesting: Int { history.count }

    var retainedSnapshotCountForTesting: Int {
        history.values.reduce(0) { $0 + $1.count }
    }

    private func analyze(process: ProcessMemoryInfo, now: Date) -> ProcessGrowthFinding? {
        let windowStart = now.addingTimeInterval(-configuration.analysisWindow)
        guard let allSamples = history[process.id] else { return nil }
        let samples = allSamples.filter { $0.timestamp >= windowStart }
        guard samples.count >= configuration.minimumSamples,
              let first = samples.first,
              let last = samples.last else { return nil }

        let duration = last.timestamp.timeIntervalSince(first.timestamp)
        guard duration >= configuration.minimumDuration,
              last.memoryBytes > first.memoryBytes,
              last.memoryBytes >= configuration.minimumCurrentSize else { return nil }

        let growth = last.memoryBytes - first.memoryBytes
        let baseline = max(first.memoryBytes, 1)
        let ratio = Double(growth) / Double(baseline)
        let qualifiesByAmount = growth >= configuration.minimumAbsoluteGrowth
        let qualifiesByRatio = growth >= configuration.relativeGrowthNoiseFloor
            && ratio >= configuration.minimumRelativeGrowth
        guard qualifiesByAmount || qualifiesByRatio else { return nil }

        var increasingIntervals = 0
        for pair in zip(samples, samples.dropFirst()) where pair.1.memoryBytes > pair.0.memoryBytes {
            increasingIntervals += 1
        }
        let intervalCount = max(samples.count - 1, 1)
        let increasingFraction = Double(increasingIntervals) / Double(intervalCount)
        guard increasingFraction >= configuration.minimumIncreasingFraction else { return nil }

        return ProcessGrowthFinding(
            identity: process.id,
            processName: process.applicationName,
            startBytes: first.memoryBytes,
            currentBytes: last.memoryBytes,
            growthBytes: growth,
            growthRatio: ratio,
            duration: duration
        )
    }
}
