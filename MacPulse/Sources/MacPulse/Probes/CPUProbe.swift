import Darwin

/// Per-core CPU load from the delta between two tick snapshots.
final class CPUProbe {
    private var previous: [[UInt32]] = []

    func sample() -> CPUStats {
        var cpuCount: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &info, &infoCount) == KERN_SUCCESS,
              let info else { return CPUStats() }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(UInt(bitPattern: info)),
                          vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.stride))
        }

        let stride = Int(CPU_STATE_MAX)
        let current: [[UInt32]] = (0..<Int(cpuCount)).map { i in
            [CPU_STATE_USER, CPU_STATE_SYSTEM, CPU_STATE_IDLE, CPU_STATE_NICE].map {
                UInt32(bitPattern: info[i * stride + Int($0)])
            }
        }
        defer { previous = current }
        guard previous.count == current.count else { return CPUStats() }

        var stats = CPUStats()
        var user = 0.0, system = 0.0, idle = 0.0
        for (now, before) in zip(current, previous) {
            let u = Double(now[0] &- before[0]) + Double(now[3] &- before[3])
            let s = Double(now[1] &- before[1])
            let i = Double(now[2] &- before[2])
            let total = u + s + i
            stats.cores.append(total > 0 ? (u + s) / total : 0)
            user += u; system += s; idle += i
        }
        let total = user + system + idle
        if total > 0 {
            stats.user = user / total
            stats.system = system / total
            stats.idle = idle / total
            stats.total = (user + system) / total
        }
        return stats
    }
}
