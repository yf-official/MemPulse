import Foundation

enum MemoryFormatter {
    private static let formatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB, .useTB]
        formatter.countStyle = .memory
        formatter.includesUnit = true
        formatter.isAdaptive = true
        formatter.zeroPadsFractionDigits = false
        return formatter
    }()

    static func string(_ bytes: UInt64) -> String {
        if bytes == 0 { return "0 MB" }
        return formatter.string(fromByteCount: Int64(clamping: bytes))
    }

    static func signedString(_ bytes: Int64) -> String {
        let magnitude = bytes == .min ? UInt64.max : UInt64(abs(bytes))
        let prefix = bytes > 0 ? "+" : (bytes < 0 ? "−" : "")
        return prefix + string(magnitude)
    }
}
