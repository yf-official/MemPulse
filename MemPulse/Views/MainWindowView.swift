import AppKit
import SwiftUI

private enum MainSection: String, CaseIterable, Identifiable {
    case overview, processes, growth, settings, about
    var id: String { rawValue }
}

struct MainWindowView: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: SettingsStore
    @State private var selection: MainSection? = .overview
    @State private var showsSmartRelease = false

    init(model: AppModel) {
        self.model = model
        settings = model.settings
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    Image("MemPulseLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("MemPulse").font(.system(size: 14, weight: .semibold))
                        Text("Monitor. Detect. Release.")
                            .font(.system(size: 8.5, weight: .medium))
                            .tracking(0.25)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 20)

                VStack(spacing: 4) {
                    sidebarButton(.overview, "Overview", "概览", "circle.grid.2x2")
                    sidebarButton(.processes, "Processes", "进程", "list.bullet.rectangle")
                    sidebarButton(.growth, "Growth Alerts", "增长检测", "chart.line.uptrend.xyaxis")
                }
                .padding(.horizontal, 10)

                Divider().padding(.horizontal, 16).padding(.vertical, 14)

                VStack(spacing: 4) {
                    sidebarButton(.settings, "Settings", "设置", "slider.horizontal.3")
                    sidebarButton(.about, "About", "关于", "info.circle")
                }
                .padding(.horizontal, 10)

                Spacer()
            }
            .frame(width: 190)
            .background(.ultraThinMaterial)

            Divider()

            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(isPresented: $showsSmartRelease) {
            SmartReleaseView(model: model)
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selection ?? .overview {
        case .overview:
            OverviewDetail(model: model, showsSmartRelease: $showsSmartRelease)
        case .processes:
            ProcessesDetail(model: model)
        case .growth:
            GrowthDetail(model: model)
        case .settings:
            MainSettingsDetail(model: model, settings: settings)
        case .about:
            MainAboutDetail(settings: settings)
        }
    }

    private func sidebarButton(_ section: MainSection, _ english: String, _ chinese: String, _ icon: String) -> some View {
        Button {
            selection = section
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 18)
                Text(settings.text(english, chinese))
                    .font(.system(size: 12.5, weight: selection == section ? .semibold : .regular))
                Spacer()
            }
            .foregroundStyle(selection == section ? .primary : .secondary)
            .padding(.horizontal, 10)
            .frame(height: 34)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(selection == section ? Color.primary.opacity(0.075) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct OverviewDetail: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: SettingsStore
    @Binding var showsSmartRelease: Bool

    init(model: AppModel, showsSmartRelease: Binding<Bool>) {
        self.model = model
        settings = model.settings
        _showsSmartRelease = showsSmartRelease
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(settings.text("SYSTEM MEMORY", "系统内存"))
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.1)
                                .foregroundStyle(.tertiary)
                            Text(settings.text("Memory Overview", "内存概览"))
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(Int(model.memoryStats.usagePercentage.rounded()))%")
                                .font(.system(size: 42, weight: .medium, design: .rounded))
                                .monospacedDigit()
                            Text("\(MemoryFormatter.string(model.memoryStats.usedMemory)) / \(MemoryFormatter.string(model.memoryStats.totalMemory))")
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(spacing: 9) {
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(Color.primary.opacity(0.07))
                                Capsule()
                                    .fill(usageColor)
                                    .frame(width: max(5, geometry.size.width * model.memoryStats.usageFraction))
                            }
                        }
                        .frame(height: 5)

                        HStack {
                            Label(pressureTitle, systemImage: "circle.fill")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundStyle(pressureColor)
                            Spacer()
                            Text(settings.text("Live · updates automatically", "实时 · 自动更新"))
                                .font(.system(size: 9.5))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    Grid(alignment: .leading, horizontalSpacing: 36, verticalSpacing: 9) {
                        GridRow {
                            metric(settings.text("Memory Used", "已用内存"), MemoryFormatter.string(model.memoryStats.usedMemory))
                            metric(settings.text("Available", "可用内存"), MemoryFormatter.string(model.memoryStats.availableMemory))
                            metric(settings.text("Physical Memory", "物理内存"), MemoryFormatter.string(model.memoryStats.totalMemory))
                        }
                        Divider().gridCellColumns(3)
                        GridRow {
                            metric(settings.text("App Memory", "应用内存"), MemoryFormatter.string(model.memoryStats.appMemory))
                            metric(settings.text("Wired", "联动内存"), MemoryFormatter.string(model.memoryStats.wiredMemory))
                            metric(settings.text("Compressed", "压缩内存"), MemoryFormatter.string(model.memoryStats.compressedMemory))
                        }
                        GridRow {
                            metric(settings.text("Cached Files", "缓存文件"), MemoryFormatter.string(model.memoryStats.cachedFiles))
                            metric(settings.text("Swap Used", "交换空间"), MemoryFormatter.string(model.memoryStats.swapUsed))
                            metric(settings.text("Purgeable", "可清除内存"), MemoryFormatter.string(model.memoryStats.purgeableMemory))
                        }
                    }

                    HStack(alignment: .firstTextBaseline) {
                        Text(settings.text("Top Processes", "高内存进程"))
                            .font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text(settings.text("Physical footprint", "物理内存占用"))
                            .font(.caption).foregroundStyle(.secondary)
                    }

                    VStack(spacing: 5) {
                        ForEach(model.topProcesses) { process in
                            ProcessRowView(
                                process: process,
                                growth: model.growthFindings.first { $0.identity == process.id },
                                language: settings.appLanguage
                            )
                            if process.id != model.topProcesses.last?.id { Divider() }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 22)
                .padding(.bottom, 10)
            }
            Divider()
            HStack {
                Button {
                    showsSmartRelease = true
                } label: {
                    Label(settings.text("Smart Release…", "智能释放…"), systemImage: "leaf")
                }
                .disabled(!settings.smartReleaseEnabled)
                Button(settings.text("Open Activity Monitor", "打开活动监视器"), action: SystemHelpers.openActivityMonitor)
                Spacer()
                Text("MemPulse 1.0")
                    .font(.system(size: 9.5, design: .monospaced)).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 10)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.system(.body, design: .monospaced)).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pressureTitle: String {
        switch model.memoryStats.pressure {
        case .normal: return settings.text("Memory Pressure: Normal", "内存压力：正常")
        case .warning: return settings.text("Memory Pressure: Warning", "内存压力：警告")
        case .critical: return settings.text("Memory Pressure: Critical", "内存压力：严重")
        case .unknown: return settings.text("Memory Pressure: Unknown", "内存压力：未知")
        }
    }

    private var pressureColor: Color {
        switch model.memoryStats.pressure {
        case .warning: return .orange
        case .critical: return .red
        case .normal: return .secondary
        case .unknown: return Color(nsColor: .tertiaryLabelColor)
        }
    }

    private var usageColor: Color {
        switch model.memoryStats.pressure {
        case .warning: return .orange
        case .critical: return .red
        case .normal, .unknown: return Color(nsColor: .labelColor).opacity(0.72)
        }
    }
}

