import Foundation

final class AlertEngine {
    private let notifications: NotificationManager
    private var ramTracker = SustainedThresholdTracker(
        threshold: 85,
        dwell: 30,
        hysteresis: 5,
        recoveryDwell: 60,
        cooldown: 10 * 60
    )
    private var configuredRAMThreshold = 85.0
    private var pressureArmed = true
    private var warningSince: Date?
    private var lastPressureNotification: Date?
    private var growthLastFired: [ProcessIdentity: Date] = [:]

    init(notifications: NotificationManager = .shared) {
        self.notifications = notifications
    }

    func evaluateMemory(_ memory: MemoryStats, settings: SettingsStore, now: Date = Date()) {
        if configuredRAMThreshold != settings.ramThresholdPercent {
            configuredRAMThreshold = settings.ramThresholdPercent
            ramTracker.reset(threshold: configuredRAMThreshold)
        }

        if settings.ramThresholdAlertsEnabled {
            if ramTracker.evaluate(value: memory.usagePercentage, now: now) {
                notifications.send(
                    identifier: "mempulse.ram-threshold",
                    title: settings.text(
                        "RAM usage stayed above \(Int(configuredRAMThreshold))%",
                        "RAM 使用率持续高于 \(Int(configuredRAMThreshold))%"
                    ),
                    body: settings.text(
                        "Memory used is \(MemoryFormatter.string(memory.usedMemory)) of \(MemoryFormatter.string(memory.totalMemory)). Pressure: \(memory.pressure.title).",
                        "已使用 \(MemoryFormatter.string(memory.usedMemory)) / \(MemoryFormatter.string(memory.totalMemory))，内存压力：\(pressureTitle(memory.pressure, settings: settings))。"
                    )
                )
            }
        } else {
            ramTracker.reset(threshold: configuredRAMThreshold)
        }

        evaluatePressure(memory, settings: settings, now: now)
    }

    func evaluateGrowth(
        _ findings: [ProcessGrowthFinding],
        settings: SettingsStore,
        now: Date = Date()
    ) {
        guard settings.growthAlertsEnabled else {
            growthLastFired.removeAll()
            return
        }
        let active = Set(findings.map(\.identity))
        growthLastFired = growthLastFired.filter { active.contains($0.key) || now.timeIntervalSince($0.value) < 20 * 60 }

        for finding in findings {
            if let last = growthLastFired[finding.identity], now.timeIntervalSince(last) < 15 * 60 {
                continue
            }
            growthLastFired[finding.identity] = now
            notifications.send(
                identifier: "mempulse.growth.\(finding.identity.pid).\(finding.identity.startTimeMicroseconds)",
                title: settings.text("\(finding.processName) memory is growing", "\(finding.processName) 的内存正在增长"),
                body: settings.text(
                    "\(MemoryFormatter.string(finding.startBytes)) → \(MemoryFormatter.string(finding.currentBytes)); +\(MemoryFormatter.string(finding.growthBytes)) in the last 5 minutes.",
                    "\(MemoryFormatter.string(finding.startBytes)) → \(MemoryFormatter.string(finding.currentBytes))；过去 5 分钟增加 \(MemoryFormatter.string(finding.growthBytes))。"
                )
            )
        }
    }

    private func evaluatePressure(_ memory: MemoryStats, settings: SettingsStore, now: Date) {
        guard settings.pressureAlertsEnabled else {
            warningSince = nil
            pressureArmed = true
            return
        }

        switch memory.pressure {
        case .critical:
            warningSince = nil
            if pressureArmed && pressureCooldownAllows(now) {
                pressureArmed = false
                lastPressureNotification = now
                notifications.send(
                    identifier: "mempulse.pressure",
                    title: settings.text("Memory pressure is critical", "内存压力严重"),
                    body: settings.text(
                        "macOS is under heavy memory pressure. Open MemPulse to review the largest processes.",
                        "macOS 正处于较高内存压力下，请打开 MemPulse 检查高内存进程。"
                    )
                )
            }
        case .warning:
            guard settings.pressureAlertThreshold == .warning else {
                warningSince = nil
                return
            }
            if warningSince == nil { warningSince = now }
            if pressureArmed,
               now.timeIntervalSince(warningSince ?? now) >= 15,
               pressureCooldownAllows(now) {
                pressureArmed = false
                lastPressureNotification = now
                notifications.send(
                    identifier: "mempulse.pressure",
                    title: settings.text("Memory pressure is elevated", "内存压力升高"),
                    body: settings.text(
                        "Compressed memory and swap may be increasing. Open MemPulse to see the likely cause.",
                        "压缩内存和交换空间可能正在增加，请打开 MemPulse 查看可能原因。"
                    )
                )
            }
        case .normal:
            warningSince = nil
            pressureArmed = true
        case .unknown:
            warningSince = nil
        }
    }

    private func pressureCooldownAllows(_ now: Date) -> Bool {
        guard let lastPressureNotification else { return true }
        return now.timeIntervalSince(lastPressureNotification) >= 10 * 60
    }

    private func pressureTitle(_ pressure: MemoryPressureLevel, settings: SettingsStore) -> String {
        switch pressure {
        case .normal: return settings.text("Normal", "正常")
        case .warning: return settings.text("Warning", "警告")
        case .critical: return settings.text("Critical", "严重")
        case .unknown: return settings.text("Unknown", "未知")
        }
    }
}
