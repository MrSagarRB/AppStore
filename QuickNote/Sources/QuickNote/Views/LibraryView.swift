import SwiftData
import SwiftUI

/// "All Notes": every saved note, searchable. Click one to float it back onto the desktop.
struct LibraryView: View {
    @Query(sort: \Note.updatedAt, order: .reverse) private var notes: [Note]

    @State private var query = ""
    @State private var filter = Filter.all
    @State private var showSettings = false

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All", desktop = "On Desktop", reminders = "Reminders", temporary = "Temporary"
        var id: String { rawValue }
    }

    private var visible: [Note] {
        notes.filter { note in
            switch filter {
            case .all: true
            case .desktop: note.isOpen
            case .reminders: note.reminderAt != nil
            case .temporary: note.expiresAt != nil
            }
        }
        .filter { query.isEmpty || $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if visible.isEmpty {
                empty
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170, maximum: 220), spacing: 16)], spacing: 16) {
                        ForEach(visible) { note in NoteCard(note: note) }
                    }
                    .padding(20)
                }
            }
        }
        .frame(minWidth: 560, minHeight: 420)
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search notes", text: $query).textFieldStyle(.plain)
                if !query.isEmpty {
                    Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                        .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))

            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).labelsHidden().fixedSize()

            Spacer()
            Button { showSettings = true } label: { Image(systemName: "gearshape") }.help("Settings")
            Button { NoteWindowManager.shared.newNote() } label: { Label("New Note", systemImage: "plus") }
                .buttonStyle(.borderedProminent)
                .help("New note (⌃⌥N from anywhere)")
        }
        .padding(12)
    }

    @ViewBuilder
    private var empty: some View {
        if !query.isEmpty {
            ContentUnavailableView.search(text: query)
        } else if filter != .all {
            ContentUnavailableView("Nothing Here", systemImage: "tray", description: Text("No notes match this filter."))
        } else {
            ContentUnavailableView("No Notes Yet", systemImage: "note.text",
                                   description: Text("Press ⌃⌥N anywhere to jot something down."))
        }
    }
}

struct NoteCard: View {
    @Bindable var note: Note

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(note.text.isEmpty ? "Empty note" : note.text)
                .font(note.font.font(size: 15))
                .foregroundStyle(note.color.textColor)
                .lineLimit(6)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                if note.isOpen { Image(systemName: "pin.fill").help("On your desktop") }
                if note.reminderAt != nil { Image(systemName: "bell.fill").help("Has a reminder") }
                if note.expiresAt != nil { Image(systemName: "hourglass").help("Deletes itself") }
                Spacer()
                Text(note.updatedAt.formatted(.relative(presentation: .named)))
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(note.color.textColor.opacity(0.55))
        }
        .padding(14)
        .frame(height: 150)
        .background(note.color.background, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(note.color.textColor.opacity(note.color.isDark ? 0.2 : 0.08)))
        .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture { NoteWindowManager.shared.open(note) }
        .contextMenu {
            Button(note.isOpen ? "Bring to Front" : "Open on Desktop") { NoteWindowManager.shared.open(note) }
            if note.isOpen { Button("Close") { NoteWindowManager.shared.close(note) } }
            Button("Copy Text") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(note.text, forType: .string)
            }
            Divider()
            Button("Delete", role: .destructive) { NoteWindowManager.shared.delete(note) }
        }
    }
}
