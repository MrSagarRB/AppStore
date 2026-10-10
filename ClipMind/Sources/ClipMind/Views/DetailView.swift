import SwiftUI

struct DetailView: View {
    @ObservedObject var store: ClipStore
    let id: UUID
    let onCopy: () -> Void
    let onNewFolder: () -> Void

    var body: some View {
        if let item = store.item(id) {
            VStack(alignment: .leading, spacing: 12) {
                header(item)
                TextField("Title (optional — name this snippet)", text: Binding(
                    get: { store.item(id)?.title ?? "" },
                    set: { store.setTitle(id, $0) }
                ))
                .textFieldStyle(.roundedBorder)
                content(item)
                footer(item)
            }
            .padding(16)
        } else {
            ContentUnavailableView("Clip Removed", systemImage: "trash")
        }
    }

    private func header(_ item: ClipItem) -> some View {
        HStack(spacing: 8) {
            Label(item.kind.label, systemImage: item.kind.symbol)
                .font(.headline)
            Spacer()
            Button { store.setPinned([id], !item.isPinned) } label: {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(item.isPinned ? .orange : .primary)
            }
            .help(item.isPinned ? "Unpin" : "Pin")
            FolderMenu(store: store, ids: [id], newFolder: onNewFolder)
                .labelStyle(.iconOnly)
                .menuStyle(.borderlessButton)
                .fixedSize()
            if item.kind == .url, let url = Self.url(from: item.text) {
                Button { NSWorkspace.shared.open(url) } label: { Image(systemName: "safari") }
                    .help("Open in Browser")
            }
            Button(role: .destructive) { store.remove([id]) } label: { Image(systemName: "trash") }
                .help("Delete")
            Button("Copy", action: onCopy)
                .buttonStyle(.borderedProminent)
        }
    }

    @ViewBuilder
    private func content(_ item: ClipItem) -> some View {
        if item.kind == .image {
            ScrollView([.horizontal, .vertical]) {
                if let image = ImageLoader.image(for: item, maxPixel: 2400) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                }
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        } else {
            TextEditor(text: Binding(
                get: { store.item(id)?.text ?? "" },
                set: { store.setText(id, $0) }
            ))
            .font(.system(.body, design: item.kind == .code ? .monospaced : .default))
            .scrollContentBackground(.hidden)
            .padding(6)
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func footer(_ item: ClipItem) -> some View {
        var parts: [String] = []
        if item.kind == .image {
            if let w = item.imageWidth, let h = item.imageHeight { parts.append("\(w) × \(h) px") }
            if let b = item.imageBytes { parts.append(ByteCountFormatter.string(fromByteCount: Int64(b), countStyle: .file)) }
        } else {
            let text = item.text ?? ""
            parts.append("\(text.count) characters")
            parts.append("\(text.split(whereSeparator: \.isWhitespace).count) words")
        }
        if let app = item.sourceApp { parts.append("from \(app)") }
        parts.append("copied \(item.useCount)×")
        parts.append("added \(item.createdAt.formatted(date: .abbreviated, time: .shortened))")
        return Text(parts.joined(separator: "  ·  "))
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    static func url(from text: String?) -> URL? {
        guard let t = text?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        return URL(string: t.contains("://") ? t : "https://" + t)
    }
}
