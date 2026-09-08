import Darwin
import Foundation

final class MemoryMonitor {
    private var previousSwapIns: UInt64?
    private var previousSwapOuts: UInt64?
    private var previousTimestamp: Date?

    func sample(now: Date = Date()) -> MemoryStats? {
        let host = mach_host_self()

        var rawPageSize: vm_size_t = 0
        guard host_page_size(host, &rawPageSize) == KERN_SUCCESS, rawPageSize > 0 else {
            return nil
        }
        let pageSize = UInt64(rawPageSize)

        var vm = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.stride / MemoryLayout<integer_t>.stride
        )
        let result = withUnsafeMutablePointer(to: &vm) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                host_statistics64(host, HOST_VM_INFO64, rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        let total = ProcessInfo.processInfo.physicalMemory
        let breakdown = MemoryMath.breakdown(
            total: total,
            freePages: UInt64(vm.free_count),
            internalPages: UInt64(vm.internal_page_count),
            externalPages: UInt64(vm.external_page_count),
            purgeablePages: UInt64(vm.purgeable_count),
            wiredPages: UInt64(vm.wire_count),
            compressedPages: UInt64(vm.compressor_page_count),
            pageSize: pageSize
        )

        var swap = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.stride
        let swapOK = sysctlbyname("vm.swapusage", &swap, &swapSize, nil, 0) == 0

        var pressureRaw: Int32 = 0
        var pressureSize = MemoryLayout<Int32>.stride
        let pressureOK = sysctlbyname(
            "kern.memorystatus_vm_pressure_level",
            &pressureRaw,
            &pressureSize,
            nil,
            0
        ) == 0

        let swapIns = UInt64(vm.swapins)
        let swapOuts = UInt64(vm.swapouts)
        var swapInRate = 0.0
        var swapOutRate = 0.0
        if let previousTimestamp,
           let previousSwapIns,
           let previousSwapOuts {
            let elapsed = now.timeIntervalSince(previousTimestamp)
            if elapsed > 0 {
                let inDelta = swapIns >= previousSwapIns ? swapIns - previousSwapIns : 0
                let outDelta = swapOuts >= previousSwapOuts ? swapOuts - previousSwapOuts : 0
                swapInRate = Double(MemoryMath.multipliedClamped(inDelta, pageSize)) / elapsed
                swapOutRate = Double(MemoryMath.multipliedClamped(outDelta, pageSize)) / elapsed
            }
        }
        previousSwapIns = swapIns
        previousSwapOuts = swapOuts
        previousTimestamp = now

        let pressure: MemoryPressureLevel
        if pressureOK {
            pressure = MemoryPressureLevel(rawValue: Int(pressureRaw)) ?? .normal
        } else {
            pressure = .unknown
        }

        return MemoryStats(
            totalMemory: total,
            usedMemory: breakdown.usedMemory,
            availableMemory: breakdown.availableMemory,
            freeMemory: MemoryMath.multipliedClamped(UInt64(vm.free_count), pageSize),
            activeMemory: MemoryMath.multipliedClamped(UInt64(vm.active_count), pageSize),
            inactiveMemory: MemoryMath.multipliedClamped(UInt64(vm.inactive_count), pageSize),
            wiredMemory: MemoryMath.multipliedClamped(UInt64(vm.wire_count), pageSize),
            compressedMemory: MemoryMath.multipliedClamped(UInt64(vm.compressor_page_count), pageSize),
            appMemory: breakdown.appMemory,
            cachedFiles: breakdown.cachedFiles,
            purgeableMemory: MemoryMath.multipliedClamped(UInt64(vm.purgeable_count), pageSize),
            swapTotal: swapOK ? UInt64(swap.xsu_total) : 0,
            swapUsed: swapOK ? UInt64(swap.xsu_used) : 0,
            swapInBytesPerSecond: swapInRate,
            swapOutBytesPerSecond: swapOutRate,
            pressure: pressure,
            timestamp: now
        )
    }
}
