import Foundation

// Apple Silicon exposes its thermal sensors only through IOKit's private HID event system.
// These are the same entry points used by other system monitors; they need no entitlements,
// but the app cannot be sandboxed (so it can't go on the Mac App Store as-is).
@_silgen_name("IOHIDEventSystemClientCreate")
private func IOHIDEventSystemClientCreate(_ allocator: CFAllocator?) -> UnsafeRawPointer?
@_silgen_name("IOHIDEventSystemClientSetMatching")
private func IOHIDEventSystemClientSetMatching(_ client: UnsafeRawPointer, _ matching: CFDictionary) -> Int32
@_silgen_name("IOHIDEventSystemClientCopyServices")
private func IOHIDEventSystemClientCopyServices(_ client: UnsafeRawPointer) -> Unmanaged<CFArray>?
@_silgen_name("IOHIDServiceClientCopyProperty")
private func IOHIDServiceClientCopyProperty(_ service: UnsafeRawPointer, _ key: CFString) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOHIDServiceClientCopyEvent")
private func IOHIDServiceClientCopyEvent(_ service: UnsafeRawPointer, _ type: Int64, _ options: Int32, _ timestamp: Int64) -> UnsafeRawPointer?
@_silgen_name("IOHIDEventGetFloatValue")
private func IOHIDEventGetFloatValue(_ event: UnsafeRawPointer, _ field: Int32) -> Double

final class ThermalProbe {
    private enum Role { case cpu, battery, ssd }

    private var client: UnsafeRawPointer?
    private var serviceList: CFArray?
    private var sensors: [(service: UnsafeRawPointer, role: Role)] = []

    private static let temperatureEventType: Int64 = 15
    private static let temperatureField: Int32 = 15 << 16

    init() {
        guard let client = IOHIDEventSystemClientCreate(kCFAllocatorDefault) else { return }
        self.client = client
        let match: [String: Any] = ["PrimaryUsagePage": 0xff00, "PrimaryUsage": 5]
        _ = IOHIDEventSystemClientSetMatching(client, match as CFDictionary)
        guard let list = IOHIDEventSystemClientCopyServices(client)?.takeRetainedValue() else { return }
        serviceList = list

        for i in 0..<CFArrayGetCount(list) {
            guard let service = CFArrayGetValueAtIndex(list, i),
                  let name = IOHIDServiceClientCopyProperty(service, "Product" as CFString)?.takeRetainedValue() as? String
            else { continue }
            if name.contains("tdie") || name.contains("ACC MTR Temp") {
                sensors.append((service, .cpu))
            } else if name.contains("NAND") {
                sensors.append((service, .ssd))
            } else if name.localizedCaseInsensitiveContains("battery") {
                sensors.append((service, .battery))
            }
        }
    }

    func read() -> ThermalStats {
        var stats = ThermalStats()
        stats.state = ProcessInfo.processInfo.thermalState

        var readings: [Role: [Double]] = [:]
        for (service, role) in sensors {
            guard let event = IOHIDServiceClientCopyEvent(service, Self.temperatureEventType, 0, 0) else { continue }
            let value = IOHIDEventGetFloatValue(event, Self.temperatureField)
            Unmanaged<AnyObject>.fromOpaque(event).release()
            if value > 0, value < 150 { readings[role, default: []].append(value) }
        }
        stats.cpu = readings[.cpu]?.max()
        stats.ssd = readings[.ssd]?.max()
        stats.battery = readings[.battery]?.max()
        return stats
    }
}
