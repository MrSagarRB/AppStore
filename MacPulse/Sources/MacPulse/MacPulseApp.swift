import SwiftUI

@main
struct MacPulseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        // Everything lives in the menu bar popover; this scene only satisfies SwiftUI.
        Settings { EmptyView() }
    }
}
