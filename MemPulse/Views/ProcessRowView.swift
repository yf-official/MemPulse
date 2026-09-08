import AppKit
import SwiftUI

struct ProcessRowView: View {
    let process: ProcessMemoryInfo
    let growth: ProcessGrowthFinding?
    var language: AppLanguage = .system

    var body: some View {
        HStack(spacing: 9) {
            processIcon
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(process.applicationName)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                if let growth {
                    Text("↑ \(MemoryFormatter.string(growth.growthBytes)) / \(language.text("5 min", "5 分钟"))")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundStyle(.orange)
                } else if process.footprintIsEstimated {
                    Text(language.text("Resident estimate", "驻留内存估算"))
                        .font(.system(size: 9.5))
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 6)

            Text(MemoryFormatter.string(process.memoryBytes))
                .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .help("\(process.processName) · PID \(process.pid)")
    }

    @ViewBuilder
    private var processIcon: some View {
        if let path = process.applicationBundlePath ?? process.executablePath {
            Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.secondary)
                .padding(2)
        }
    }
}
