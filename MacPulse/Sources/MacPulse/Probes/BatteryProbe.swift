import Foundation
import IOKit
import IOKit.ps

enum BatteryProbe {
    static func read() -> BatteryStats {
        var stats = BatteryStats()

        let info = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(info).takeRetainedValue() as [CFTypeRef]
        for source in sources {
            guard let d = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  d[kIOPSTypeKey] as? String == kIOPSInternalBatteryType else { continue }
            stats.present = true
            let current = d[kIOPSCurrentCapacityKey] as? Int ?? 0
            let max = d[kIOPSMaxCapacityKey] as? Int ?? 100
            stats.percent = max > 0 ? Int((Double(current) / Double(max) * 100).rounded()) : current
            stats.isCharging = d[kIOPSIsChargingKey] as? Bool ?? false
            stats.isCharged = d[kIOPSIsChargedKey] as? Bool ?? false
            stats.onAC = d[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let key = stats.isCharging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
            if let minutes = d[key] as? Int, minutes >= 0 { stats.minutesRemaining = minutes }
        }
        guard stats.present else { return stats }

        if let adapter = IOPSCopyExternalPowerAdapterDetails()?.takeRetainedValue() as? [String: Any] {
            stats.adapterWatts = adapter[kIOPSPowerAdapterWattsKey] as? Int
        }

        if let props = smartBatteryProperties() {
            stats.cycles = props["CycleCount"] as? Int
            if let design = (props["DesignCapacity"] as? NSNumber)?.doubleValue, design > 0 {
                // Apple Silicon reports mAh in AppleRawMaxCapacity; "MaxCapacity" is only a percentage there.
                let full = (props["NominalChargeCapacity"] as? NSNumber)?.doubleValue
                    ?? (props["AppleRawMaxCapacity"] as? NSNumber)?.doubleValue
                    ?? (props["MaxCapacity"] as? NSNumber)?.doubleValue
                if let full, full > 100 { stats.healthPercent = min(full / design * 100, 100) }
            }
            if let t = (props["Temperature"] as? NSNumber)?.doubleValue, t > 0 { stats.temperature = t / 100 }
            if let mv = (props["Voltage"] as? NSNumber)?.doubleValue,
               let rawMA = (props["InstantAmperage"] as? NSNumber)?.uint64Value {
                // Discharge current is reported as a wrapped unsigned value.
                let mA = Double(Int64(bitPattern: rawMA))
                stats.watts = mv * mA / 1_000_000
            }
        }
        return stats
    }

    private static func smartBatteryProperties() -> [String: Any]? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS else { return nil }
        return props?.takeRetainedValue() as? [String: Any]
    }
}
