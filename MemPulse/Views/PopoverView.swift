import AppKit
import SwiftUI

struct PopoverView: View {
    @ObservedObject var model: AppModel
    let openMainWindow: () -> Void

    private var settings: SettingsStore { model.settings }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    header
                    pressureAndUsage
                        .padding(.top, 13)

                    Divider()
                        .padding(.vertical, 13)

                    processSection

                    Spacer(minLength: 10)

                    Divider()
                        .padding(.bottom, 12)

                    actions
                }
                .padding(.horizontal, 18)
                .padding(.top, 16)
                .padding(.bottom, 14)
            }
            .frame(width: 344, height: 520)
            .navigationTitle("")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("MemPulse")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text(settings.text("Memory at a glance", "内存状态一览"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text(memoryPercent)
                    .font(.system(size: 27, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("RAM")
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var pressureAndUsage: some View {
        VStack(spacing: 11) {
            HStack(spacing: 7) {
                Circle()
                    .fill(pressureColor)
                    .frame(width: 8, height: 8)
                Text(settings.text("Memory Pressure", "内存压力"))
                    .font(.system(size: 11.5, weight: .medium))
                Spacer()
                Text(pressureTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(pressureColor)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(pressureColor)
                        .frame(width: max(5, geometry.size.width * model.memoryStats.usageFraction))
                }
            }
            .frame(height: 5)

            HStack(spacing: 0) {
                compactMetric(
                    settings.text("Used", "已用"),
                    MemoryFormatter.string(model.memoryStats.usedMemory)
                )
                metricDivider
                compactMetric(
                    settings.text("Compressed", "压缩"),
                    MemoryFormatter.string(model.memoryStats.compressedMemory)
                )
                metricDivider
                compactMetric(
                    settings.text("Swap", "交换"),
                    MemoryFormatter.string(model.memoryStats.swapUsed)
                )
            }
        }
    }

    private var processSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(alignment: .firstTextBaseline) {
                Text(settings.text("Top Processes", "高内存进程"))
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(settings.text("Physical footprint", "物理内存占用"))
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }

            if model.topProcesses.isEmpty {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(model.topProcesses.enumerated()), id: \.element.id) { index, process in
                        ProcessRowView(
                            process: process,
                            growth: model.growthFindings.first { $0.identity == process.id },
                            language: settings.appLanguage
                        )
                        .frame(height: 33)

                        if index < model.topProcesses.count - 1 {
                            Divider().padding(.leading, 31)
                        }
                    }
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button(action: openMainWindow) {
                Label(settings.text("Open MemPulse", "打开 MemPulse"), systemImage: "macwindow")
                    .font(.system(size: 12.5, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 30)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.bordered)

            HStack(spacing: 8) {
                if settings.smartReleaseEnabled {
                    NavigationLink {
                        SmartReleaseView(model: model)
                    } label: {
                        compactAction(settings.text("Smart Release", "智能释放"), icon: "leaf")
                    }
                    .buttonStyle(.bordered)
                }

                Button(action: SystemHelpers.openActivityMonitor) {
                    compactAction(settings.text("Activity Monitor", "活动监视器"), icon: "waveform.path.ecg")
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: 15) {
                NavigationLink {
                    SettingsView(model: model, settings: settings)
                } label: {
                    footerAction(settings.text("Settings", "设置"), icon: "gearshape")
                }

                NavigationLink {
                    AboutView(settings: settings)
                } label: {
                    footerAction(settings.text("About", "关于"), icon: "info.circle")
                }

                Spacer()

                Button {
                    NSApp.terminate(nil)
                } label: {
                    footerAction(settings.text("Quit", "退出"), icon: "power")
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var metricDivider: some View {
        Divider()
            .frame(height: 30)
            .padding(.horizontal, 10)
    }

    private func compactMetric(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9.5, weight: .medium))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactAction(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 11.5, weight: .medium))
            .frame(maxWidth: .infinity)
            .frame(height: 26)
            .contentShape(Rectangle())
    }

    private func footerAction(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
    }

    private var memoryPercent: String {
        "\(Int(model.memoryStats.usagePercentage.rounded()))%"
    }

    private var pressureColor: Color {
        switch model.memoryStats.pressure {
        case .normal: return Color(nsColor: .secondaryLabelColor)
        case .warning: return .orange
        case .critical: return .red
        case .unknown: return Color(nsColor: .tertiaryLabelColor)
        }
    }

    private var pressureTitle: String {
        switch model.memoryStats.pressure {
        case .normal: return settings.text("Normal", "正常")
        case .warning: return settings.text("Warning", "警告")
        case .critical: return settings.text("Critical", "严重")
        case .unknown: return settings.text("Unknown", "未知")
        }
    }
}
