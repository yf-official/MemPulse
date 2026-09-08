import Combine
import Foundation
import ServiceManagement

enum PressureAlertThreshold: String, CaseIterable, Identifiable {
    case warning
    case critical

    var id: String { rawValue }
}

final class SettingsStore: ObservableObject {
    private enum Key {
        static let refreshInterval = "monitoring.refreshInterval"
        static let processScanInterval = "monitoring.processScanInterval"
        static let growthAlertsEnabled = "notifications.growthAlertsEnabled"
        static let ramThresholdAlertsEnabled = "notifications.ramThresholdAlertsEnabled"
        static let ramThresholdPercent = "notifications.ramThresholdPercent"
        static let pressureAlertsEnabled = "notifications.pressureAlertsEnabled"
        static let pressureAlertThreshold = "notifications.pressureAlertThreshold"
        static let smartReleaseEnabled = "smartRelease.enabled"
        static let appLanguage = "general.appLanguage"
    }

    private let defaults: UserDefaults

    @Published var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: Key.refreshInterval) }
    }
    @Published var processScanInterval: Double {
        didSet { defaults.set(processScanInterval, forKey: Key.processScanInterval) }
    }
    @Published var growthAlertsEnabled: Bool {
        didSet { defaults.set(growthAlertsEnabled, forKey: Key.growthAlertsEnabled) }
    }
    @Published var ramThresholdAlertsEnabled: Bool {
        didSet { defaults.set(ramThresholdAlertsEnabled, forKey: Key.ramThresholdAlertsEnabled) }
    }
    @Published var ramThresholdPercent: Double {
        didSet { defaults.set(ramThresholdPercent, forKey: Key.ramThresholdPercent) }
    }
    @Published var pressureAlertsEnabled: Bool {
        didSet { defaults.set(pressureAlertsEnabled, forKey: Key.pressureAlertsEnabled) }
    }
    @Published var pressureAlertThreshold: PressureAlertThreshold {
        didSet { defaults.set(pressureAlertThreshold.rawValue, forKey: Key.pressureAlertThreshold) }
    }
    @Published var smartReleaseEnabled: Bool {
        didSet { defaults.set(smartReleaseEnabled, forKey: Key.smartReleaseEnabled) }
    }
    @Published var appLanguage: AppLanguage {
        didSet { defaults.set(appLanguage.rawValue, forKey: Key.appLanguage) }
    }
    @Published private(set) var launchAtLoginEnabled: Bool
    @Published private(set) var launchAtLoginError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        refreshInterval = defaults.object(forKey: Key.refreshInterval) as? Double ?? 2
        processScanInterval = defaults.object(forKey: Key.processScanInterval) as? Double ?? 5
        growthAlertsEnabled = defaults.object(forKey: Key.growthAlertsEnabled) as? Bool ?? true
        ramThresholdAlertsEnabled = defaults.object(forKey: Key.ramThresholdAlertsEnabled) as? Bool ?? false
        ramThresholdPercent = defaults.object(forKey: Key.ramThresholdPercent) as? Double ?? 85
        pressureAlertsEnabled = defaults.object(forKey: Key.pressureAlertsEnabled) as? Bool ?? true
        pressureAlertThreshold = PressureAlertThreshold(
            rawValue: defaults.string(forKey: Key.pressureAlertThreshold) ?? ""
        ) ?? .warning
        smartReleaseEnabled = defaults.object(forKey: Key.smartReleaseEnabled) as? Bool ?? true
        appLanguage = AppLanguage(rawValue: defaults.string(forKey: Key.appLanguage) ?? "") ?? .system
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }

    func text(_ english: String, _ chinese: String) -> String {
        appLanguage.text(english, chinese)
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginError = nil
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            launchAtLoginError = error.localizedDescription
        }
    }
}
