import AppKit
import SwiftUI

/// Reports mouse enter/exit even while the window isn't key (plain `onHover` only works for key windows).
struct HoverTracker: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) { view.onChange = onChange }

    final class TrackingView: NSView {
        var onChange: ((Bool) -> Void)?

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            trackingAreas.forEach(removeTrackingArea)
            addTrackingArea(NSTrackingArea(rect: .zero,
                                           options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                           owner: self))
        }

        override func mouseEntered(with event: NSEvent) { onChange?(true) }
        override func mouseExited(with event: NSEvent) { onChange?(false) }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }   // never swallow clicks
    }
}

/// Tells SwiftUI whether *its own* window is currently the key window.
struct KeyWindowTracker: NSViewRepresentable {
    let onChange: (Bool) -> Void

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.onChange = onChange
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) { view.onChange = onChange }

    final class TrackingView: NSView {
        var onChange: ((Bool) -> Void)?
        private var tokens: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens = []
            guard let window else { return }
            let center = NotificationCenter.default
            tokens = [
                center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in self?.onChange?(true) },
                center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in self?.onChange?(false) },
            ]
            onChange?(window.isKeyWindow)
        }

        deinit { tokens.forEach(NotificationCenter.default.removeObserver) }
        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}

/// An invisible strip that drags the whole note window. (The text editor fills the note,
/// so without a dedicated handle there would be nowhere to grab it.)
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { true }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
}

/// Bottom-right corner grip that resizes the note.
struct ResizeGrip: NSViewRepresentable {
    func makeNSView(context: Context) -> GripView { GripView() }
    func updateNSView(_ view: GripView, context: Context) {}

    final class GripView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            let startMouse = NSEvent.mouseLocation
            let startFrame = window.frame
            window.trackEvents(matching: [.leftMouseDragged, .leftMouseUp], timeout: .infinity, mode: .eventTracking) { next, stop in
                guard let next else { return }
                if next.type == .leftMouseUp { stop.pointee = true; return }
                let mouse = NSEvent.mouseLocation
                let width = min(max(startFrame.width + (mouse.x - startMouse.x), window.minSize.width), window.maxSize.width)
                let height = min(max(startFrame.height - (mouse.y - startMouse.y), window.minSize.height), window.maxSize.height)
                window.setFrame(NSRect(x: startFrame.minX, y: startFrame.maxY - height, width: width, height: height), display: true)
            }
        }
    }
}

struct GripShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        for inset in [CGFloat(0.35), 0.7] {
            path.move(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * inset))
            path.addLine(to: CGPoint(x: rect.minX + rect.width * inset, y: rect.maxY))
        }
        return path
    }
}

struct NoteView: View {
    @Bindable var note: Note
    let onClose: () -> Void
    let onDelete: () -> Void
    let onLevelChange: (Bool) -> Void

    @State private var hovering = false
    @State private var isKey = false
    @State private var showReminder = false
    @State private var pulse = false

