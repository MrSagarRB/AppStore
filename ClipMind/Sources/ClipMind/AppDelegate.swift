import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var mainWindow: NSWindow?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["maxItems": 500, "captureImages": true])
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "paperclip", accessibilityDescription: "ClipMind")
            button.target = self
            button.action = #selector(togglePopover)
        }
        popover.behavior = .transient

        ClipboardMonitor.shared.start()

        // ⌘⇧V opens the quick panel from anywhere.
        hotKey = HotKey(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey | shiftKey)) { [weak self] in
            MainActor.assumeIsolated { self?.togglePopover() }
        }

        showMainWindow()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showMainWindow()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        ClipStore.shared.saveNow()
    }

    // MARK: Quick panel

    @objc private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
            return
        }
        guard let button = statusItem.button else { return }
        // Fresh view each time so the search box is empty and focused.
        popover.contentViewController = NSHostingController(rootView: QuickView(
            store: .shared,
            close: { [weak self] in self?.popover.performClose(nil) },
            openMain: { [weak self] in self?.showMainWindow() },
            openSettings: { [weak self] in self?.showSettings() }
        ))
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
        popover.contentViewController?.view.window?.makeKey()
    }

    // MARK: Windows

    func showMainWindow() {
        popover.performClose(nil)
        if mainWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1040, height: 660),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            window.title = "ClipMind"
            let hosting = NSHostingController(rootView: MainView(store: .shared))
            hosting.sizingOptions = []   // the window, not the SwiftUI content, decides its size
            window.contentViewController = hosting
            window.minSize = NSSize(width: 820, height: 480)
            window.setContentSize(NSSize(width: 1040, height: 660))
            window.isReleasedWhenClosed = false
            window.delegate = self
            let restored = window.setFrameUsingName("ClipMindMain")
            if !restored || window.frame.width < window.minSize.width || window.frame.height < window.minSize.height {
                window.setContentSize(NSSize(width: 1040, height: 660))
                window.center()
            }
            window.setFrameAutosaveName("ClipMindMain")
            mainWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        mainWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func showSettings() {
        popover.performClose(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Back to a menu-bar-only app once the main window is gone.
        NSApp.setActivationPolicy(.accessory)
    }
}
