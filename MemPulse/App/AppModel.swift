import Combine
import Dispatch
import Foundation

final class AppModel: ObservableObject {
    static let shared = AppModel()

    @Published private(set) var memoryStats: MemoryStats = .empty
    @Published private(set) var allProcesses: [ProcessMemoryInfo] = []
    @Published private(set) var topProcesses: [ProcessMemoryInfo] = []
    @Published private(set) var growthFindings: [ProcessGrowthFinding] = []
    @Published private(set) var lastError: String?

    let settings = SettingsStore()

    private let queue = DispatchQueue(label: "com.yfofficial.MemPulse.sampling", qos: .utility)
    private let memoryMonitor = MemoryMonitor()
    private let processMonitor = ProcessMonitor()
    private let growthDetector = MemoryGrowthDetector()
    private let alertEngine = AlertEngine()
    private let smartReleaseManager = SmartReleaseManager()

    private var memoryTimer: DispatchSourceTimer?
    private var processTimer: DispatchSourceTimer?
    private var pressureSource: DispatchSourceMemoryPressure?
    private var cancellables = Set<AnyCancellable>()
    private var started = false

    init() {
        Publishers.CombineLatest(settings.$refreshInterval, settings.$processScanInterval)
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in self?.installTimers() }
            .store(in: &cancellables)
    }

    func start() {
        guard !started else { return }
        started = true
        installTimers()
        installPressureSource()
        if settings.growthAlertsEnabled || settings.pressureAlertsEnabled || settings.ramThresholdAlertsEnabled {
            NotificationManager.shared.requestAuthorization()
        }
    }

    func stop() {
        started = false
        memoryTimer?.cancel()
        memoryTimer = nil
        processTimer?.cancel()
        processTimer = nil
        pressureSource?.cancel()
        pressureSource = nil
    }

    func refreshNow() {
        queue.async { [weak self] in
            self?.sampleMemoryOnQueue()
            self?.sampleProcessesOnQueue()
        }
    }

    @MainActor
    func smartReleaseCandidates() -> [SmartReleaseCandidate] {
        smartReleaseManager.candidates(from: allProcesses)
    }

    @MainActor
    func performSmartRelease(
        _ candidates: [SmartReleaseCandidate],
        completion: @escaping (SmartReleaseResult) -> Void
    ) {
        let before = memoryStats
        let estimated = candidates.reduce(UInt64(0)) {
            MemoryMath.addingClamped($0, $1.estimatedBytes)
        }
        let request = smartReleaseManager.requestNormalTermination(for: candidates)

        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self else { return }
            self.sampleMemory { after in
                let delta = Int64(clamping: before.usedMemory) - Int64(clamping: after.usedMemory)
                completion(SmartReleaseResult(
                    estimatedBytes: estimated,
                    measuredUsedMemoryDelta: delta,
                    requestedCount: request.requested,
                    acceptedCount: request.accepted,
                    pressureBefore: before.pressure,
                    pressureAfter: after.pressure
                ))
                self.refreshNow()
            }
        }
    }

    private func installTimers() {
        guard started else { return }
        memoryTimer?.cancel()
        processTimer?.cancel()

        let memoryTimer = DispatchSource.makeTimerSource(queue: queue)
        memoryTimer.schedule(deadline: .now(), repeating: settings.refreshInterval, leeway: .milliseconds(200))
        memoryTimer.setEventHandler { [weak self] in self?.sampleMemoryOnQueue() }
        memoryTimer.activate()
        self.memoryTimer = memoryTimer

        let processTimer = DispatchSource.makeTimerSource(queue: queue)
        processTimer.schedule(deadline: .now(), repeating: settings.processScanInterval, leeway: .milliseconds(500))
        processTimer.setEventHandler { [weak self] in self?.sampleProcessesOnQueue() }
        processTimer.activate()
        self.processTimer = processTimer
    }

    private func installPressureSource() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: queue
        )
        source.setEventHandler { [weak self] in self?.sampleMemoryOnQueue() }
        source.activate()
        pressureSource = source
    }

    private func sampleMemoryOnQueue() {
        guard let stats = memoryMonitor.sample() else {
            DispatchQueue.main.async { [weak self] in
                self?.lastError = "Unable to read Mach virtual-memory statistics."
            }
            return
        }
        publishMemory(stats)
    }

    private func sampleMemory(completion: @escaping (MemoryStats) -> Void) {
        queue.async { [weak self] in
            guard let self, let stats = self.memoryMonitor.sample() else { return }
            DispatchQueue.main.async {
                self.memoryStats = stats
                self.lastError = nil
                self.alertEngine.evaluateMemory(stats, settings: self.settings)
                completion(stats)
            }
        }
    }

    private func publishMemory(_ stats: MemoryStats) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.memoryStats = stats
            self.lastError = nil
            self.alertEngine.evaluateMemory(stats, settings: self.settings)
        }
    }

    private func sampleProcessesOnQueue() {
        let processes = processMonitor.sample()
        let findings = growthDetector.update(processes: processes)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.allProcesses = processes
            self.topProcesses = Array(processes.prefix(5))
            self.growthFindings = findings
            self.alertEngine.evaluateGrowth(findings, settings: self.settings)
        }
    }
}