    private var showControls: Bool { hovering || isKey }
    private var ink: Color { note.color.textColor }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous).fill(note.color.background)

            NoteTextView(text: Binding(get: { note.text },
                                       set: { note.text = $0; note.updatedAt = Date() }),
                         font: note.font, textColor: note.color.nsTextColor)

            if note.text.isEmpty {
                Text("New note…")
                    .font(note.font.font(size: 24))
                    .foregroundStyle(ink.opacity(0.35))
                    .allowsHitTesting(false)
            }

            VStack {
                topBar
                Spacer(minLength: 0)
                Group { if showControls { colorBar } else { statusLine } }
                    .frame(maxWidth: .infinity, minHeight: 26)
                    .background(WindowDragHandle().padding(.horizontal, -10).padding(.bottom, -10).padding(.top, -2))
            }
            .padding(10)
            .opacity(showControls || hasStatus ? 1 : 0)

            if showControls {
                ResizeGrip()
                    .frame(width: 22, height: 22)
                    .overlay(GripShape().stroke(ink.opacity(0.45), lineWidth: 1.6).padding(6).allowsHitTesting(false))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(3)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .strokeBorder(ink.opacity(note.color.isDark ? 0.18 : 0.08), lineWidth: 1))
        .background(HoverTracker { hovering = $0 })
        .background(KeyWindowTracker { isKey = $0 })
        .scaleEffect(pulse ? 1.06 : 1)
        .onReceive(NotificationCenter.default.publisher(for: .noteReminderFired)) { n in
            if n.object as? UUID == note.id { ring() }
        }
    }

    // MARK: Controls

    private var hasStatus: Bool { note.reminderAt != nil || note.expiresAt != nil }

    private var topBar: some View {
        HStack(spacing: 6) {
            iconButton("xmark", help: "Close (⌘W). The note is saved.") { onClose() }
            Spacer()
            if showControls {
                Button { showReminder = true } label: { icon(note.reminderAt == nil ? "bell" : "bell.fill") }
                    .buttonStyle(.plain)
                    .help("Remind me")
                    .popover(isPresented: $showReminder, arrowEdge: .bottom) { ReminderPopover(note: note) }
                fontMenu
                moreMenu
            }
        }
        .frame(height: 24)
        .background(WindowDragHandle().padding(.horizontal, -10).padding(.top, -10).padding(.bottom, -8))
        .opacity(showControls ? 1 : 0)
    }

    private var fontMenu: some View {
        Menu {
            ForEach(NoteFont.allCases) { f in
                Button { note.font = f } label: {
                    if f == note.font { Label(f.label, systemImage: "checkmark") } else { Text(f.label) }
                }
            }
        } label: { icon("textformat") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
            .help("Font")
    }

    private var moreMenu: some View {
        Menu {
            Button("Copy Text") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(note.text, forType: .string)
            }
            Button { note.floatsAboveWindows.toggle(); onLevelChange(note.floatsAboveWindows) } label: {
                if note.floatsAboveWindows { Label("Float Above Windows", systemImage: "checkmark") }
                else { Text("Float Above Windows") }
            }
            Menu("Auto-delete") {
                Button("Keep Forever") { note.expiresAt = nil }
                Button("After 1 Hour") { note.expiresAt = Date().addingTimeInterval(3_600) }
                Button("After 1 Day") { note.expiresAt = Date().addingTimeInterval(86_400) }
                Button("After 1 Week") { note.expiresAt = Date().addingTimeInterval(604_800) }
            }
            Divider()
            Button("Delete Note", role: .destructive, action: onDelete)
        } label: { icon("ellipsis") }
            .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
    }

    private var colorBar: some View {
        HStack(spacing: 7) {
            ForEach(NoteColor.allCases) { c in
                Circle()
                    .fill(c.background)
                    .frame(width: 17, height: 17)
                    .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 0.8))
                    .overlay(Circle().strokeBorder(ink, lineWidth: c == note.color ? 2 : 0).padding(-3))
                    .contentShape(Circle())
                    .onTapGesture { note.color = c }
                    .help(c.label)
            }
        }
        .padding(.bottom, 2)
    }

    private var statusLine: some View {
        HStack(spacing: 8) {
            if let r = note.reminderAt {
                Label(r.formatted(date: .abbreviated, time: .shortened), systemImage: "bell.fill")
            }
            if let e = note.expiresAt {
                Label(e.formatted(.relative(presentation: .named)), systemImage: "hourglass")
            }
        }
        .font(.system(size: 10, weight: .semibold))
        .foregroundStyle(ink.opacity(0.55))
        .labelStyle(.titleAndIcon)
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(ink.opacity(0.6))
            .frame(width: 22, height: 22)
            .background(Circle().fill(ink.opacity(0.08)))
            .contentShape(Circle())
    }

    private func iconButton(_ name: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { icon(name) }.buttonStyle(.plain).help(help)
    }

    // MARK: State

    private func ring() {
        NSSound(named: "Glass")?.play()
        withAnimation(.easeInOut(duration: 0.25).repeatCount(6, autoreverses: true)) { pulse = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { pulse = false }
    }
}

struct ReminderPopover: View {
    @Bindable var note: Note
    @State private var custom = Date().addingTimeInterval(3_600)
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Remind me").font(.headline)
            preset("In 10 minutes", seconds: 600)
            preset("In 30 minutes", seconds: 1_800)
            preset("In 1 hour", seconds: 3_600)
            preset("In 3 hours", seconds: 10_800)
            Button("Tomorrow, 9:00 AM") { set(tomorrowMorning()) }
            Divider()
            DatePicker("Pick a time", selection: $custom, in: Date()...)
                .datePickerStyle(.field)
                .labelsHidden()
            Button("Set for this time") { set(custom) }
            if let r = note.reminderAt {
                Divider()
                Text("Set for \(r.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
                Button("Clear Reminder", role: .destructive) { note.reminderAt = nil; dismiss() }
            }
        }
        .padding(14)
        .frame(width: 210, alignment: .leading)
    }

    private func preset(_ title: String, seconds: TimeInterval) -> some View {
        Button(title) { set(Date().addingTimeInterval(seconds)) }
    }

    private func set(_ date: Date) {
        note.reminderAt = date
        note.updatedAt = Date()
        dismiss()
    }

    private func tomorrowMorning() -> Date {
        let cal = Calendar.current
        let tomorrow = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: Date())) ?? Date()
        return cal.date(byAdding: .hour, value: 9, to: tomorrow) ?? tomorrow
    }
}
