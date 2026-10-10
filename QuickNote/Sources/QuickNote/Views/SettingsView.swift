import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultColor") private var defaultColor = NoteColor.yellow.rawValue
    @AppStorage("defaultFont") private var defaultFont = NoteFont.bold.rawValue
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Form {
                Section("New notes") {
                    HStack {
                        Text("Color")
                        Spacer()
                        ForEach(NoteColor.allCases) { c in
                            Circle().fill(c.background).frame(width: 20, height: 20)
                                .overlay(Circle().strokeBorder(.secondary.opacity(0.5), lineWidth: 0.8))
                                .overlay(Circle().strokeBorder(Color.accentColor, lineWidth: defaultColor == c.rawValue ? 2.5 : 0).padding(-3))
                                .onTapGesture { defaultColor = c.rawValue }
                                .help(c.label)
                        }
                    }
                    Picker("Font", selection: $defaultFont) {
                        ForEach(NoteFont.allCases) { Text($0.label).tag($0.rawValue) }
                    }
                }
                Section("General") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { _, on in updateLogin(on) }
                    if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                }
                Section("Shortcuts") {
                    LabeledContent("New note", value: "⌃⌥N")
                    LabeledContent("Hide / show all notes", value: "⌃⌥H")
                    LabeledContent("Close the focused note", value: "⌘W")
                }
                Section("Privacy") {
                    Text("Notes are stored only on this Mac, in ~/Library/Application Support/QuickNote.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            Divider()
            HStack { Spacer(); Button("Done") { dismiss() }.keyboardShortcut(.defaultAction) }.padding(12)
        }
        .frame(width: 440, height: 520)
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
