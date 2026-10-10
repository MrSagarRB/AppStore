import AppKit
import Carbon.HIToolbox
import ServiceManagement
import SwiftData
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let store = NoteStore.shared
    private let manager = NoteWindowManager.shared
    private var statusItem: NSStatusItem!
    private var libraryWindow: NSWindow?
    private var sweepTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: ["defaultColor": NoteColor.yellow.rawValue, "defaultFont": NoteFont.bold.rawValue])
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "note.text", accessibilityDescription: "QuickNote")
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        HotKeyCenter.shared.register(id: 1, keyCode: kVK_ANSI_N, modifiers: controlKey | optionKey) { [weak self] in
            self?.manager.newNote()
        }
        HotKeyCenter.shared.register(id: 2, keyCode: kVK_ANSI_H, modifiers: controlKey | optionKey) { [weak self] in
            self?.manager.toggleAllHidden()
        }

        if NoteStore.isDemo { seedDemoNotes() }
        manager.restoreOpenNotes()
        sweep()
        let timer = Timer(timeInterval: 15, repeats: true) { [weak self] _ in Task { @MainActor in self?.sweep() } }
        RunLoop.main.add(timer, forMode: .common)
        sweepTimer = timer

        // Debug aids: `--new-note` opens a note straight away, `--library` opens the All Notes window.
        if CommandLine.arguments.contains("--new-note") { manager.newNote(text: "Hello from QuickNote") }
        if CommandLine.arguments.contains("--library") { showLibrary() }
        if CommandLine.arguments.contains("--test-timers") { seedTimerTest() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLibrary()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) { store.save() }

    // MARK: Reminders and temporary notes

    /// Deletes notes whose auto-delete time has passed and pops up notes whose reminder is due.
    private func sweep() {
        let now = Date()
        for note in store.allNotes() {
            if let expires = note.expiresAt, expires <= now {
                manager.delete(note)
            } else if let reminder = note.reminderAt, reminder <= now {
                note.reminderAt = nil
                manager.flash(note)
            }
        }
        store.save()   // belt and braces: SwiftData autosaves, but a kill -9 shouldn't lose typing
    }

    // MARK: Menu bar

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        add(menu, "New Note", #selector(newNote), key: "n", mods: [.control, .option])
        add(menu, manager.allHidden ? "Show All Notes on Desktop" : "Hide All Notes", #selector(toggleHidden), key: "h", mods: [.control, .option])

        let recent = Array(store.allNotes().prefix(8))
        if !recent.isEmpty {
            menu.addItem(.separator())
            let header = NSMenuItem(title: "Recent Notes", action: nil, keyEquivalent: "")
            header.isEnabled = false
            menu.addItem(header)
            for note in recent {
                let item = NSMenuItem(title: note.title, action: #selector(openNote(_:)), keyEquivalent: "")
                item.target = self
                item.representedObject = note.id
                item.state = manager.isOnScreen(note) ? .on : .off
                menu.addItem(item)
            }
        }
        menu.addItem(.separator())
        add(menu, "All Notes…", #selector(showLibraryAction), key: "")
        let login = add(menu, "Launch at Login", #selector(toggleLogin), key: "")
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit QuickNote", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    @discardableResult
    private func add(_ menu: NSMenu, _ title: String, _ action: Selector, key: String, mods: NSEvent.ModifierFlags = []) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.keyEquivalentModifierMask = mods
        item.target = self
        menu.addItem(item)
        return item
    }

    @objc private func newNote() { manager.newNote() }
    @objc private func toggleHidden() { manager.toggleAllHidden() }
    @objc private func showLibraryAction() { showLibrary() }

    @objc private func openNote(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? UUID, let note = store.note(id: id) { manager.open(note) }
    }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled { try SMAppService.mainApp.unregister() }
            else { try SMAppService.mainApp.register() }
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change the login item"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    // MARK: All Notes window

    func showLibrary() {
        if libraryWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 760, height: 540),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "QuickNote — All Notes"
            let hosting = NSHostingController(rootView: LibraryView().modelContainer(store.container))
            hosting.sizingOptions = []
            window.contentViewController = hosting
            window.setContentSize(NSSize(width: 760, height: 540))
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            libraryWindow = window
        }
        NSApp.setActivationPolicy(.regular)
        libraryWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)   // back to menu-bar-only; floating notes stay put
    }

    // MARK: Demo data

    /// `--test-timers`: a closed note whose reminder is due in 2 s, and a wide open note that expires in 2 s.
    private func seedTimerTest() {
        let reminder = store.makeNote(text: "Reminder fired!")
        reminder.reminderAt = Date().addingTimeInterval(2)
        let expiring = store.makeNote(text: "I should vanish")
        expiring.width = 300
        let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        expiring.originX = area.midX; expiring.originY = area.midY
        expiring.expiresAt = Date().addingTimeInterval(2)
        manager.open(expiring)
    }

    /// Three notes laid out like the product shot, plus a few more for the All Notes window.
    private func seedDemoNotes() {
        let area = (NSScreen.main ?? NSScreen.screens[0]).visibleFrame
        func place(_ note: Note, x: Double, top: Double, w: Double = 220, h: Double = 220) {
            note.width = w; note.height = h
            note.originX = area.minX + area.width * x
            note.originY = area.maxY - area.height * top - h
            note.isOpen = true
        }
        let avocado = store.makeNote(text: "Remember to buy avocados 🥑")
        place(avocado, x: 0.25, top: 0.27)
        let room = store.makeNote(text: "Room number: 432")
        room.color = .charcoal
        place(room, x: 0.5165, top: 0.215)
        let focus = store.makeNote(text: "Focus on positivity")
        focus.color = .pink; focus.font = .handwritten
        place(focus, x: 0.42, top: 0.518, w: 460)

        let call = store.makeNote(text: "Call the dentist — Tuesday 3 pm")
        call.color = .blue; call.reminderAt = Date().addingTimeInterval(86_400)
        let wifi = store.makeNote(text: "Guest wifi: maple-4821")
        wifi.color = .green; wifi.expiresAt = Date().addingTimeInterval(3_600 * 5)
        let git = store.makeNote(text: "git rebase -i HEAD~3")
        git.color = .purple; git.font = .mono
        let idea = store.makeNote(text: "Idea: weekly review every Friday at 5")
        idea.color = .orange; idea.font = .serif
        store.save()
    }
}