private struct ProcessesDetail: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: SettingsStore
    init(model: AppModel) { self.model = model; settings = model.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(settings.text("Memory Processes", "内存进程"))
                .font(.system(size: 24, weight: .semibold))
            Text(settings.text("Sorted by physical footprint. Helper processes remain separate in MVP.", "按物理内存占用排序；MVP 暂时保留独立的 Helper 进程。"))
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            ScrollView {
                LazyVStack(spacing: 9) {
                    ForEach(model.allProcesses.prefix(40)) { process in
                        ProcessRowView(
                            process: process,
                            growth: model.growthFindings.first { $0.identity == process.id },
                            language: settings.appLanguage
                        )
                        Divider()
                    }
                }
            }
        }
        .padding(28)
    }
}

private struct GrowthDetail: View {
    @ObservedObject var model: AppModel
    @ObservedObject private var settings: SettingsStore
    init(model: AppModel) { self.model = model; settings = model.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(settings.text("Memory Growth", "内存增长检测"))
                .font(.system(size: 24, weight: .semibold))
            Text(settings.text("A process is flagged only after a sustained five-minute trend, not a single spike.", "仅在进程持续约五分钟增长时标记，不会因单次波动报警。"))
                .font(.caption).foregroundStyle(.secondary)
            Divider()
            if model.growthFindings.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 36)).foregroundStyle(.secondary)
                    Text(settings.text("No unusual growth", "未发现异常增长")).font(.headline)
                    Text(settings.text("Recent process samples look stable.", "近期进程采样保持稳定。"))
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ForEach(model.growthFindings) { finding in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(finding.processName).font(.headline)
                            Text("\(MemoryFormatter.string(finding.startBytes)) → \(MemoryFormatter.string(finding.currentBytes))")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("+\(MemoryFormatter.string(finding.growthBytes)) / 5 min")
                            .foregroundStyle(.orange).monospacedDigit()
                    }
                }
            }
            Spacer()
        }
        .padding(28)
    }
}

