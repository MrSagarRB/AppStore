import Foundation

/// Samples every probe on a timer and keeps a short history for the sparklines.
@MainActor
final class SystemMonitor: ObservableObject {
    static let shared = SystemMonitor()
    static let historyLength = 60

    @Published private(set) var cpu = CPUStats()
    @Published private(set) var memory = MemoryStats()
    @Published private(set) var thermal = ThermalStats()
    @Published private(set) var battery = BatteryStats()
    @Published private(set) var network = NetworkStats()
    @Published private(set) var cpuHistory: [Double] = []
    @Published private(set) var downHistory: [Double] = []
    @Published private(set) var upHistory: [Double] = []

    /// Called after every sample so the menu bar title can refresh.
    var onUpdate: (() -> Void)?

    private let cpuProbe = CPUProbe()
    private let networkProbe = NetworkProbe()
    private let thermalProbe = ThermalProbe()
    private var timer: Timer?
    private var scheduledInterval = 0.0

    var interval: TimeInterval {
        let v = UserDefaults.standard.double(forKey: "interval")
        return v > 0 ? v : 2
    }

    func start() {
        _ = cpuProbe.sample()        // prime the tick/byte deltas
        _ = networkProbe.sample()
        schedule()
        sample()
    }

    /// Re-arms the timer only if the interval setting actually changed.
    func rescheduleIfNeeded() {
        if interval != scheduledInterval { schedule() }
    }

    private func schedule() {
        timer?.invalidate()
        scheduledInterval = interval
        let t = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sample() }
        }
        RunLoop.main.add(t, forMode: .common)   // keep ticking while a menu is open
        timer = t
    }

    private func sample() {
        cpu = cpuProbe.sample()
        memory = MemoryProbe.read()
        thermal = thermalProbe.read()
        battery = BatteryProbe.read()
        network = networkProbe.sample()

        cpuHistory = Self.appending(cpuHistory, cpu.total)
        downHistory = Self.appending(downHistory, network.down)
        upHistory = Self.appending(upHistory, network.up)
        onUpdate?()
    }

    private static func appending(_ array: [Double], _ value: Double) -> [Double] {
        Array((array + [value]).suffix(historyLength))
    }
}
