import AppKit
import CryptoKit
import SwiftUI

@MainActor
final class ClipStore: ObservableObject {
    static let shared = ClipStore()

    @Published private(set) var items: [ClipItem] = []
    @Published private(set) var folders: [Folder] = []

    let imagesDirectory: URL
    private let storeURL: URL
    private var saveWork: DispatchWorkItem?

    private struct Snapshot: Codable {
        var items: [ClipItem]
        var folders: [Folder]
    }

    var maxItems: Int {
        let v = UserDefaults.standard.integer(forKey: "maxItems")
        return v > 0 ? v : 500
    }

    private init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClipMind", isDirectory: true)
        imagesDirectory = support.appendingPathComponent("Images", isDirectory: true)
        storeURL = support.appendingPathComponent("store.json")
        try? FileManager.default.createDirectory(at: imagesDirectory, withIntermediateDirectories: true)

        if let data = try? Data(contentsOf: storeURL),
           let snap = try? JSONDecoder.iso.decode(Snapshot.self, from: data) {
            items = snap.items
            folders = snap.folders
        }
    }

    // MARK: Queries

    func item(_ id: UUID) -> ClipItem? { items.first { $0.id == id } }

    func folder(_ id: UUID?) -> Folder? {
        guard let id else { return nil }
        return folders.first { $0.id == id }
    }

    func count(_ scope: Scope) -> Int { items.lazy.filter { scope.matches($0) }.count }

    /// Items in `scope` matching every word of `query`, newest-used first.
    func filtered(_ scope: Scope, query: String, pinnedFirst: Bool = false) -> [ClipItem] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        var result = items.filter { scope.matches($0) }
        if !terms.isEmpty {
            result = result.filter { item in
                let hay = item.searchText + "\n" + (folder(item.folderID)?.name ?? "")
                return terms.allSatisfy { hay.localizedCaseInsensitiveContains($0) }
            }
        }
        return result.sorted {
            if pinnedFirst, $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.lastUsedAt > $1.lastUsedAt
        }
    }

    // MARK: Capture

    func addText(_ text: String, source: String?) {
        let kind = Classifier.classify(text)
        let hash = Self.hash(Data(("\(kind.rawValue):" + text).utf8))
        // Same text may have been classified differently before; match on text alone.
        if let i = items.firstIndex(where: { $0.kind != .image && $0.text == text }) {
            bump(at: i)
            return
        }
        insert(ClipItem(kind: kind, text: text, contentHash: hash, sourceApp: source))
    }

    func addImage(png: Data, width: Int, height: Int, source: String?) {
        let hash = Self.hash(png)
        if let i = items.firstIndex(where: { $0.contentHash == hash }) {
            bump(at: i)
            return
        }
        let file = UUID().uuidString + ".png"
        do { try png.write(to: imagesDirectory.appendingPathComponent(file)) } catch { return }
        insert(ClipItem(kind: .image, imageFile: file, imageWidth: width, imageHeight: height,
                        imageBytes: png.count, contentHash: hash, sourceApp: source))
    }

    private func bump(at index: Int) {
        items[index].lastUsedAt = Date()
        scheduleSave()
    }

    private func insert(_ item: ClipItem) {
        items.insert(item, at: 0)
        trim()
        scheduleSave()
    }

    func markUsed(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].lastUsedAt = Date()
        items[i].useCount += 1
        scheduleSave()
    }

    // MARK: Mutations

    func setPinned(_ ids: Set<UUID>, _ pinned: Bool) {
        mutate(ids) { $0.isPinned = pinned }
    }

    func move(_ ids: Set<UUID>, to folderID: UUID?) {
        mutate(ids) { $0.folderID = folderID }
    }

    func setTitle(_ id: UUID, _ title: String) {
        mutate([id]) { $0.title = title.isEmpty ? nil : title }
    }

    func setText(_ id: UUID, _ text: String) {
        mutate([id]) {
            $0.text = text
            $0.contentHash = Self.hash(Data(("\($0.kind.rawValue):" + text).utf8))
        }
    }

    func remove(_ ids: Set<UUID>) {
        for item in items where ids.contains(item.id) { deleteFile(of: item) }
        items.removeAll { ids.contains($0.id) }
        scheduleSave()
    }

    /// Removes everything that is neither pinned nor filed in a folder.
    func clearHistory() {
        remove(Set(items.filter { !$0.isPinned && $0.folderID == nil }.map(\.id)))
    }

    @discardableResult
    func addFolder(_ name: String) -> Folder {
        let folder = Folder(name: name)
        folders.append(folder)
        scheduleSave()
        return folder
    }

    func renameFolder(_ id: UUID, to name: String) {
        guard let i = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[i].name = name
        scheduleSave()
    }

    /// Deleting a folder keeps its clips; they just go back to plain history.
    func deleteFolder(_ id: UUID) {
        move(Set(items.filter { $0.folderID == id }.map(\.id)), to: nil)
        folders.removeAll { $0.id == id }
        scheduleSave()
    }

    private func mutate(_ ids: Set<UUID>, _ change: (inout ClipItem) -> Void) {
        for i in items.indices where ids.contains(items[i].id) { change(&items[i]) }
        scheduleSave()
    }

    /// History is capped, but pinned clips and clips in folders are kept forever.
    private func trim() {
        let disposable = items
            .filter { !$0.isPinned && $0.folderID == nil }
            .sorted { $0.lastUsedAt > $1.lastUsedAt }
        guard disposable.count > maxItems else { return }
        let drop = Set(disposable.dropFirst(maxItems).map(\.id))
        for item in items where drop.contains(item.id) { deleteFile(of: item) }
        items.removeAll { drop.contains($0.id) }
    }

    private func deleteFile(of item: ClipItem) {
        guard let file = item.imageFile else { return }
        try? FileManager.default.removeItem(at: imagesDirectory.appendingPathComponent(file))
    }

    // MARK: Persistence

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            MainActor.assumeIsolated { self?.saveNow() }
        }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    func saveNow() {
        saveWork?.cancel()
        guard let data = try? JSONEncoder.iso.encode(Snapshot(items: items, folders: folders)) else { return }
        try? data.write(to: storeURL, options: .atomic)
    }

    private static func hash(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }()
}

extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

/// Cached, downsampled image loading for list thumbnails and the detail preview.
enum ImageLoader {
    private static let cache = NSCache<NSString, NSImage>()

    @MainActor
    static func image(for item: ClipItem, maxPixel: Int) -> NSImage? {
        guard let file = item.imageFile else { return nil }
        let key = "\(file)@\(maxPixel)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let url = ClipStore.shared.imagesDirectory.appendingPathComponent(file)
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: .zero)
        cache.setObject(image, forKey: key)
        return image
    }
}
