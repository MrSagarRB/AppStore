import SwiftUI

@main
struct QuickNoteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Everything lives in floating notes, the menu bar and the All Notes window.
        Settings { EmptyView() }
    }
}
