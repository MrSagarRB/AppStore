import Foundation

enum Format {
    static func percent(_ fraction: Double) -> String { "\(Int((fraction * 100).rounded()))%" }

    static func bytes(_ value: UInt64) -> String {
        let gb = Double(value) / 1_073_741_824
        return gb >= 1 ? String(format: "%.1f GB", gb) : String(format: "%.0f MB", Double(value) / 1_048_576)
    }

    /// Throughput. `compact` drops the "/s" and spacing for the menu bar.
    static func speed(_ bytesPerSecond: Double, compact: Bool = false) -> String {
        let units: [(String, Double)] = [("GB", 1e9), ("MB", 1e6), ("KB", 1e3)]
        for (unit, size) in units where bytesPerSecond >= size {
            let v = bytesPerSecond / size
            let text = v >= 100 ? String(format: "%.0f", v) : String(format: "%.1f", v)
            return compact ? "\(text)\(unit.prefix(1))" : "\(text) \(unit)/s"
        }
        let b = String(format: "%.0f", bytesPerSecond)
        return compact ? "\(b)B" : "\(b) B/s"
    }

    static func total(_ value: UInt64) -> String {
        let v = Double(value)
        if v >= 1e9 { return String(format: "%.2f GB", v / 1e9) }
        if v >= 1e6 { return String(format: "%.1f MB", v / 1e6) }
        return String(format: "%.0f KB", v / 1e3)
    }

    static func temperature(_ celsius: Double, fahrenheit: Bool) -> String {
        fahrenheit ? "\(Int((celsius * 9 / 5 + 32).rounded()))°F" : "\(Int(celsius.rounded()))°C"
    }

    static func duration(minutes: Int) -> String {
        minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
    }
}

extension UserDefaults {
    static func registerMacPulseDefaults() {
        standard.register(defaults: [
            "showCPU": true, "showMemory": true, "showTemperature": true,
            "showBattery": true, "showNetwork": true,
            "interval": 2.0, "fahrenheit": false,
        ])
    }
}
