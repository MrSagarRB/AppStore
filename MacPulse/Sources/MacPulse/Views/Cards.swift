import SwiftUI

struct CPUCard: View {
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        let cpu = monitor.cpu
        Card(title: "CPU", symbol: "cpu", value: Format.percent(cpu.total)) {
            Sparkline(values: monitor.cpuHistory, maxValue: 1, color: loadColor(cpu.total))
                .frame(height: 44)
            HStack(spacing: 14) {
                StatRow(label: "User", value: Format.percent(cpu.user))
                StatRow(label: "System", value: Format.percent(cpu.system))
            }
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(Array(cpu.cores.enumerated()), id: \.offset) { _, load in
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 2).fill(.quaternary)
                        RoundedRectangle(cornerRadius: 2).fill(loadColor(load))
                            .frame(height: max(2, 26 * load))
                    }
                    .frame(height: 26)
                }
            }
            .help("Load per core")
        }
    }
}

struct MemoryCard: View {
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        let m = monitor.memory
        Card(title: "Memory", symbol: "memorychip", value: Format.percent(m.usedFraction)) {
            HStack {
                Text("\(Format.bytes(m.used)) of \(Format.bytes(m.total))")
                    .font(.callout).monospacedDigit()
                Spacer()
                Text("Pressure").font(.caption).foregroundStyle(.secondary)
                Pill(text: m.pressure.label, color: pressureColor(m.pressure))
            }
            breakdownBar(m)
            VStack(spacing: 4) {
                StatRow(label: "App", value: Format.bytes(m.app), tint: .blue)
                StatRow(label: "Wired", value: Format.bytes(m.wired), tint: .orange)
                StatRow(label: "Compressed", value: Format.bytes(m.compressed), tint: .purple)
                StatRow(label: "Cached files", value: Format.bytes(m.cached), tint: .gray)
                StatRow(label: "Swap used", value: Format.bytes(m.swapUsed))
            }
        }
    }

    private func breakdownBar(_ m: MemoryStats) -> some View {
        GeometryReader { geo in
            let total = max(Double(m.total), 1)
            HStack(spacing: 1) {
                segment(.blue, Double(m.app) / total, geo.size.width)
                segment(.orange, Double(m.wired) / total, geo.size.width)
                segment(.purple, Double(m.compressed) / total, geo.size.width)
                segment(.gray.opacity(0.5), Double(m.cached) / total, geo.size.width)
                Spacer(minLength: 0)
            }
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .frame(height: 10)
    }

    private func segment(_ color: Color, _ fraction: Double, _ width: CGFloat) -> some View {
        Rectangle().fill(color).frame(width: max(0, width * fraction))
    }

    private func pressureColor(_ p: MemoryPressure) -> Color {
        switch p {
        case .normal: .green
        case .warning: .orange
        case .critical: .red
        }
    }
}

struct TemperatureCard: View {
    @ObservedObject var monitor: SystemMonitor
    @AppStorage("fahrenheit") private var fahrenheit = false

    var body: some View {
        let t = monitor.thermal
        Card(title: "Temperature", symbol: "thermometer.medium",
             value: t.headline.map { Format.temperature($0, fahrenheit: fahrenheit) }) {
            if let cpu = t.cpu { StatRow(label: "CPU", value: Format.temperature(cpu, fahrenheit: fahrenheit)) }
            if let ssd = t.ssd { StatRow(label: "SSD", value: Format.temperature(ssd, fahrenheit: fahrenheit)) }
            if let battery = t.battery ?? monitor.battery.temperature {
                StatRow(label: "Battery", value: Format.temperature(battery, fahrenheit: fahrenheit))
            }
            HStack {
                Text("Thermal state").foregroundStyle(.secondary)
                Spacer()
                Pill(text: t.stateLabel, color: stateColor(t.state))
            }
            .font(.callout)
            if t.headline == nil {
                Text("Temperature sensors aren't exposed on this Mac; showing the system thermal state only.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func stateColor(_ s: ProcessInfo.ThermalState) -> Color {
        switch s {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        @unknown default: .gray
        }
    }
}

struct BatteryCard: View {
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        let b = monitor.battery
        Card(title: "Battery", symbol: b.isCharging ? "battery.100.bolt" : "battery.75", value: "\(b.percent)%") {
            ProgressView(value: Double(b.percent), total: 100)
                .tint(b.percent <= 20 && !b.onAC ? .red : .green)
            StatRow(label: "Status", value: status(b))
            if let minutes = b.minutesRemaining {
                StatRow(label: b.isCharging ? "Time to full" : "Time remaining", value: Format.duration(minutes: minutes))
            }
            if let watts = b.watts, abs(watts) >= 0.1 {
                StatRow(label: watts > 0 ? "Charging power" : "Power draw", value: String(format: "%.1f W", abs(watts)))
            }
            if let adapter = b.adapterWatts { StatRow(label: "Power adapter", value: "\(adapter) W") }
            if let health = b.healthPercent { StatRow(label: "Maximum capacity", value: "\(Int(health.rounded()))%") }
            if let cycles = b.cycles { StatRow(label: "Cycle count", value: "\(cycles)") }
        }
    }

    private func status(_ b: BatteryStats) -> String {
        if b.isCharging { return "Charging" }
        if b.isCharged { return "Fully charged" }
        return b.onAC ? "Plugged in" : "On battery"
    }
}

struct NetworkCard: View {
    @ObservedObject var monitor: SystemMonitor

    var body: some View {
        let n = monitor.network
        let ceiling = max(monitor.downHistory.max() ?? 0, monitor.upHistory.max() ?? 0, 1_000)
        Card(title: "Network", symbol: "network", value: n.interface?.uppercased()) {
            HStack(spacing: 18) {
                speedLabel("arrow.down", Format.speed(n.down), .green)
                speedLabel("arrow.up", Format.speed(n.up), .blue)
            }
            ZStack {
                Sparkline(values: monitor.downHistory, maxValue: ceiling, color: .green)
                Sparkline(values: monitor.upHistory, maxValue: ceiling, color: .blue, filled: false)
            }
            .frame(height: 44)
            StatRow(label: "Downloaded since launch", value: Format.total(n.totalDown))
            StatRow(label: "Uploaded since launch", value: Format.total(n.totalUp))
        }
    }

    private func speedLabel(_ symbol: String, _ text: String, _ color: Color) -> some View {
        Label(text, systemImage: symbol)
            .font(.callout.weight(.medium)).monospacedDigit()
            .foregroundStyle(color)
    }
}