private struct MainSettingsDetail: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: SettingsStore

    var body: some View {
        Form {
            Section(settings.text("General", "通用")) {
                Picker(settings.text("Language", "语言"), selection: $settings.appLanguage) {
                    ForEach(AppLanguage.allCases) { Text($0.displayName).tag($0) }
                }
                Toggle(settings.text("Launch MemPulse at Login", "登录时启动 MemPulse"), isOn: Binding(
                    get: { settings.launchAtLoginEnabled }, set: { settings.setLaunchAtLogin($0) }
                ))
            }
            Section(settings.text("Monitoring", "监控")) {
                Picker(settings.text("Memory refresh", "内存刷新"), selection: $settings.refreshInterval) {
                    Text("2 s").tag(2.0); Text("3 s").tag(3.0); Text("5 s").tag(5.0)
                }
                Picker(settings.text("Process scan", "进程扫描"), selection: $settings.processScanInterval) {
                    Text("5 s").tag(5.0); Text("10 s").tag(10.0); Text("15 s").tag(15.0)
                }
            }
            Section(settings.text("Notifications", "通知")) {
                Toggle(settings.text("Memory Growth Alerts", "内存异常增长提醒"), isOn: $settings.growthAlertsEnabled)
                Toggle(settings.text("Memory Pressure Alerts", "内存压力提醒"), isOn: $settings.pressureAlertsEnabled)
                if settings.pressureAlertsEnabled {
                    Picker(settings.text("Alert level", "触发级别"), selection: $settings.pressureAlertThreshold) {
                        Text(settings.text("Warning (Recommended)", "警告（建议）")).tag(PressureAlertThreshold.warning)
                        Text(settings.text("Critical only", "仅严重时")).tag(PressureAlertThreshold.critical)
                    }
                    Text(settings.text(
                        "This controls notifications only. The live Memory Pressure state always comes directly from macOS.",
                        "此选项只控制提醒时机；界面中的实时内存压力始终直接来自 macOS。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Toggle(settings.text("RAM Threshold Alert", "RAM 阈值提醒"), isOn: $settings.ramThresholdAlertsEnabled)
                if settings.ramThresholdAlertsEnabled {
                    Stepper("\(settings.text("Threshold", "阈值")): \(Int(settings.ramThresholdPercent))%", value: $settings.ramThresholdPercent, in: 70...95, step: 5)
                    Text(settings.text(
                        "Recommended: 85%. The macOS Memory Pressure state is system-defined and is not overridden.",
                        "建议阈值：85%。macOS 内存压力状态由系统判定，不会被此阈值覆盖。"
                    ))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
            Section(settings.text("Smart Release", "智能释放")) {
                Toggle(settings.text("Allow Smart Release", "允许智能释放"), isOn: $settings.smartReleaseEnabled)
                Text(settings.text("Normal Quit only; no force quit, purge, sudo, or private APIs.", "仅正常退出；不使用强退、purge、sudo 或私有 API。"))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct MainAboutDetail: View {
    @ObservedObject var settings: SettingsStore
    var body: some View {
        VStack(spacing: 14) {
            Image("MemPulseLogo").resizable().scaledToFit().frame(width: 140, height: 140)
            Text("MemPulse").font(.system(size: 28, weight: .semibold))
            Text(settings.text("A lightweight memory monitor for macOS.", "轻量的 macOS 内存监控工具。"))
                .foregroundStyle(.secondary)
            Text("Monitor. Detect. Release.").font(.headline)
            Text(settings.text("Version 1.0.0", "版本 1.0.0")).font(.caption).foregroundStyle(.secondary)
            Text(settings.text("100% local · No telemetry · No account", "100% 本地 · 无遥测 · 无需账号"))
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}
