import AppKit
import SwiftData

/// Owns the SwiftData container. Everything saves automatically; nothing here needs an explicit "Save".
@MainActor
final class NoteStore {
    static let shared = NoteStore()

    /// `--demo` (and `--test-timers`) keep everything in memory so they never touch real notes.
    static let isDemo = CommandLine.arguments.contains("--demo")
    static let usesMemoryStore = isDemo || CommandLine.arguments.contains("--test-timers")

    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    private init() {
        let configuration: ModelConfiguration
        if Self.usesMemoryStore {
            configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        } else {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("QuickNote", isDirectory: true)
            try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            configuration = ModelConfiguration(url: support.appendingPathComponent("QuickNote.store"))
        }
        do {
            container = try ModelContainer(for: Note.self, configurations: configuration)
        } catch {
            fatalError("QuickNote could not open its note store: \(error)")
        }
    }

    func allNotes() -> [Note] {
        (try? context.fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? []
    }

    func note(id: UUID) -> Note? {
        let descriptor = FetchDescriptor<Note>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    func makeNote(text: String = "") -> Note {
        let defaults = UserDefaults.standard
        let note = Note(text: text,
                        color: NoteColor(rawValue: defaults.string(forKey: "defaultColor") ?? "") ?? .yellow,
                        font: NoteFont(rawValue: defaults.string(forKey: "defaultFont") ?? "") ?? .bold)
        context.insert(note)
        return note
    }

    func delete(_ note: Note) {
        context.delete(note)
        save()
    }

    func save() { try? context.save() }
}
