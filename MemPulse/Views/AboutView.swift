import SwiftUI

struct AboutView: View {
    @ObservedObject var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            detailHeader
            Divider()

            VStack(spacing: 14) {
                Spacer()
                Image("MemPulseLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 104, height: 104)
                    .accessibilityLabel("MemPulse logo")
                Text("MemPulse")
                    .font(.system(size: 22, weight: .semibold))
                Text(settings.text("A lightweight memory monitor for macOS.", "轻量的 macOS 内存监控工具。"))
                    .foregroundStyle(.secondary)
                Text("Monitor. Detect. Release.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                Text(settings.text("Version 1.0.0", "版本 1.0.0"))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(settings.text("100% local · No telemetry · No account", "100% 本地 · 无遥测 · 无需账号"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
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

            Text(settings.text("About", "关于"))
                .font(.system(size: 13, weight: .semibold))

            Spacer()

            Color.clear.frame(width: 42, height: 1)
        }
        .padding(.horizontal, 14)
        .frame(height: 42)
    }
}
