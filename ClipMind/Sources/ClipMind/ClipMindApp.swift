import SwiftUI

@main
struct ClipMindApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings { SettingsView() }
    }
}
