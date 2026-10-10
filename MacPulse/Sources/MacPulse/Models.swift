import Foundation

struct CPUStats {
    var total = 0.0      // 0...1
    var user = 0.0
    var system = 0.0
    var idle = 1.0
    var cores: [Double] = []
}

enum MemoryPressure {
    case normal, warning, critical

    var label: String {
        switch self {
        case .normal: "Normal"
        case .warning: "Warning"
        case .critical: "Critical"
        }
    }
}

struct MemoryStats {
    var total: UInt64 = 0
    var app: UInt64 = 0
    var wired: UInt64 = 0
    var compressed: UInt64 = 0
    var cached: UInt64 = 0
    var swapUsed: UInt64 = 0
    var pressure = MemoryPressure.normal

    var used: UInt64 { app + wired + compressed }
    var free: UInt64 { total > used + cached ? total - used - cached : 0 }
    var usedFraction: Double { total == 0 ? 0 : Double(used) / Double(total) }
}

struct ThermalStats {
    var cpu: Double?          // °C, hottest CPU die sensor
    var battery: Double?
    var ssd: Double?
    var state = ProcessInfo.ThermalState.nominal

    var headline: Double? { cpu ?? battery }

    var stateLabel: String {
        switch state {
        case .nominal: "Nominal"
        case .fair: "Fair"
        case .serious: "Serious"
        case .critical: "Critical"
        @unknown default: "Unknown"
        }
    }
}

struct BatteryStats {
    var present = false
    var percent = 0
    var isCharging = false
    var onAC = false
    var isCharged = false
    var minutesRemaining: Int?
    var healthPercent: Double?
    var cycles: Int?
    var watts: Double?          // current charge/discharge power
    var adapterWatts: Int?
    var temperature: Double?
}

struct NetworkStats {
    var down = 0.0              // bytes / second
    var up = 0.0
    var totalDown: UInt64 = 0   // since launch
    var totalUp: UInt64 = 0
    var interface: String?
}
