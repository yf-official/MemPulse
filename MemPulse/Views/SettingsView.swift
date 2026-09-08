import SwiftUI

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider()
            settingsForm
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationBarBackButtonHidden(true)
    }

    private var detailHeader: some View {
        HStack(spacing: 10) {
            Button { dismiss() } label: {
                Label(settings.text("Back", "返回"), systemImage: "chevron.left")
                    .font(.system(size: 11.5, weight: .medium))
            }
            .buttonStyle(.plain)

            Spacer()

            Text(settings.text("Settings", "设置"))
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Color.clear.frame(width: 42, height: 1)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }

    private var settingsForm: some View {
        Form {
            Section(settings.text("General", "通用")) {
                Picker(settings.text("Language", "语言"), selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                Toggle(
                    settings.text("Launch MemPulse at Login", "登录时启动 MemPulse"),
                    isOn: Binding(
                        get: { settings.launchAtLoginEnabled },
                        set: { settings.setLaunchAtLogin($0) }
                    )
                )
                if let error = settings.launchAtLoginError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section(settings.text("Monitoring", "监控")) {
                Picker(settings.text("Memory refresh", "内存刷新"), selection: $settings.refreshInterval) {
                    Text(settings.text("2 sec", "2 秒")).tag(2.0)
                    Text(settings.text("3 sec", "3 秒")).tag(3.0)
                    Text(settings.text("5 sec", "5 秒")).tag(5.0)
                }
                Picker(settings.text("Process scan", "进程扫描"), selection: $settings.processScanInterval) {
                    Text(settings.text("5 sec", "5 秒")).tag(5.0)
                    Text(settings.text("10 sec", "10 秒")).tag(10.0)
                    Text(settings.text("15 sec", "15 秒")).tag(15.0)
                }
            }

            Section(settings.text("Notifications", "通知")) {
                Toggle(settings.text("Memory Growth Alerts", "内存异常增长提醒"), isOn: $settings.growthAlertsEnabled)
                    .onChange(of: settings.growthAlertsEnabled) { enabled in
                        if enabled { NotificationManager.shared.requestAuthorization() }
                    }
                Toggle(settings.text("Memory Pressure Alerts", "内存压力提醒"), isOn: $settings.pressureAlertsEnabled)
                    .onChange(of: settings.pressureAlertsEnabled) { enabled in
                        if enabled { NotificationManager.shared.requestAuthorization() }
                    }
                if settings.pressureAlertsEnabled {
                    Picker(settings.text("Alert level", "触发级别"), selection: $settings.pressureAlertThreshold) {
                        Text(settings.text("Warning (Recommended)", "警告（建议）")).tag(PressureAlertThreshold.warning)
                        Text(settings.text("Critical only", "仅严重时")).tag(PressureAlertThreshold.critical)
                    }
                    Text(settings.text(
                        "This only changes when MemPulse notifies you. The live Memory Pressure state always comes directly from macOS.",
                        "这只改变 MemPulse 的提醒时机；实时内存压力状态始终直接来自 macOS。"
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle(settings.text("RAM Threshold Alert", "RAM 阈值提醒"), isOn: $settings.ramThresholdAlertsEnabled)
                    .onChange(of: settings.ramThresholdAlertsEnabled) { enabled in
                        if enabled { NotificationManager.shared.requestAuthorization() }
                    }
                if settings.ramThresholdAlertsEnabled {
                    HStack {
                        Text(settings.text("Threshold", "阈值"))
                        Spacer()
                        Stepper(
                            "\(Int(settings.ramThresholdPercent))%",
                            value: $settings.ramThresholdPercent,
                            in: 70...95,
                            step: 5
                        )
                    }
                    Text(settings.text(
                        "Recommended: 85%. Alerts after 30 seconds above the threshold; resets after 60 seconds below threshold − 5%. macOS Memory Pressure remains system-defined.",
                        "建议阈值：85%。高于阈值持续 30 秒后提醒；低于阈值减 5% 持续 60 秒后恢复待命。macOS 内存压力状态仍由系统判定。"
                    ))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(settings.text("Smart Release", "智能释放")) {
                Toggle(settings.text("Allow Smart Release", "允许智能释放"), isOn: $settings.smartReleaseEnabled)
                Text(settings.text(
                    "Normal Quit only. Force Quit, cache purge, sudo, and private APIs are not used.",
                    "仅发送正常退出请求；不使用强制退出、缓存清理、sudo 或私有 API。"
                ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let error = model.lastError {
                Section(settings.text("Diagnostics", "诊断")) {
                    Text(error).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
