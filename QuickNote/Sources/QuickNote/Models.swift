import AppKit
import SwiftData
import SwiftUI

enum NoteColor: String, CaseIterable, Identifiable {
    case yellow, pink, blue, green, orange, purple, charcoal

    var id: String { rawValue }
    var label: String { rawValue.capitalized }

    private var rgb: (Double, Double, Double) {
        switch self {
        case .yellow: (1.00, 0.98, 0.65)
        case .pink: (0.96, 0.72, 0.85)
        case .blue: (0.70, 0.86, 1.00)
        case .green: (0.73, 0.95, 0.78)
        case .orange: (1.00, 0.83, 0.62)
        case .purple: (0.83, 0.77, 1.00)
        case .charcoal: (0.11, 0.11, 0.12)
        }
    }

    var background: Color { Color(red: rgb.0, green: rgb.1, blue: rgb.2) }
    var isDark: Bool { self == .charcoal }
    var nsTextColor: NSColor { isDark ? NSColor(white: 0.94, alpha: 1) : NSColor(white: 0.07, alpha: 1) }
    var textColor: Color { Color(nsColor: nsTextColor) }
}

enum NoteFont: String, CaseIterable, Identifiable {
    case bold, handwritten, serif, mono

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bold: "Bold"
        case .handwritten: "Handwritten"
        case .serif: "Serif"
        case .mono: "Typewriter"
        }
    }

    func nsFont(size: CGFloat) -> NSFont {
        switch self {
        case .bold:
            let base = NSFont.systemFont(ofSize: size, weight: .bold)
            return base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: size) } ?? base
        case .handwritten:
            return NSFont(name: "Noteworthy-Bold", size: size)
                ?? NSFont(name: "BradleyHandITCTT-Bold", size: size)
                ?? NSFont.systemFont(ofSize: size, weight: .semibold)
        case .serif:
            let base = NSFont.systemFont(ofSize: size, weight: .semibold)
            return base.fontDescriptor.withDesign(.serif).flatMap { NSFont(descriptor: $0, size: size) } ?? base
        case .mono:
            return NSFont.monospacedSystemFont(ofSize: size, weight: .semibold)
        }
    }

    func font(size: CGFloat) -> Font { Font(nsFont(size: size)) }
}

@Model
final class Note {
    @Attribute(.unique) var id: UUID
    var text: String
    var colorRaw: String
    var fontRaw: String
    var createdAt: Date
    var updatedAt: Date
    var originX: Double
    var originY: Double
    var width: Double
    var height: Double
    var isOpen: Bool
    var floatsAboveWindows: Bool
    var reminderAt: Date?
    var expiresAt: Date?

    init(text: String = "", color: NoteColor = .yellow, font: NoteFont = .bold) {
        id = UUID()
        self.text = text
        colorRaw = color.rawValue
        fontRaw = font.rawValue
        createdAt = Date()
        updatedAt = Date()
        originX = 0
        originY = 0
        width = 220
        height = 220
        isOpen = false
        floatsAboveWindows = true
    }

    var color: NoteColor {
        get { NoteColor(rawValue: colorRaw) ?? .yellow }
        set { colorRaw = newValue.rawValue; updatedAt = Date() }
    }

    var font: NoteFont {
        get { NoteFont(rawValue: fontRaw) ?? .bold }
        set { fontRaw = newValue.rawValue; updatedAt = Date() }
    }

    var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    /// First non-empty line, for menus and lists.
    var title: String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? "Empty note" : String(trimmed.prefix(60))
    }
}

extension Notification.Name {
    /// Posted when a reminder fires; the object is the note's UUID.
    static let noteReminderFired = Notification.Name("QuickNoteReminderFired")
}
