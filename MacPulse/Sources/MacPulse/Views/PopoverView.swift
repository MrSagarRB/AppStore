import ServiceManagement
import SwiftUI

struct PopoverView: View {
    @ObservedObject var monitor: SystemMonitor
    @State private var showingSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(showingSettings ? "Settings" : "MacPulse").font(.headline)
                Spacer()
                Button { showingSettings.toggle() } label: {
                    Image(systemName: showingSettings ? "xmark.circle.fill" : "gearshape")
                }
                .buttonStyle(.plain).foregroundStyle(.secondary)
                .help(showingSettings ? "Back" : "Settings")
                Button { NSApp.terminate(nil) } label: { Image(systemName: "power") }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                    .help("Quit MacPulse")
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            Divider()

            if showingSettings {
                SettingsPanel()
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        CPUCard(monitor: monitor)
                        MemoryCard(monitor: monitor)
                        TemperatureCard(monitor: monitor)
                        if monitor.battery.present { BatteryCard(monitor: monitor) }
                        NetworkCard(monitor: monitor)
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 340, height: 660)
    }
}

struct SettingsPanel: View {
    @AppStorage("showCPU") private var showCPU = true
    @AppStorage("showMemory") private var showMemory = true
    @AppStorage("showTemperature") private var showTemperature = true
    @AppStorage("showBattery") private var showBattery = true
    @AppStorage("showNetwork") private var showNetwork = true
    @AppStorage("interval") private var interval = 2.0
    @AppStorage("fahrenheit") private var fahrenheit = false
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Show in menu bar") {
                Toggle("CPU usage", isOn: $showCPU)
                Toggle("Memory usage", isOn: $showMemory)
                Toggle("Temperature", isOn: $showTemperature)
                Toggle("Battery", isOn: $showBattery)
                Toggle("Network speed", isOn: $showNetwork)
            }
            Section("General") {
                Picker("Update every", selection: $interval) {
                    Text("1 second").tag(1.0)
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                }
                Picker("Temperature unit", selection: $fahrenheit) {
                    Text("Celsius").tag(false)
                    Text("Fahrenheit").tag(true)
                }
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in updateLogin(on) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
            }
        }
        .formStyle(.grouped)
    }

    private func updateLogin(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Couldn't change login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
