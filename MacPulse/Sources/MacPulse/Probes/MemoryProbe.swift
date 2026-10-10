import Darwin

enum MemoryProbe {
    static func read() -> MemoryStats {
        var stats = MemoryStats()
        stats.total = sysctlValue("hw.memsize") ?? 0

        var vm = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &vm) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        if result == KERN_SUCCESS {
            let page = UInt64(vm_kernel_page_size)
            // Same breakdown Activity Monitor uses.
            stats.app = UInt64(vm.internal_page_count &- vm.purgeable_count) * page
            stats.wired = UInt64(vm.wire_count) * page
            stats.compressed = UInt64(vm.compressor_page_count) * page
            stats.cached = (UInt64(vm.external_page_count) + UInt64(vm.purgeable_count)) * page
        }

        var swap = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        if sysctlbyname("vm.swapusage", &swap, &size, nil, 0) == 0 { stats.swapUsed = swap.xsu_used }

        var level: Int32 = 1
        var levelSize = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &levelSize, nil, 0) == 0 {
            switch level {
            case 2: stats.pressure = .warning
            case 4: stats.pressure = .critical
            default: stats.pressure = .normal
            }
        }
        return stats
    }

    private static func sysctlValue(_ name: String) -> UInt64? {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        return sysctlbyname(name, &value, &size, nil, 0) == 0 ? value : nil
    }
}
