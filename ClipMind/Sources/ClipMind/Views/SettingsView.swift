import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = ClipStore.shared
    @AppStorage("maxItems") private var maxItems = 500
    @AppStorage("captureImages") private var captureImages = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section("History") {
                Picker("Keep up to", selection: $maxItems) {
                    ForEach([100, 250, 500, 1000, 5000], id: \.self) { Text("\($0) clips").tag($0) }
                }
                Toggle("Capture images", isOn: $captureImages)
                Text("Pinned clips and clips in folders are never removed by the history limit.")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Clear History…", role: .destructive) { confirmClear = true }
            }
            Section("General") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in updateLogin(on) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                LabeledContent("Quick panel shortcut", value: "⌘⇧V")
            }
            Section("Privacy") {
                Text("Clips are stored only on this Mac in ~/Library/Application Support/ClipMind. Items flagged as concealed by password managers are never recorded.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 420)
        .confirmationDialog("Clear all unpinned clips?", isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { store.clearHistory() }
        } message: {
            Text("Pinned clips and clips in folders are kept.")
        }
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
