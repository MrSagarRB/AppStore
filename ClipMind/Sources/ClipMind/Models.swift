import Foundation

enum ClipKind: String, Codable, CaseIterable, Hashable {
    case text, code, url, image

    var label: String {
        switch self {
        case .text: "Text"
        case .code: "Code"
        case .url: "Link"
        case .image: "Image"
        }
    }

    var pluralLabel: String {
        switch self {
        case .text: "Text"
        case .code: "Code"
        case .url: "Links"
        case .image: "Images"
        }
    }

    var symbol: String {
        switch self {
        case .text: "text.alignleft"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .url: "link"
        case .image: "photo"
        }
    }
}

struct ClipItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var kind: ClipKind
    var text: String?
    var imageFile: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var imageBytes: Int?
    var contentHash: String
    var title: String?
    var createdAt = Date()
    var lastUsedAt = Date()
    var isPinned = false
    var folderID: UUID?
    var sourceApp: String?
    var useCount = 0

    /// What the row shows as its main line.
    var headline: String {
        if let title, !title.isEmpty { return title }
        return preview
    }

    var preview: String {
        switch kind {
        case .image:
            if let w = imageWidth, let h = imageHeight { return "Image \(w)×\(h)" }
            return "Image"
        default:
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return String(trimmed.prefix(300))
        }
    }

    var searchText: String {
        [text, title, sourceApp, kind == .image ? "image screenshot picture" : nil]
            .compactMap { $0 }
            .joined(separator: "\n")
    }
}

struct Folder: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var createdAt = Date()
}

/// A selectable slice of the library (sidebar entries).
enum Scope: Hashable {
    case all
    case pinned
    case kind(ClipKind)
    case folder(UUID)

    func matches(_ item: ClipItem) -> Bool {
        switch self {
        case .all: true
        case .pinned: item.isPinned
        case .kind(let k): item.kind == k
        case .folder(let id): item.folderID == id
        }
    }
}
