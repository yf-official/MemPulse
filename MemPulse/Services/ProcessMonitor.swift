import AppKit
import Darwin
import Foundation

final class ProcessMonitor {
    private struct Metadata {
        let applicationName: String
        let bundleIdentifier: String?
        let executablePath: String?
        let applicationBundlePath: String?
    }

    private var metadataCache: [ProcessIdentity: Metadata] = [:]

    func sample(limit: Int? = nil) -> [ProcessMemoryInfo] {
        let pids = allPIDs()
        var processes: [ProcessMemoryInfo] = []
        processes.reserveCapacity(pids.count)
        var liveIdentities = Set<ProcessIdentity>()

        for pid in pids where pid > 0 {
            guard let info = taskAllInfo(pid) else { continue }

            let seconds = UInt64(max(info.pbsd.pbi_start_tvsec, 0))
            let microseconds = UInt64(max(info.pbsd.pbi_start_tvusec, 0))
            let identity = ProcessIdentity(
                pid: pid,
                startTimeMicroseconds: seconds &* 1_000_000 &+ microseconds
            )
            liveIdentities.insert(identity)

            let processName = name(pid)
            let executablePath = path(pid)
            let metadata = metadataCache[identity] ?? resolveMetadata(
                processName: processName,
                executablePath: executablePath
            )
            metadataCache[identity] = metadata

            var footprintError: Int32 = 0
            let footprint = mp_process_phys_footprint(pid, &footprintError)
            let resident = UInt64(info.ptinfo.pti_resident_size)
            let memoryBytes = footprintError == 0 && footprint > 0 ? footprint : resident

            processes.append(ProcessMemoryInfo(
                pid: pid,
                parentPID: Int32(info.pbsd.pbi_ppid),
                uid: UInt32(info.pbsd.pbi_uid),
                startTimeMicroseconds: identity.startTimeMicroseconds,
                processName: processName,
                applicationName: metadata.applicationName,
                bundleIdentifier: metadata.bundleIdentifier,
                executablePath: metadata.executablePath,
                applicationBundlePath: metadata.applicationBundlePath,
                memoryBytes: memoryBytes,
                residentBytes: resident,
                footprintIsEstimated: footprintError != 0 || footprint == 0
            ))
        }

        metadataCache = metadataCache.filter { liveIdentities.contains($0.key) }
        let sorted = processes.sorted {
            if $0.memoryBytes == $1.memoryBytes { return $0.pid < $1.pid }
            return $0.memoryBytes > $1.memoryBytes
        }
        guard let limit else { return sorted }
        return Array(sorted.prefix(limit))
    }

    private func allPIDs() -> [pid_t] {
        let estimate = proc_listallpids(nil, 0)
        guard estimate > 0 else { return [] }
        var pids = [pid_t](repeating: 0, count: Int(estimate) + 256)
        let count = pids.withUnsafeMutableBufferPointer { buffer in
            proc_listallpids(
                buffer.baseAddress,
                Int32(buffer.count * MemoryLayout<pid_t>.stride)
            )
        }
        guard count > 0 else { return [] }
        return Array(pids.prefix(min(Int(count), pids.count))).filter { $0 > 0 }
    }

    private func taskAllInfo(_ pid: pid_t) -> proc_taskallinfo? {
        var info = proc_taskallinfo()
        let expected = Int32(MemoryLayout<proc_taskallinfo>.stride)
        let read = withUnsafeMutablePointer(to: &info) {
            proc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, $0, expected)
        }
        return read == expected ? info : nil
    }

    private func name(_ pid: pid_t) -> String {
        var buffer = [CChar](repeating: 0, count: 256)
        let length = buffer.withUnsafeMutableBufferPointer { pointer in
            proc_name(pid, pointer.baseAddress, UInt32(pointer.count))
        }
        guard length > 0 else { return "PID \(pid)" }
        return buffer.withUnsafeBufferPointer { pointer in
            String(cString: pointer.baseAddress!)
        }
    }

    private func path(_ pid: pid_t) -> String? {
        var buffer = [CChar](repeating: 0, count: 4 * 1024)
        let length = buffer.withUnsafeMutableBufferPointer { pointer in
            proc_pidpath(pid, pointer.baseAddress, UInt32(pointer.count))
        }
        guard length > 0 else { return nil }
        return buffer.withUnsafeBufferPointer { pointer in
            String(cString: pointer.baseAddress!)
        }
    }

    private func resolveMetadata(processName: String, executablePath: String?) -> Metadata {
        guard let executablePath,
              let bundlePath = outermostApplicationBundlePath(in: executablePath),
              let bundle = Bundle(path: bundlePath) else {
            return Metadata(
                applicationName: processName,
                bundleIdentifier: nil,
                executablePath: executablePath,
                applicationBundlePath: nil
            )
        }

        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
        return Metadata(
            applicationName: displayName ?? bundleName ?? processName,
            bundleIdentifier: bundle.bundleIdentifier,
            executablePath: executablePath,
            applicationBundlePath: bundlePath
        )
    }

    private func outermostApplicationBundlePath(in executablePath: String) -> String? {
        let nsPath = executablePath as NSString
        let range = nsPath.range(of: ".app/")
        guard range.location != NSNotFound else { return nil }
        return nsPath.substring(to: range.location + 4)
    }
}
