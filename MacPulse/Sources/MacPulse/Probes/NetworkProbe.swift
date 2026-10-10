import Darwin
import Foundation

/// Throughput of the physical interfaces (Wi-Fi / Ethernet / Thunderbolt), not VPN tunnels,
/// so traffic isn't counted twice.
final class NetworkProbe {
    private var previous: [String: (rx: UInt32, tx: UInt32)] = [:]
    private var lastTime: Date?
    private var totalDown: UInt64 = 0
    private var totalUp: UInt64 = 0

    func sample() -> NetworkStats {
        var counters: [String: (rx: UInt32, tx: UInt32)] = [:]
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return NetworkStats() }
        defer { freeifaddrs(head) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let entry = cursor {
            defer { cursor = entry.pointee.ifa_next }
            let name = String(cString: entry.pointee.ifa_name)
            let flags = Int32(entry.pointee.ifa_flags)
            guard name.hasPrefix("en"),
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0,
                  entry.pointee.ifa_addr?.pointee.sa_family == UInt8(AF_LINK),
                  let data = entry.pointee.ifa_data?.assumingMemoryBound(to: if_data.self).pointee
            else { continue }
            counters[name] = (data.ifi_ibytes, data.ifi_obytes)
        }

        let now = Date()
        defer { previous = counters; lastTime = now }
        guard let lastTime else { return NetworkStats() }
        let dt = max(now.timeIntervalSince(lastTime), 0.001)

        var down: UInt64 = 0, up: UInt64 = 0
        var busiest: (name: String, bytes: UInt64)?
        for (name, now) in counters {
            guard let before = previous[name] else { continue }
            let rx = UInt64(now.rx &- before.rx)   // wrapping: the kernel counters are 32-bit
            let tx = UInt64(now.tx &- before.tx)
            down += rx; up += tx
            if rx + tx > (busiest?.bytes ?? 0) { busiest = (name, rx + tx) }
        }
        totalDown += down
        totalUp += up
        return NetworkStats(down: Double(down) / dt, up: Double(up) / dt,
                            totalDown: totalDown, totalUp: totalUp, interface: busiest?.name)
    }
}
