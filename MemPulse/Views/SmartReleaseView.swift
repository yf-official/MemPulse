import SwiftUI

struct SmartReleaseView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var candidates: [SmartReleaseCandidate] = []
    @State private var selection = Set<Int32>()
    @State private var isReleasing = false
    @State private var result: SmartReleaseResult?
    private var settings: SettingsStore { model.settings }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { dismiss() } label: {
                    Label(settings.text("Back", "返回"), systemImage: "chevron.left")
                }
                .buttonStyle(.plain)
                Spacer()
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(settings.text("Smart Release", "智能释放"))
                        .font(.system(size: 17, weight: .semibold))
                    Text("\(settings.text("Estimated potential", "预计可释放")): \(MemoryFormatter.string(selectedBytes))")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(settings.text(
                "Only normal Quit requests are sent. Apps may ask to save work or refuse to quit. Nothing is force-quit.",
                "仅发送正常退出请求。应用可以提示保存或拒绝退出，不会强制结束任何进程。"
            ))
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            if let result {
                resultView(result)
            } else if candidates.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "checkmark.shield")
                        .font(.system(size: 30))
                        .foregroundStyle(.secondary)
                    Text(settings.text("No Safe Candidates", "没有安全候选应用"))
                        .font(.headline)
                    Text(settings.text("Frontmost, system, and protected apps are excluded.", "已排除前台应用、系统进程和受保护应用。"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, minHeight: 260)
            } else {
                ScrollView {
                    LazyVStack(spacing: 5) {
                        ForEach(candidates) { candidate in
                            Toggle(isOn: selectionBinding(for: candidate.pid)) {
                                HStack {
                                    Text(candidate.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Text(MemoryFormatter.string(candidate.estimatedBytes))
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            HStack {
                Button(result == nil ? settings.text("Cancel", "取消") : settings.text("Done", "完成")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                if result == nil {
                    Button(settings.text("Release", "释放")) { releaseSelected() }
                        .keyboardShortcut(.defaultAction)
                        .disabled(selection.isEmpty || isReleasing)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationBarBackButtonHidden(true)
        .onAppear(perform: loadCandidates)
    }

    private var selectedBytes: UInt64 {
        candidates.filter { selection.contains($0.pid) }.reduce(UInt64(0)) {
            MemoryMath.addingClamped($0, $1.estimatedBytes)
        }
    }

    private func selectionBinding(for pid: Int32) -> Binding<Bool> {
        Binding(
            get: { selection.contains(pid) },
            set: { selected in
                if selected { selection.insert(pid) } else { selection.remove(pid) }
            }
        )
    }

    private func loadCandidates() {
        candidates = Array(model.smartReleaseCandidates().prefix(12))
        selection.removeAll()
    }

    private func releaseSelected() {
        let selected = candidates.filter { selection.contains($0.pid) }
        guard !selected.isEmpty else { return }
        isReleasing = true
        model.performSmartRelease(selected) { outcome in
            result = outcome
            isReleasing = false
        }
    }

    private func resultView(_ result: SmartReleaseResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(settings.text("Quit requests sent", "已发送退出请求"), systemImage: "checkmark.circle")
                .font(.system(size: 14, weight: .semibold))
            metric(settings.text("Estimated selected", "所选应用估算"), MemoryFormatter.string(result.estimatedBytes))
            metric(settings.text("Requests accepted", "已接受请求"), "\(result.acceptedCount) / \(result.requestedCount)")
            metric(
                settings.text("Measured used-memory change", "实测已用内存变化"),
                MemoryFormatter.signedString(result.measuredUsedMemoryDelta)
            )
            metric(
                settings.text("Memory Pressure", "内存压力"),
                "\(pressureTitle(result.pressureBefore)) → \(pressureTitle(result.pressureAfter))"
            )
            Text(settings.text(
                "The measured delta is system-wide and may differ from the estimate because macOS can immediately reuse or reclassify memory.",
                "实测值来自全系统，macOS 可能立即复用或重新分类内存，因此可能与估算不同。"
            ))
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
    }

    private func metric(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.system(.body, design: .monospaced))
        }
        .font(.system(size: 11.5))
    }

    private func pressureTitle(_ pressure: MemoryPressureLevel) -> String {
        switch pressure {
        case .normal: return settings.text("Normal", "正常")
        case .warning: return settings.text("Warning", "警告")
        case .critical: return settings.text("Critical", "严重")
        case .unknown: return settings.text("Unknown", "未知")
        }
    }
}
