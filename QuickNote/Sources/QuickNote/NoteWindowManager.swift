import AppKit
import SwiftUI

/// A borderless sticky-note window. It is a non-activating panel, so you can type into it
/// while the app you were using stays frontmost.
final class NotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    var onClose: (() -> Void)?
    var onNewNote: (() -> Void)?

    /// An inactive app has no live menu, so route the common editing shortcuts by hand.
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask).contains(.command),
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        let shift = event.modifierFlags.contains(.shift)
        switch key {
        case "c": return NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: self)
        case "x": return NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: self)
        case "v": return NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: self)
        case "a": return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
        case "z": return NSApp.sendAction(Selector(shift ? "redo:" : "undo:"), to: nil, from: self)
        case "w": onClose?(); return true
        case "n": onNewNote?(); return true
        default: return super.performKeyEquivalent(with: event)
        }
    }

    func focusText() {
        if let textView = contentView?.firstDescendant(ofType: NSTextView.self) { makeFirstResponder(textView) }
    }
}

extension NSView {
    func firstDescendant<T: NSView>(ofType type: T.Type) -> T? {
        if let match = self as? T { return match }
        for sub in subviews { if let found = sub.firstDescendant(ofType: type) { return found } }
        return nil
    }
}

@MainActor
final class NoteWindowManager {
    static let shared = NoteWindowManager()

    private let store = NoteStore.shared
    private var panels: [UUID: NotePanel] = [:]
    private var observers: [UUID: [NSObjectProtocol]] = [:]
    private(set) var allHidden = false

    func isOnScreen(_ note: Note) -> Bool { panels[note.id] != nil }

    // MARK: Opening and closing

    func restoreOpenNotes() {
        for note in store.allNotes() where note.isOpen { show(note, focus: false) }
    }

    @discardableResult
    func newNote(text: String = "") -> Note {
        let note = store.makeNote(text: text)
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let area = screen?.visibleFrame {
            let jitter = { Double.random(in: -50...50) }
            note.originX = area.midX - note.width / 2 + jitter()
            note.originY = area.midY - note.height / 2 + jitter()
        }
        note.isOpen = true
        if allHidden { toggleAllHidden() }
        show(note, focus: true)
        store.save()
        return note
    }

    func open(_ note: Note) {
        note.isOpen = true
        if allHidden { toggleAllHidden() }
        show(note, focus: true)
        store.save()
    }

    /// Hides the window but keeps the note. Empty notes aren't worth keeping, so those are deleted.
    func close(_ note: Note) {
        teardown(note.id)
        if note.isEmpty { store.delete(note) } else { note.isOpen = false; store.save() }
    }

    func delete(_ note: Note) {
        teardown(note.id)
        store.delete(note)
    }

    func closeEverything() {
        for panel in Array(panels.values) { panel.orderOut(nil) }
    }

    func toggleAllHidden() {
        allHidden.toggle()
        for panel in panels.values {
            if allHidden { panel.orderOut(nil) } else { panel.orderFrontRegardless() }
        }
    }

    /// Brings a note up for a reminder without stealing keyboard focus from whatever you're typing in.
    func flash(_ note: Note) {
        note.isOpen = true
        if allHidden { toggleAllHidden() }
        show(note, focus: false)
        store.save()
        NotificationCenter.default.post(name: .noteReminderFired, object: note.id)
    }

    // MARK: Window plumbing

    private func show(_ note: Note, focus: Bool) {
        if let existing = panels[note.id] {
            existing.orderFrontRegardless()
            if focus { existing.makeKey(); existing.focusText() }
            return
        }
        let panel = makePanel(for: note)
        panels[note.id] = panel
        panel.orderFrontRegardless()
        if focus {
            panel.makeKey()
            DispatchQueue.main.async { panel.focusText() }
        }
    }

    private func makePanel(for note: Note) -> NotePanel {
        let panel = NotePanel(contentRect: restoredFrame(for: note),
                              styleMask: [.borderless, .nonactivatingPanel, .resizable],
                              backing: .buffered, defer: false)
        panel.isFloatingPanel = note.floatsAboveWindows
        panel.level = note.floatsAboveWindows ? .floating : .normal
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.minSize = NSSize(width: 170, height: 150)
        panel.maxSize = NSSize(width: 700, height: 700)
        panel.onClose = { [weak self] in self?.close(note) }
        panel.onNewNote = { [weak self] in self?.newNote() }

        let view = NoteView(note: note,
                            onClose: { [weak self] in self?.close(note) },
                            onDelete: { [weak self] in self?.delete(note) },
                            onLevelChange: { [weak panel] floating in
                                panel?.isFloatingPanel = floating
                                panel?.level = floating ? .floating : .normal
                            })
        panel.contentView = NSHostingView(rootView: view)

        let center = NotificationCenter.default
        let id = note.id
        let remember: (Notification) -> Void = { [weak panel, weak note] _ in
            guard let panel, let note else { return }
            note.originX = panel.frame.origin.x
            note.originY = panel.frame.origin.y
            note.width = panel.frame.width
            note.height = panel.frame.height
        }
        observers[id] = [
            center.addObserver(forName: NSWindow.didMoveNotification, object: panel, queue: .main, using: remember),
            center.addObserver(forName: NSWindow.didResizeNotification, object: panel, queue: .main, using: remember),
        ]
        return panel
    }

    private func teardown(_ id: UUID) {
        for token in observers[id] ?? [] { NotificationCenter.default.removeObserver(token) }
        observers[id] = nil
        panels[id]?.orderOut(nil)
        panels[id]?.contentView = nil
        panels[id] = nil
    }

    /// Reopens a note where it was left, unless that spot is no longer on any screen.
    private func restoredFrame(for note: Note) -> NSRect {
        let frame = NSRect(x: note.originX, y: note.originY, width: note.width, height: note.height)
        if NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame) }) { return frame }
        let area = NSScreen.main?.visibleFrame ?? NSRect(x: 100, y: 100, width: 800, height: 600)
        return NSRect(x: area.midX - note.width / 2, y: area.midY - note.height / 2, width: note.width, height: note.height)
    }
}
